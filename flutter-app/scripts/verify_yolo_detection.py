"""验证 YOLO LCD 检测模型在测试集上的效果"""
import os, glob, json
from ultralytics import YOLO
from PIL import Image, ImageDraw

MODEL_PATH = 'assets/models/lcd_detector.pt'
IMG_DIR = 'dataset/images'
LABELS_DIR = 'dataset/labels_screen'
OUTPUT_DIR = 'lcd_detection_output'

os.makedirs(OUTPUT_DIR, exist_ok=True)

model = YOLO(MODEL_PATH)

# 加载标注
json_files = sorted(glob.glob(os.path.join(LABELS_DIR, '*.json')))
total = len(json_files)
correct_iou50 = 0
correct_iou25 = 0

for f in json_files:
    with open(f) as fp:
        data = json.load(fp)

    fname = data['image']
    bbox = data['bbox']  # [x, y, w, h]
    img_path = os.path.join(IMG_DIR, fname)
    if not os.path.exists(img_path):
        continue

    img = Image.open(img_path)

    # 推理
    results = model(img_path, verbose=False, conf=0.25)

    # 画结果
    draw = ImageDraw.Draw(img)

    # 画真实框 (绿色)
    draw.rectangle([bbox[0], bbox[1], bbox[0]+bbox[2], bbox[1]+bbox[3]], outline='green', width=3)
    draw.text((bbox[0], bbox[1]-15), 'GT', fill='green')

    best_iou = 0.0
    best_pred = None

    for r in results:
        for box in r.boxes:
            x1, y1, x2, y2 = box.xyxy[0].tolist()
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
                best_pred = (x1, y1, x2, y2, conf)

            # 画预测框 (红色)
            draw.rectangle([x1, y1, x2, y2], outline='red', width=2)
            draw.text((x1, y1-15), f'{conf:.2f}', fill='red')

    if best_iou >= 0.5:
        correct_iou50 += 1
    if best_iou >= 0.25:
        correct_iou25 += 1

    status = 'OK' if best_iou >= 0.5 else 'PARTIAL' if best_iou >= 0.25 else 'FAIL'
    print(f'{status} {fname}: IoU={best_iou:.3f} (pred={len(results[0].boxes)} boxes)')

    # 保存图片
    img.save(os.path.join(OUTPUT_DIR, fname))

print(f'\n=== 结果 ===')
print(f'总图片数: {total}')
print(f'IoU >= 0.5: {correct_iou50}/{total} = {correct_iou50/total*100:.0f}%')
print(f'IoU >= 0.25: {correct_iou25}/{total} = {correct_iou25/total*100:.0f}%')
print(f'可视化输出: {OUTPUT_DIR}/')
