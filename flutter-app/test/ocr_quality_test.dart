import 'package:flutter_test/flutter_test.dart';
import 'package:health_center_app/core/ocr/models/ocr_quality.dart';
import 'package:health_center_app/core/ocr/models/ocr_result.dart';

/// OCR 可信度判据的单测
///
/// 背景：血压计**读错**时给的是"看着很合理"的错值（真值 138/88 → 133/88），
/// 用户看不出来就存进健康档案，比识别失败更危险。
///
/// 判据分三档（阈值都来自 60 张真实照片的标定，见 `tool/ocr_lab.py --tiers`）：
///   · agree ≥ 0.40                      → 直接可用，不打扰
///   · 0.30 ≤ agree &lt; 0.40 或 detConf 低 → 填值但要求核对
///   · agree &lt; 0.30                      → **不填值**，让用户重拍/手输
///                                        （实测这一档 14 张里 12 张是错的）
void main() {
  /// 造一个各项都好的质量信号
  OcrQuality good({
    double detConf = 0.9,
    int variants = 1,
    double agree = 1.0,
    double weightShare = 1.0,
    double margin = 1.0,
    double meanGeo = 0.9,
  }) {
    return OcrQuality(
      detConf: detConf,
      variants: variants,
      agree: agree,
      weightShare: weightShare,
      margin: margin,
      meanGeo: meanGeo,
    );
  }

  group('第一档：高可信度 → 不打扰', () {
    test('各项都好 → 既不拒绝也不需要核对', () {
      final q = good();
      expect(q.rejected, isFalse);
      expect(q.needsReview, isFalse);
    });

    test('agree 正好在自动接受线（0.40）→ 不需要核对', () {
      final q = good(agree: OcrQuality.agreeAutoAccept);
      expect(q.rejected, isFalse);
      expect(q.needsReview, isFalse);
    });
  });

  group('第二档：中等可信度 → 填值但要求核对', () {
    test('一致度偏低（0.30~0.40）→ 需要核对，但不拒绝', () {
      final q = good(agree: 0.35, variants: 5);
      expect(q.rejected, isFalse, reason: '还没低到该拒绝的程度');
      expect(q.needsReview, isTrue);
      expect(q.reviewReason, contains('核对'));
    });

    test('屏幕框置信度低（一致度正常）→ 需要核对', () {
      final q = good(detConf: OcrQuality.detConfMin - 0.01);
      expect(q.rejected, isFalse);
      expect(q.needsReview, isTrue);
      expect(q.reviewReason, contains('屏幕'));
    });

    test('两个信号都偏低 → 两条原因都要说清', () {
      final q = good(agree: 0.35, detConf: 0.1);
      expect(q.needsReview, isTrue);
      expect(q.reviewReason, contains('一致'));
      expect(q.reviewReason, contains('屏幕'));
    });
  });

  group('第三档：认不准 → 连值都不给', () {
    test('一致度低于 0.30 → 拒绝填值（而不是填了再让用户核对）', () {
      final q = good(agree: OcrQuality.agreeMin - 0.01);
      expect(q.rejected, isTrue);
      expect(q.reviewReason, contains('没认准'));
      // 被拒绝时不再走"请核对"那条路：值都不填，没什么可核对的
      expect(q.needsReview, isFalse);
    });

    test('边界：agree 正好等于 0.30 → 不拒绝', () {
      expect(good(agree: OcrQuality.agreeMin).rejected, isFalse);
    });

    test('被拒绝的文案要给出量化的把握程度，且不出现内部术语', () {
      final q = good(agree: 0.12);
      expect(q.reviewReason, contains('12%'));
      expect(q.reviewReason, isNot(contains('agree')));
      expect(q.reviewReason, isNot(contains('detConf')));
      expect(q.reviewReason, isNot(contains('meanGeo')));
    });
  });

  group('不参与判定的信号', () {
    test('meanGeo 再低也不影响判定 —— 实测没有区分度，别加回判据', () {
      // 60 张实测：三项全对时 meanGeo 0.212~0.232，有错时 0.180~0.230，
      // 两组几乎完全重叠；任何 ≥0.25 的阈值都会把 100% 的结果标成"请核对"。
      final q = good(meanGeo: 0.05);
      expect(q.rejected, isFalse);
      expect(q.needsReview, isFalse,
          reason: 'meanGeo 只用于日志排查，不参与判定');
    });

    test('debugLabel 含全部信号，便于从日志定位是哪一项偏低', () {
      final q = good();
      expect(q.debugLabel, contains('agree='));
      expect(q.debugLabel, contains('meanGeo='));
      expect(q.debugLabel, contains('rejected='));
    });
  });

  group('OcrResult 与质量信号的关系', () {
    test('新链路给了质量信号且偏低 → 需要核对', () {
      final r = OcrResult(
        rawText: '133/88 mmHg',
        systolic: 133,
        diastolic: 88,
        heartRate: 70,
        quality: good(agree: 0.35),
      );
      expect(r.isValid, isTrue, reason: '有数值，识别本身是"成功"的');
      expect(r.needsReview, isTrue, reason: '但成功不等于可信');
      expect(r.rejected, isFalse);
    });

    test('认不准时 rejected 为真 —— 录入页据此不填值', () {
      final r = OcrResult(
        rawText: '140/85 mmHg',
        systolic: 140,
        diastolic: 85,
        heartRate: 71,
        quality: good(agree: 0.1, detConf: 0.1),
      );
      expect(r.isValid, isTrue);
      expect(r.rejected, isTrue);
      expect(r.reviewReason, isNotEmpty);
    });

    test('没有质量信号（旧链路 / ML Kit）→ 不提示，也没有依据去拒绝', () {
      final r = OcrResult(
        rawText: '120/80 mmHg',
        systolic: 120,
        diastolic: 80,
      );
      expect(r.isValid, isTrue);
      expect(r.needsReview, isFalse);
      expect(r.rejected, isFalse);
      expect(r.quality, isNull);
    });

    test('来自兜底链的结果即使没有质量信号，也必须要求核对（且不拒绝）', () {
      // 真机实测：新链路失败后回退到欧姆龙链，真值 117/80/57 被读成 116/66，
      // 而当时没有任何提示，用户直接就存了。所以兜底结果一律要求核对。
      final r = OcrResult(
        rawText: '116/66 mmHg',
        systolic: 116,
        diastolic: 66,
        fromFallback: true,
      );
      expect(r.isValid, isTrue);
      expect(r.quality, isNull, reason: '兜底链没有质量信号');
      expect(r.needsReview, isTrue, reason: '没有可信度信号时更要提示');
      expect(r.rejected, isFalse, reason: '没有依据就不要拒绝');
      expect(r.reviewReason, contains('备用识别方式'));
    });

    test('copyWith 能带上质量信号与兜底标记', () {
      final r = OcrResult(rawText: 'x', systolic: 120, diastolic: 80)
          .copyWith(quality: good(agree: 0.1));
      expect(r.rejected, isTrue);

      final f = OcrResult(rawText: 'x', systolic: 120, diastolic: 80)
          .copyWith(fromFallback: true);
      expect(f.needsReview, isTrue);
      expect(f.reviewReason, contains('备用识别方式'));
    });
  });
}
