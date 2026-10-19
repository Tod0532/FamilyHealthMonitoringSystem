/// 一次 OCR 识别的可信度信号
///
/// ## 为什么需要它
/// 血压计识别错的时候，给出的往往是**"看着很合理"的错值**：真值 138/88 被读成
/// 133/88，用户根本看不出来，直接存进健康记录 —— 这比识别失败更危险
/// （失败至少用户会重拍）。所以识别完必须能回答一个问题：**这次读数可不可信。**
///
/// ## 信号怎么来
/// 新链路（`LcdOnnxPipeline`）会对同一个检测框做 81 组测试时增强（TTA：3 种尺度
/// × 3 种宽 × 3 种平移），每组都独立读一次七位数字，再按"模型置信度加权 + 票数"
/// 选出胜出读数。于是天然就有了一堆**免费的一致性信号**：
///   · [agree]        81 次里有多少次读出了同一个结果
///   · [weightShare]  胜出读数的置信度和占全部候选的比例
///   · [margin]       胜出读数比第二名领先多少
///   · [meanGeo]      每次读数时，7 个数字头各自最大概率的**几何均值**
///                    （用几何均值而不是概率乘积：乘积是 7 个数连乘，
///                     0.9^7≈0.48，数值被压得很小、不好定阈值也不好解释）
///   · [detConf]      液晶屏定位框的置信度
///
/// 注意 [meanGeo] 经实测**没有区分度**，不参与"是否需要核对"的判定，
/// 只用于日志排查（原因见下方常量处）。
///
/// ## 阈值怎么定（重点）
/// 判据**必须用真实照片标定**，不能凭感觉：
///   · 阈值太松 → 该提示的没提示，错值照旧被存进去
///   · 阈值太紧 → 大量正确结果被标成"请核对"，用户每次拍照都要多点几下，
///                几天后就会条件反射地直接点确认，提示等于失效
///
/// 标定脚本：`flutter-app/tool/confidence_calibration.py`
/// 它把 60 张真实照片（文件名即真值）跑完整 TTA，输出各信号在
/// "三项全对"与"有错"两组上的分布，以及每个候选阈值的漏报率/误报率。
/// **改下面的常量请重跑那个脚本，并把结果写进提交信息。**
library;

class OcrQuality {
  /// 液晶屏定位框置信度（0~1）
  final double detConf;

  /// TTA 候选读数的种数（越少越稳）
  final int variants;

  /// 一致度：胜出读数的票数 / 全部成功读数次数（0~1）
  final double agree;

  /// 权重占比：胜出读数的置信度和 / 全部候选置信度和（0~1）
  final double weightShare;

  /// 领先幅度：与第二候选的相对差距（0~1，只有一个候选时为 1）
  final double margin;

  /// 数字模型置信度：7 个数字头各自最大概率的几何均值（0~1）
  final double meanGeo;

  const OcrQuality({
    required this.detConf,
    required this.variants,
    required this.agree,
    required this.weightShare,
    required this.margin,
    required this.meanGeo,
  });

  /// ── 以下是标定出来的判据（60 张真实照片，见 tool/confidence_calibration.py）──
  ///
  /// 实测定下来的规则：**一致度 < 0.30 或 屏幕框置信度 < 0.30** → 提示核对。
  /// 在 60 张上的表现：抓到 **14/15（93%）** 个错值，误标 **4/43（9.3%）** 个正确结果。
  ///
  /// 为什么必须是这两个信号：
  ///   · [agree] 是最强的信号（错读中位 0.19，正确中位 0.63）——
  ///     读错时多个尺度各执一词，胜出读数的一致度就低。
  ///   · [detConf] 单独看很弱（阈值 0.65 也只抓到 60%），但和 agree 组合后
  ///     能多抓一个"高一致度、其实框得不准"的错读，代价是 9% 的误标。
  ///   · **[meanGeo] 没有区分度，故意不参与判定**：实测三项全对时 0.212~0.232、
  ///     有错时 0.180~0.230，两组几乎完全重叠，任何 ≥0.25 的阈值都会把
  ///     100% 的结果标成"请核对"（等于提示失效）。它只留在调试标签里。
  ///
  /// **改这两个常量请重跑标定脚本，并把结果写进提交信息。**
  static const double agreeMin = 0.30;

  /// 液晶屏定位框置信度下限
  static const double detConfMin = 0.30;

  /// 按一致度分档时"直接可接受"的下限（≥ 它就不打扰用户）
  ///
  /// 实测分档（`tool/ocr_lab.py --tiers`，60 张真实照片，75 组候选）：
  ///   agree ≥ 0.60        → 该档准确率 92.6%（27 张）
  ///   0.40 ≤ agree &lt; 0.60 → 该档准确率 **100%**（12 张）
  ///   0.30 ≤ agree &lt; 0.40 → 该档准确率 80.0%（5 张）
  ///   agree &lt; 0.30        → 14 张里只有 2 张对（该档准确率 14%）
  static const double agreeAutoAccept = 0.40;

  /// 是否**连结果都不该给**（拒绝填值，请用户重拍或手动输入）
  ///
  /// 这一档不是为了"更准"，而是为了**不让错值有机会进表单**：
  /// agree &lt; 0.30 的 14 张里有 12 张是错的。与其填一个"看着很合理"的错血压，
  /// 不如直接说"没认准"。
  ///
  /// 同一批 60 张上的效果：填出的值准确率 **74.1% → 93.2%**，
  /// 代价是 24% 的照片需要重拍或手动输入。
  bool get rejected => agree < agreeMin;

  /// 是否需要人工核对（排除被拒绝的那些——它们连值都不填）
  bool get needsReview =>
      !rejected && (agree < agreeAutoAccept || detConf < detConfMin);

  /// 给用户看的原因（不要写"置信度 0.43"这种内部术语，要说人话）
  String get reviewReason {
    if (rejected) {
      return '同一张照片反复识别的结果不一致'
          '（只有 ${(agree * 100).round()}% 的尝试给出相同读数），没认准';
    }
    final problems = <String>[];
    if (agree < agreeAutoAccept) {
      problems.add('同一张照片反复识别的结果只有'
          '${(agree * 100).round()}% 一致，请重点核对');
    }
    if (detConf < detConfMin) {
      problems.add('没能稳定地找到血压计屏幕'
          '（定位把握 ${(detConf * 100).round()}%）');
    }
    if (problems.isEmpty) {
      return '识别结果请核对';
    }
    return '${problems.join('；')}，识别结果请核对';
  }

  /// 供日志/工单使用的紧凑描述
  String get debugLabel => 'det=${detConf.toStringAsFixed(2)} '
      'variants=$variants agree=${agree.toStringAsFixed(2)} '
      'weight=${weightShare.toStringAsFixed(2)} '
      'margin=${margin.toStringAsFixed(2)} '
      'meanGeo=${meanGeo.toStringAsFixed(3)} '
      'needsReview=$needsReview rejected=$rejected';

  @override
  String toString() => 'OcrQuality($debugLabel)';
}
