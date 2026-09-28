"""基于 TFLite 置信度的自适应 LCD 裁剪方案
不需要精确检测 LCD 位置，而是用 TFLite 模型自身的置信度来选择最佳裁剪区域
"""
import os, json, glob, time
from PIL import Image
import numpy as np
import tensorflow as tf

# 位置先验 (基于 63 张标注图片的统计)
POSITION_PRIORS = {
    '1279x1706': {'rx': 0.256, 'ry': 0.572, 'rw': 0.663, 'rh': 0.258, 'rx_s': 0.137, 'ry_s': 0.150},
    '3060x4080': {'rx': 0.190, 'ry': 0.444, 'rw': 0.603, 'rh': 0.261, 'rx_s': 0.099, 'ry_s': 0.091},
    '3072x4096': {'rx': 0.359, 'ry': 0.394, 'rw': 0.359, 'rh': 0.386, 'rx_s': 0.245, 'ry_s': 0.059},
    '4096x3072': {'rx': 0.000, 'ry': 0.390, 'rw': 0.269, 'rh': 0.570, 'rx_s': 0.200, 'ry_s': 0.100},
    '1080x1919': {'rx': 0.033, 'ry': 0.708, 'rw': 0.967, 'rh': 0.257, 'rx_s': 0.200, 'ry_s': 0.100},
}

# TFLite 输出索引映射
SYS_INDICES = [4, 1, 5]
DIA_INDICES = [3, 0]
PULSE_INDICES = [2, 6]
INPUT_SIZE = 224
MODEL_PATH = 'assets/models/bpressure_multihead.tflite'

def load_model():
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    return interpreter

def preprocess(img):
    img = img.resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    return np.expand_dims(arr, axis=0)

def predict(interpreter, img):
    input_data = preprocess(img)
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    outputs = []
    for i in range(7):
        t = interpreter.get_tensor(output_details[i]['index'])
        outputs.append(np.max(t[0]))
    return np.mean(outputs)  # 返回平均置信度

def decode_output(interpreter):
    output_details = interpreter.get_output_details()
    outputs = []
    for i in range(7):
        t = interpreter.get_tensor(output_details[i]['index'])
        digit = np.argmax(t[0])
        outputs.append(digit)
    sys_val = outputs[SYS_INDICES[0]]*100 + outputs[SYS_INDICES[1]]*10 + outputs[SYS_INDICES[2]]
    dia_val = outputs[DIA_INDICES[0]]*10 + outputs[DIA_INDICES[1]]
    pulse_val = outputs[PULSE_INDICES[0]]*10 + outputs[PULSE_INDICES[1]]
    return sys_val, dia_val, pulse_val

