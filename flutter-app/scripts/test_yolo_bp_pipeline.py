"""测试完整流程: YOLO 检测 LCD -> 裁剪 -> TFLite 血压识别"""
import os, glob, json
from PIL import Image
from ultralytics import YOLO
import numpy as np
import tensorflow as tf

YOLO_PATH = 'assets/models/lcd_detector.pt'
BP_MODEL_PATH = 'assets/models/bpressure_multihead.tflite'
IMG_DIR = 'dataset/images'
LABELS_DIR = 'dataset/labels_screen'
OUTPUT_DIR = 'yolo_crops'

os.makedirs(OUTPUT_DIR, exist_ok=True)

SYS_INDICES = [4, 1, 5]
DIA_INDICES = [3, 0]
PULSE_INDICES = [2, 6]
INPUT_SIZE = 224

yolo_model = YOLO(YOLO_PATH)
bp_interpreter = tf.lite.Interpreter(model_path=BP_MODEL_PATH)
bp_interpreter.allocate_tensors()
input_details = bp_interpreter.get_input_details()
output_details = bp_interpreter.get_output_details()

json_files = sorted(glob.glob(os.path.join(LABELS_DIR, '*.json')))
ok = 0
total = 0

for f in json_files:
    with open(f) as fp:
        data = json.load(fp)

    fname = data['image']
    bbox = data['bbox']
    img_path = os.path.join(IMG_DIR, fname)
    if not os.path.exists(img_path):
        continue

    base = fname.replace('.jpg','').replace('.png','')
    parts = base.split('-')
    true_sys, true_dia, true_pulse = int(parts[0]), int(parts[1]), int(parts[2])

    # YOLO 检测
    results = yolo_model(img_path, verbose=False, conf=0.25)

    best_iou = 0.0
    best_crop = None

    for r in results:
        for box in r.boxes:
            x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]
            conf = box.conf[0].item()

            # 计算 IoU
            ix1 = max(bbox[0], x1)
            iy1 = max(bbox[1], y1)
            ix2 = min(bbox[0]+bbox[2], x2)
            iy2 = min(bbox[1]+bbox[3], y2)
            iw = max(0, ix2 - ix1)
            ih = max(0, iy2 - iy1)
            inter = iw * ih
            area_gt = bbox[2] * bbox[3]
            area_pred = (x2-x1) * (y2-y1)
            union = area_gt + area_pred - inter
            iou = inter / union if union > 0 else 0

            if iou > best_iou:
                best_iou = iou
                img = Image.open(img_path).convert('RGB')
                best_crop = img.crop((x1, y1, x2, y2))

    if best_crop is None:
        # 没有检测到，跳过
        total += 1
        print(f'SKIP {fname}: 未检测到 LCD')
        continue

    # 保存裁剪图
    best_crop.save(os.path.join(OUTPUT_DIR, fname))

    # TFLite 血压识别
    crop_resized = best_crop.resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(crop_resized, dtype=np.float32) / 255.0
    arr = np.expand_dims(arr, axis=0)

    bp_interpreter.set_tensor(input_details[0]['index'], arr)
    bp_interpreter.invoke()

    outputs = []
    for i in range(7):
        t = bp_interpreter.get_tensor(output_details[i]['index'])
        outputs.append(np.argmax(t[0]))

    pred_sys = outputs[SYS_INDICES[0]]*100 + outputs[SYS_INDICES[1]]*10 + outputs[SYS_INDICES[2]]
    pred_dia = outputs[DIA_INDICES[0]]*10 + outputs[DIA_INDICES[1]]
    pred_pulse = outputs[PULSE_INDICES[0]]*10 + outputs[PULSE_INDICES[1]]

    sys_ok = (pred_sys == true_sys)
    dia_ok = (pred_dia == true_dia)
    pulse_ok = (pred_pulse == true_pulse)
    all_ok = sys_ok and dia_ok and pulse_ok

    if all_ok:
        ok += 1
    total += 1

    status = 'OK' if all_ok else 'ERR'
    if not all_ok:
        print(f'{status} {fname}: true={true_sys}/{true_dia},{true_pulse} pred={pred_sys}/{pred_dia},{pred_pulse} IoU={best_iou:.3f}')
    else:
        print(f'{status} {fname} (IoU={best_iou:.3f})')

print(f'\n=== 结果 ===')
print(f'检测到并识别的图片: {ok}/{total} = {ok/total*100:.0f}%')
print(f'跳过(未检测到): {len(json_files) - total}')
