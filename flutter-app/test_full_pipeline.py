#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
完整管道测试：原始照片 -> 自动LCD检测裁剪 -> TFLite识别 -> 评估精度

流程：
1. 用 OpenCV 自动检测 Omron J710 血压计的 LCD 屏幕区域
2. 裁剪 LCD 区域
3. 用 TFLite 多头CNN模型识别血压值
4. 与文件名中的真实标签对比评估精度
"""
import os
import sys
import numpy as np
import cv2
import tensorflow as tf
from PIL import Image

if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

IMAGE_DIR = 'dataset/images'
MODEL_PATH = 'assets/models/bpressure_multihead.tflite'
OUTPUT_DIR = 'auto_crops'

SYS_INDICES = [4, 1, 5]
DIA_INDICES = [3, 0]
PULSE_INDICES = [2, 6]
INPUT_SIZE = 224


def load_tflite_model():
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    return interpreter


def preprocess_image(pil_image):
    img = pil_image.convert('RGB')
    img = img.resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    return np.expand_dims(arr, axis=0)


def parse_filename(filename):
    base = os.path.splitext(filename)[0]
    parts = base.split('-')
    if len(parts) == 3:
        return int(parts[0]), int(parts[1]), int(parts[2])
    return None


def predict(interpreter, pil_image):
    input_data = preprocess_image(pil_image)
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    outputs = []
    for i in range(7):
        output_tensor = interpreter.get_tensor(output_details[i]['index'])
        digit = np.argmax(output_tensor[0])
        prob = np.max(output_tensor[0])
        outputs.append((digit, prob))

    sys_val = outputs[SYS_INDICES[0]][0] * 100 + outputs[SYS_INDICES[1]][0] * 10 + outputs[SYS_INDICES[2]][0]
    dia_val = outputs[DIA_INDICES[0]][0] * 10 + outputs[DIA_INDICES[1]][0]
    pulse_val = outputs[PULSE_INDICES[0]][0] * 10 + outputs[PULSE_INDICES[1]][0]
    avg_conf = np.mean([outputs[i][1] for i in range(7)])

    return sys_val, dia_val, pulse_val, avg_conf, outputs


def detect_lcd_screen(opencv_img):
    """
    自动检测 Omron J710 血压计的 LCD 屏幕区域

    核心思路：
    1. 先找到白色设备外壳（设备比背景亮）
    2. 在设备内部找到深色 LCD 屏幕
    3. LCD 特征：设备内最暗的矩形区域，内部有高对比度（7段数码管数字）
    """
    gray = cv2.cvtColor(opencv_img, cv2.COLOR_BGR2GRAY)
    hsv = cv2.cvtColor(opencv_img, cv2.COLOR_BGR2HSV)
    h, w = gray.shape
    img_area = h * w

    # === 方法1: 先找设备外壳，再在内部找 LCD ===
    # 设备外壳是亮色区域（白色/米白色）
    # 用高阈值找到亮色区域
    device_mask = cv2.inRange(gray, 180, 255)

    # 形态学操作：填充空洞、连接设备边缘
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    device_mask = cv2.morphologyEx(device_mask, cv2.MORPH_CLOSE, kernel)
    device_mask = cv2.morphologyEx(device_mask, cv2.MORPH_OPEN, kernel)

    # 找到设备轮廓
    device_contours, _ = cv2.findContours(device_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    best_device = None
    best_device_area = 0
    for cnt in device_contours:
        area = cv2.contourArea(cnt)
        if area > img_area * 0.05 and area > best_device_area:
            best_device = cnt
            best_device_area = area

    if best_device is not None:
        dx, dy, dw, dh = cv2.boundingRect(best_device)

        # 在设备内部找 LCD（深色区域）
        # 裁剪设备区域
        device_roi = gray[dy:dy+dh, dx:dx+dw]
        device_h, device_w = device_roi.shape

        # 在设备内找暗区
        # LCD 比设备外壳暗很多
        _, dark_thresh = cv2.threshold(device_roi, 140, 255, cv2.THRESH_BINARY_INV)

        # 形态学操作
        dark_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        dark_thresh = cv2.morphologyEx(dark_thresh, cv2.MORPH_CLOSE, dark_kernel)

        # 找到暗区轮廓
        dark_contours, _ = cv2.findContours(dark_thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        best_lcd = None
        best_lcd_score = 0

        for cnt in dark_contours:
            lx, ly, lw, lh = cv2.boundingRect(cnt)
            area = lw * lh

            # LCD 大小约束
            if area < device_w * device_h * 0.05 or area > device_w * device_h * 0.60:
                continue

            aspect = lw / lh if lh > 0 else 0
            if aspect < 0.3 or aspect > 3.0:
                continue

            # 计算该区域内的对比度（LCD内应该有数字，对比度较高）
            roi_gray = device_roi[ly:ly+lh, lx:lx+lw]
            if roi_gray.size == 0:
                continue
            contrast = roi_gray.std()

            # 评分：面积 + 对比度
            score = (area / (device_w * device_h)) * contrast

            if score > best_lcd_score:
                best_lcd_score = score
                best_lcd = (dx + lx, dy + ly, lw, lh)

        if best_lcd is not None and best_lcd_score > 5:
            lx, ly, lw, lh = best_lcd
            # 稍微扩大以确保完整包含 LCD 边框
            margin_x = int(lw * 0.08)
            margin_y = int(lh * 0.08)
            lx = max(0, lx - margin_x)
            ly = max(0, ly - margin_y)
            lw = min(w - lx, lw + margin_x * 2)
            lh = min(h - ly, lh + margin_y * 2)
            return (lx, ly, lw, lh), 'device-dark'

    # === 方法2: 直接找图像中的深色矩形区域（LCD 特征） ===
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # 找图像中偏暗的区域（LCD 屏幕通常是灰色/深色）
    _, dark_thresh = cv2.threshold(blurred, 150, 255, cv2.THRESH_BINARY_INV)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    dark_thresh = cv2.morphologyEx(dark_thresh, cv2.MORPH_CLOSE, kernel)

    contours, _ = cv2.findContours(dark_thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    best_rect = None
    best_score = 0

    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cw * ch

        # 面积约束
        if area < img_area * 0.02 or area > img_area * 0.60:
            continue

        aspect = cw / ch if ch > 0 else 0
        if aspect < 0.3 or aspect > 3.0:
            continue

        roi_gray = gray[y:y+ch, x:x+cw]
        if roi_gray.size == 0:
            continue

        # LCD 内部应该有高对比度（数字 vs 背景）
        contrast = roi_gray.std()

        # 检查区域内是否均匀（LCD 背景应该是均匀的深色）
        mean_brightness = roi_gray.mean()

        # LCD 的亮度应该在中等范围（不是太暗也不是太亮）
        if mean_brightness < 30 or mean_brightness > 180:
            continue

        score = contrast * (area / img_area) * 100

        if score > best_score:
            best_score = score
            best_rect = (x, y, cw, ch)

    if best_rect is not None and best_score > 10:
        x, y, cw, ch = best_rect
        margin_x = int(cw * 0.05)
        margin_y = int(ch * 0.05)
        x = max(0, x - margin_x)
        y = max(0, y - margin_y)
        cw = min(w - x, cw + margin_x * 2)
        ch = min(h - y, ch + margin_y * 2)
        return (x, y, cw, ch), 'direct-dark'

    # === 方法3: 使用标注数据的平均位置作为启发式 ===
    # 根据标注数据统计：
    # X: mean=0.28, Y: mean=0.46, W: mean=0.50, H: mean=0.32
    lcd_x = int(w * 0.15)
    lcd_y = int(h * 0.35)
    lcd_w = int(w * 0.55)
    lcd_h = int(h * 0.35)
    return (lcd_x, lcd_y, lcd_w, lcd_h), 'heuristic'


def main():
    print('=' * 60)
    print('完整管道测试：原图 -> 自动LCD裁剪 -> TFLite识别')
    print('=' * 60)

    print(f'\n加载模型: {MODEL_PATH}')
    interpreter = load_tflite_model()
    print('模型加载成功')

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    images = sorted([f for f in os.listdir(IMAGE_DIR) if f.endswith(('.jpg', '.png'))])
    print(f'共 {len(images)} 张图片\n')

    results = []

    for img_file in images:
        label = parse_filename(img_file)
        if label is None:
            print(f'[SKIP] {img_file} (无法解析标签)')
            continue

        true_sys, true_dia, true_pulse = label
        img_path = os.path.join(IMAGE_DIR, img_file)

        img_cv = cv2.imread(img_path)
        if img_cv is None:
            print(f'[ERR] 无法读取: {img_file}')
            continue

        img_pil = Image.open(img_path).convert('RGB')
        orig_w, orig_h = img_pil.size

        # === 步骤1: 自动检测 LCD 区域 ===
        try:
            (x, y, cw, ch), method = detect_lcd_screen(img_cv)
        except Exception as e:
            print(f'[SKIP] {img_file} - 检测异常: {e}')
            continue

        crop_x = max(0, x)
        crop_y = max(0, y)
        crop_w = min(cw, orig_w - crop_x)
        crop_h = min(ch, orig_h - crop_y)

        if crop_w < 50 or crop_h < 50:
            print(f'[WARN] {img_file} - 裁剪区域过小: {crop_w}x{crop_h}, 跳过')
            continue

        lcd_crop = img_pil.crop((crop_x, crop_y, crop_x + crop_w, crop_y + crop_h))

        crop_path = os.path.join(OUTPUT_DIR, img_file.replace('.png', '.jpg'))
        lcd_crop.save(crop_path)

        # === 步骤2: TFLite 识别 ===
        pred_sys, pred_dia, pred_pulse, conf, outputs = predict(interpreter, lcd_crop)

        sys_correct = (pred_sys == true_sys)
        dia_correct = (pred_dia == true_dia)
        pulse_correct = (pred_pulse == true_pulse)
        all_correct = sys_correct and dia_correct and pulse_correct

        results.append({
            'file': img_file,
            'true': (true_sys, true_dia, true_pulse),
            'pred': (pred_sys, pred_dia, pred_pulse),
            'conf': conf,
            'method': method,
            'crop_size': f'{crop_w}x{crop_h}',
            'sys_correct': sys_correct,
            'dia_correct': dia_correct,
            'pulse_correct': pulse_correct,
            'all_correct': all_correct,
            'sys_err': abs(pred_sys - true_sys),
            'dia_err': abs(pred_dia - true_dia),
            'pulse_err': abs(pred_pulse - true_pulse),
        })

        status = '[OK]' if all_correct else '[ERR]'
        print(f'{status} {img_file}')
        print(f'   原图: {orig_w}x{orig_h}, LCD裁剪: {crop_w}x{crop_h} (方法:{method})')
        print(f'   真实: {true_sys}/{true_dia}, {true_pulse} bpm')
        print(f'   预测: {pred_sys}/{pred_dia}, {pred_pulse} bpm  (置信度: {conf:.2f})')
        if not all_correct:
            errs = []
            if not sys_correct: errs.append(f'收缩压误差{abs(pred_sys - true_sys)}')
            if not dia_correct: errs.append(f'舒张压误差{abs(pred_dia - true_dia)}')
            if not pulse_correct: errs.append(f'脉搏误差{abs(pred_pulse - true_pulse)}')
            print(f'   错误: {", ".join(errs)}')

    # 统计
    total = len(results)
    if total == 0:
        print('\n没有可分析的图片')
        return

    sys_correct_count = sum(1 for r in results if r['sys_correct'])
    dia_correct_count = sum(1 for r in results if r['dia_correct'])
    pulse_correct_count = sum(1 for r in results if r['pulse_correct'])
    all_correct_count = sum(1 for r in results if r['all_correct'])

    sys_mae = np.mean([r['sys_err'] for r in results])
    dia_mae = np.mean([r['dia_err'] for r in results])
    pulse_mae = np.mean([r['pulse_err'] for r in results])
    avg_conf = np.mean([r['conf'] for r in results])

    print('\n' + '=' * 60)
    print('统计结果')
    print('=' * 60)
    print(f'总图片数: {total}')
    print(f'完全正确率: {all_correct_count}/{total} = {all_correct_count/total*100:.1f}%')
    print(f'收缩压正确率: {sys_correct_count}/{total} = {sys_correct_count/total*100:.1f}%')
    print(f'舒张压正确率: {dia_correct_count}/{total} = {dia_correct_count/total*100:.1f}%')
    print(f'脉搏正确率: {pulse_correct_count}/{total} = {pulse_correct_count/total*100:.1f}%')
    print(f'收缩压 MAE: {sys_mae:.1f} mmHg')
    print(f'舒张压 MAE: {dia_mae:.1f} mmHg')
    print(f'脉搏 MAE: {pulse_mae:.1f} bpm')
    print(f'平均置信度: {avg_conf:.2f}')

    # 按检测方法统计
    methods = {}
    for r in results:
        m = r['method']
        if m not in methods:
            methods[m] = {'total': 0, 'correct': 0}
        methods[m]['total'] += 1
        if r['all_correct']:
            methods[m]['correct'] += 1

    print('\n各检测方法表现:')
    for m, stats in methods.items():
        acc = stats['correct'] / stats['total'] * 100 if stats['total'] > 0 else 0
        print(f'  {m}: {stats["correct"]}/{stats["total"]} = {acc:.1f}%')

    print('=' * 60)

    # 失败案例
    failed = [r for r in results if not r['all_correct']]
    if failed:
        print('\n失败案例:')
        for r in failed:
            print(f'  {r["file"]} | 真实:{r["true"]} | 预测:{r["pred"]} | 裁剪:{r["crop_size"]} ({r["method"]})')


if __name__ == '__main__':
    main()