def generate_crop_candidates(img_w, img_h):
    """生成多个候选裁剪区域"""
    key = f'{img_w}x{img_h}'
    prior = POSITION_PRIORS.get(key, {'rx':0.3, 'ry':0.5, 'rw':0.5, 'rh':0.4, 'rx_s':0.2, 'ry_s':0.1})

    candidates = []

    # 1. 基于先验的中心区域 + 偏移
    offsets = [
        (0, 0), (-1, 0), (1, 0), (0, -1), (0, 1),
        (-1, -1), (1, -1), (-1, 1), (1, 1),
        (0, -2), (0, 2), (-2, 0), (2, 0),
    ]

    for dx, dy in offsets:
        rx = prior['rx'] + dx * prior['rx_s'] * 0.5
        ry = prior['ry'] + dy * prior['ry_s'] * 0.5
        rw = prior['rw']
        rh = prior['rh']

        x1 = max(0, int(img_w * rx))
        y1 = max(0, int(img_h * ry))
        x2 = min(img_w, int(img_w * (rx + rw)))
        y2 = min(img_h, int(img_h * (ry + rh)))

        if (x2-x1) > 50 and (y2-y1) > 50:
            candidates.append((x1, y1, x2-x1, y2-y1))

    # 2. 全图居中区域（覆盖未知分辨率情况）
    for scale in [0.3, 0.4, 0.5, 0.6]:
        cw = int(img_w * scale)
        ch = int(img_h * scale * 0.8)
        cx = (img_w - cw) // 2
        cy = (img_h - ch) // 2
        candidates.append((cx, cy, cw, ch))

    # 3. 偏下区域（有些照片 LCD 在底部）
    for scale in [0.3, 0.4, 0.5]:
        cw = int(img_w * scale)
        ch = int(img_h * scale)
        cx = (img_w - cw) // 2
        cy = int(img_h * 0.5)
        candidates.append((cx, cy, cw, ch))

    # 去重
    unique = []
    seen = set()
    for c in candidates:
        key_c = (c[0]//20, c[1]//20, c[2]//20, c[3]//20)
        if key_c not in seen:
            seen.add(key_c)
            unique.append(c)

    return unique

def score_bp_result(sys_val, dia_val, pulse_val, conf):
    """评分: 血压值合理性 + 置信度"""
    score = 0.0
    # 收缩压合理性 (70-200 mmHg)
    if 70 <= sys_val <= 200:
        score += 3.0
        # 最佳范围 90-160
        if 90 <= sys_val <= 160:
            score += 2.0
    elif 50 <= sys_val < 70 or 200 < sys_val <= 250:
        score += 0.5
    else:
        score -= 2.0  # 明显不合理

    # 舒张压合理性 (40-130 mmHg)
    if 40 <= dia_val <= 130:
        score += 3.0
        if 50 <= dia_val <= 110:
            score += 2.0
    else:
        score -= 2.0

    # 脉搏合理性 (40-150 bpm)
    if 40 <= pulse_val <= 150:
        score += 2.0
        if 50 <= pulse_val <= 120:
            score += 1.0
    else:
        score -= 2.0

    # 收缩压 > 舒张压
    if sys_val > dia_val:
        score += 2.0

    # 差值合理性 (脉压差 20-80)
    pp = sys_val - dia_val
    if 20 <= pp <= 80:
        score += 2.0

    # 加上置信度
    score += conf * 5.0

    return score

def detect_and_recognize(interpreter, img_path, ground_truth=None):
    """自动检测 LCD 并识别"""
    img = Image.open(img_path).convert('RGB')
    w, h = img.size

    candidates = generate_crop_candidates(w, h)

    best_score = -999
    best_result = None
    best_crop = None
    best_conf = 0

    for (x, y, cw, ch) in candidates:
        crop = img.crop((x, y, x+cw, y+ch))
        input_data = preprocess(crop)

        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()

        outputs = []
        for i in range(7):
            t = interpreter.get_tensor(output_details[i]['index'])
            outputs.append((np.argmax(t[0]), np.max(t[0])))

        sys_val = outputs[SYS_INDICES[0]][0]*100 + outputs[SYS_INDICES[1]][0]*10 + outputs[SYS_INDICES[2]][0]
        dia_val = outputs[DIA_INDICES[0]][0]*10 + outputs[DIA_INDICES[1]][0]
        pulse_val = outputs[PULSE_INDICES[0]][0]*10 + outputs[PULSE_INDICES[1]][0]
        conf = np.mean([o[1] for o in outputs])

        score = score_bp_result(sys_val, dia_val, pulse_val, conf)

        if score > best_score:
            best_score = score
            best_result = (sys_val, dia_val, pulse_val)
            best_conf = conf
            best_crop = crop

    return best_result, best_conf, best_crop

def main():
    print('=' * 60)
    print('自适应裁剪 + TFLite 置信度选择测试')
    print('=' * 60)

    interpreter = load_model()
    labels_dir = 'dataset/labels_screen'
    json_files = sorted(glob.glob(os.path.join(labels_dir, '*.json')))
    img_dir = 'dataset/images'

    # 加载标注
    annotations = []
    for f in json_files:
        with open(f) as fp:
            data = json.load(fp)
        fname = data['image']
        img_path = os.path.join(img_dir, fname)
        if not os.path.exists(img_path):
            continue
        im = Image.open(img_path)
        bbox = data['bbox']
        base = fname.replace('.jpg','').replace('.png','')
        parts = base.split('-')
        annotations.append({
            'file': fname, 'img_w': im.width, 'img_h': im.height,
            'true_sys': int(parts[0]),
            'true_dia': int(parts[1]),
            'true_pulse': int(parts[2]),
            'x1': bbox[0], 'y1': bbox[1], 'w': bbox[2], 'h': bbox[3]
        })

    print(f'共 {len(annotations)} 张图片\n')

    results = []
    t0 = time.time()

    for i, ann in enumerate(annotations):
        img_path = os.path.join(img_dir, ann['file'])
        pred, conf, crop = detect_and_recognize(interpreter, img_path)

        sys_ok = (pred[0] == ann['true_sys'])
        dia_ok = (pred[1] == ann['true_dia'])
        pulse_ok = (pred[2] == ann['true_pulse'])
        all_ok = sys_ok and dia_ok and pulse_ok

        results.append({
            'file': ann['file'],
            'true': (ann['true_sys'], ann['true_dia'], ann['true_pulse']),
            'pred': pred,
            'conf': conf,
            'all_ok': all_ok,
        })

        status = '[OK]' if all_ok else '[ERR]'
        if not all_ok:
            print(f'{status} {ann["file"]}: true={ann["true_sys"]}/{ann["true_dia"]},{ann["true_pulse"]} pred={pred[0]}/{pred[1]},{pred[2]} conf={conf:.3f}')
        else:
            print(f'{status} {ann["file"]}')

    elapsed = time.time() - t0

    total = len(results)
    ok_count = sum(1 for r in results if r['all_ok'])
    avg_conf = np.mean([r['conf'] for r in results])

    print('\n' + '=' * 60)
    print(f'结果: {ok_count}/{total} = {ok_count/total*100:.1f}%')
    print(f'平均置信度: {avg_conf:.3f}')
    print(f'总耗时: {elapsed:.0f}s ({elapsed/total:.1f}s/张)')
    print('=' * 60)

if __name__ == '__main__':
    main()
