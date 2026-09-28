"""测试 TFLite 血压识别模型在数据集上的精度"""
import os
import numpy as np
import tensorflow as tf

IMAGE_DIR = 'lcd_crops'
MODEL_PATH = 'assets/models/bpressure_multihead.tflite'

# TFLite 输出索引映射
SYS_INDICES = [4, 1, 5]   # 收缩压数字位
DIA_INDICES = [3, 0]      # 舒张压数字位
PULSE_INDICES = [2, 6]    # 脉搏数字位

INPUT_SIZE = 224

def load_tflite_model():
    """加载 TFLite 模型"""
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    return interpreter

def preprocess_image(image_path):
    """预处理图像到 224x224 RGB 归一化"""
    from PIL import Image
    img = Image.open(image_path).convert('RGB')
    img = img.resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    return np.expand_dims(arr, axis=0)

def parse_filename(filename):
    """从文件名解析真实标签: 收缩压-舒张压-脉搏.jpg"""
    base = os.path.splitext(filename)[0]
    parts = base.split('-')
    if len(parts) == 3:
        return int(parts[0]), int(parts[1]), int(parts[2])
    return None

def predict(interpreter, image_path):
    """使用 TFLite 模型预测血压"""
    input_data = preprocess_image(image_path)

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    # 获取 7 个输出头，每个输出 10 个分类概率 (0-9)
    outputs = []
    for i in range(7):
        output_tensor = interpreter.get_tensor(output_details[i]['index'])
        # output_tensor shape: (1, 10)
        digit = np.argmax(output_tensor[0])
        prob = np.max(output_tensor[0])
        outputs.append((digit, prob))

    # 解码血压值
    sys_val = outputs[SYS_INDICES[0]][0] * 100 + outputs[SYS_INDICES[1]][0] * 10 + outputs[SYS_INDICES[2]][0]
    dia_val = outputs[DIA_INDICES[0]][0] * 10 + outputs[DIA_INDICES[1]][0]
    pulse_val = outputs[PULSE_INDICES[0]][0] * 10 + outputs[PULSE_INDICES[1]][0]

    # 计算平均置信度
    avg_conf = np.mean([outputs[i][1] for i in range(7)])

    return sys_val, dia_val, pulse_val, avg_conf, outputs

def main():
    print('=' * 60)
    print('TFLite 血压识别模型精度测试')
    print('=' * 60)

    # 加载模型
    print(f'\n加载模型: {MODEL_PATH}')
    interpreter = load_tflite_model()
    print('模型加载成功')

    # 获取所有图片
    images = sorted([f for f in os.listdir(IMAGE_DIR) if f.endswith(('.jpg', '.png'))])
    print(f'共 {len(images)} 张图片\n')

    results = []

    for img_file in images:
        label = parse_filename(img_file)
        if label is None:
            continue

        true_sys, true_dia, true_pulse = label
        img_path = os.path.join(IMAGE_DIR, img_file)

        pred_sys, pred_dia, pred_pulse, conf, outputs = predict(interpreter, img_path)

        sys_correct = (pred_sys == true_sys)
        dia_correct = (pred_dia == true_dia)
        pulse_correct = (pred_pulse == true_pulse)
        all_correct = sys_correct and dia_correct and pulse_correct

        results.append({
            'file': img_file,
            'true': (true_sys, true_dia, true_pulse),
            'pred': (pred_sys, pred_dia, pred_pulse),
            'conf': conf,
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
    print('=' * 60)

if __name__ == '__main__':
    main()
