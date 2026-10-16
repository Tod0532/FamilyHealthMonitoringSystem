import 'package:flutter_test/flutter_test.dart';
import 'package:health_center_app/core/ocr/models/ocr_quality.dart';
import 'package:health_center_app/core/ocr/models/ocr_result.dart';

/// OCR 可信度判据的单测
///
/// 背景：血压计**读错**时给的是"看着很合理"的错值（真值 138/88 → 133/88），
/// 用户看不出来就存进健康档案，比识别失败更危险。所以识别成功后还要判断
/// "这次读数可不可信"，不可信就提示核对、并且**不允许直接保存**。
///
/// 阈值本身来自 60 张真实照片的标定（`tool/confidence_calibration.py`），
/// 这里钉的是**判据逻辑**：哪个信号越界、提示文案说的是不是那件事、
/// 以及"没有质量信息时不打扰用户"这条边界。
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

  group('OcrQuality.needsReview', () {
    test('各项都好 → 不需要核对', () {
      expect(good().needsReview, isFalse);
    });

    test('一致度低于阈值 → 需要核对（多个尺度各执一词，说明读数不稳）', () {
      final q = good(agree: OcrQuality.agreeMin - 0.01, variants: 5);
      expect(q.needsReview, isTrue);
      expect(q.reviewReason, contains('不一致'));
    });

    test('屏幕框置信度低于阈值 → 需要核对（屏幕没定位稳）', () {
      final q = good(detConf: OcrQuality.detConfMin - 0.01);
      expect(q.needsReview, isTrue);
      expect(q.reviewReason, contains('屏幕'));
    });

    test('两个信号都越界 → 两条原因都要说清', () {
      final q = good(agree: 0.1, detConf: 0.1);
      expect(q.needsReview, isTrue);
      expect(q.reviewReason, contains('不一致'));
      expect(q.reviewReason, contains('屏幕'));
    });

    test('meanGeo 再低也不参与判定 —— 实测没有区分度，别把它加回判据', () {
      // 60 张实测：三项全对时 meanGeo 0.212~0.232，有错时 0.180~0.230，
      // 两组几乎完全重叠；任何 ≥0.25 的阈值都会把 100% 的结果标成"请核对"。
      final q = good(meanGeo: 0.05);
      expect(q.needsReview, isFalse,
          reason: 'meanGeo 只用于日志排查，不参与 needsReview');
    });

    test('正好等于阈值 → 不算越界（避免边界上抖动）', () {
      final q = good(agree: OcrQuality.agreeMin, detConf: OcrQuality.detConfMin);
      expect(q.needsReview, isFalse);
    });

    test('提示文案要给出量化的把握程度，且不出现内部术语', () {
      final q = good(agree: 0.05, detConf: 0.9);
      expect(q.reviewReason, contains('5%'));
      expect(q.reviewReason, contains('请核对'));
      expect(q.reviewReason, isNot(contains('meanGeo')));
      expect(q.reviewReason, isNot(contains('TTA')));
      expect(q.reviewReason, isNot(contains('detConf')));
    });

    test('debugLabel 含全部信号，便于从日志定位是哪一项偏低', () {
      final q = good();
      expect(q.debugLabel, contains('agree='));
      expect(q.debugLabel, contains('meanGeo='));
      expect(q.debugLabel, contains('needsReview='));
    });
  });

  group('OcrResult 与质量信号的关系', () {
    test('新链路给了质量信号且偏低 → 需要核对', () {
      final r = OcrResult(
        rawText: '133/88 mmHg',
        systolic: 133,
        diastolic: 88,
        heartRate: 70,
        quality: good(agree: 0.12),
      );
      expect(r.isValid, isTrue, reason: '有数值，识别本身是"成功"的');
      expect(r.needsReview, isTrue, reason: '但成功不等于可信');
    });

    test('没有质量信号（旧链路/ML Kit）→ 不提示，没有依据就不要打扰用户', () {
      final r = OcrResult(
        rawText: '120/80 mmHg',
        systolic: 120,
        diastolic: 80,
      );
      expect(r.isValid, isTrue);
      expect(r.needsReview, isFalse);
      expect(r.quality, isNull);
    });

    test('copyWith 能带上质量信号', () {
      final r = OcrResult(rawText: 'x', systolic: 120, diastolic: 80)
          .copyWith(quality: good(agree: 0.1));
      expect(r.quality, isNotNull);
      expect(r.needsReview, isTrue);
    });
  });
}
