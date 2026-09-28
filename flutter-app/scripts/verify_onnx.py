#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
验证 ONNX 模型的推理能力
使用 onnxruntime 加载训练好的 YOLOv8n LCD 检测模型
"""
import os
import numpy as np
import cv2
import onnxruntime as ort

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ONNX_PATH = os.path.join(BASE_DIR, "assets", "models", "lcd_detector.onnx")

IMG_SIZE = 640
CONF_THRESHOLD = 0.25
IOU_THRESHOLD = 0.45


def preprocess_image(img):
    """预处理图片为 YOLO 输入格式 (letterbox)"""
    if len(img.shape) == 2:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
    elif img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)

    h, w = img.shape[:2]
    scale = min(IMG_SIZE / w, IMG_SIZE / h)
    new_w = int(w * scale)
    new_h = int(h * scale)

    resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

    pad_w = (IMG_SIZE - new_w) // 2
    pad_h = (IMG_SIZE - new_h) // 2
    padded = cv2.copyMakeBorder(resized, pad_h, IMG_SIZE - new_h - pad_h,
                                 pad_w, IMG_SIZE - new_w - pad_w,
                                 cv2.BORDER_CONSTANT, value=(114, 114, 114))

    img_blob = np.transpose(padded.astype(np.float32) / 255.0, (2, 0, 1))
    img_blob = np.expand_dims(img_blob, axis=0)

    return img_blob, scale, pad_w, pad_h


def postprocess_detections(output, scale, pad_w, pad_h, orig_w, orig_h):
    """
    解析 YOLOv8 ONNX 输出为边界框
    ONNX 输出: (1, 5, 8400) - 归一化到 0-1 范围
    需要乘以 IMG_SIZE 得到 letterbox 空间的像素坐标
    """
    output = output[0]  # (5, 8400)

    boxes = []
    for i in range(output.shape[1]):
        # ONNX 输出已经是 0-1 归一化值，需要转换到 letterbox 空间
        cx_norm = output[0, i]
        cy_norm = output[1, i]
        w_norm = output[2, i]
        h_norm = output[3, i]
        conf = output[4, i]

        if conf < CONF_THRESHOLD:
            continue

        # 转换到 letterbox 640x640 空间
        cx = cx_norm * IMG_SIZE
        cy = cy_norm * IMG_SIZE
        bw = w_norm * IMG_SIZE
        bh = h_norm * IMG_SIZE

        # 反 letterbox: 去掉 padding
        cx = cx - pad_w
        cy = cy - pad_h

        # 缩放回原始图片
        cx = cx / scale
        cy = cy / scale
        bw = bw / scale
        bh = bh / scale

        x1 = int(cx - bw / 2)
        y1 = int(cy - bh / 2)
        x2 = int(cx + bw / 2)
        y2 = int(cy + bh / 2)

        x1 = max(0, x1)
        y1 = max(0, y1)
        x2 = min(orig_w, x2)
        y2 = min(orig_h, y2)

        if x2 > x1 and y2 > y1:
            boxes.append([x1, y1, x2, y2, float(conf)])

    if len(boxes) == 0:
        return []

    boxes = np.array(boxes)
    indices = cv2.dnn.NMSBoxes(
        boxes[:, :4].tolist(),
        boxes[:, 4].tolist(),
        CONF_THRESHOLD,
        IOU_THRESHOLD
    )

    results = []
    if len(indices) > 0:
        for i in indices.flatten():
            x1, y1, x2, y2, conf = boxes[i]
            results.append({
                "x": int(x1),
                "y": int(y1),
                "width": int(x2 - x1),
                "height": int(y2 - y1),
                "confidence": round(float(conf), 4)
            })

    return results


def run_inference(image_path, session):
    """对单张图片进行推理"""
    img = cv2.imread(image_path)
    if img is None:
        print(f"无法加载图片: {image_path}")
        return None, None

    orig_h, orig_w = img.shape[:2]
    input_blob, scale, pad_w, pad_h = preprocess_image(img)

    input_name = session.get_inputs()[0].name
    output = session.run(None, {input_name: input_blob})[0]

    detections = postprocess_detections(output, scale, pad_w, pad_h, orig_w, orig_h)

    # 绘制检测结果
    img_vis = img.copy()
    for det in detections:
        cv2.rectangle(img_vis, (det["x"], det["y"]),
                      (det["x"] + det["width"], det["y"] + det["height"]),
                      (0, 255, 0), 3)
        cv2.putText(img_vis, f"LCD {det['confidence']:.2f}",
                    (det["x"], det["y"] - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    return detections, img_vis


def main():
    print("=" * 60)
    print("YOLOv8n LCD 检测器 - ONNX 模型验证")
    print("=" * 60)

    session = ort.InferenceSession(ONNX_PATH, providers=["CPUExecutionProvider"])
    input_info = session.get_inputs()[0]
    output_info = session.get_outputs()[0]
    print(f"模型输入: {input_info.name} shape={input_info.shape}")
    print(f"模型输出: {output_info.name} shape={output_info.shape}")
    print()

    # 加载标注用于对比
    import json
    labels_dir = os.path.join(BASE_DIR, "dataset", "labels_screen")

    images_dir = os.path.join(BASE_DIR, "dataset", "images")
    test_images = sorted([f for f in os.listdir(images_dir) if f.endswith((".jpg", ".png"))])[:10]

    out_dir = os.path.join(BASE_DIR, "dataset", "preview_detections_v2")
    os.makedirs(out_dir, exist_ok=True)

    total_detected = 0
    for img_name in test_images:
        img_path = os.path.join(images_dir, img_name)
        detections, img_vis = run_inference(img_path, session)

        base = os.path.splitext(img_name)[0]
        label_path = os.path.join(labels_dir, base + ".json")

        print(f"图片: {img_name}")
        if detections:
            print(f"  检测到 {len(detections)} 个 LCD:")
            for d in detections:
                print(f"    x={d['x']}, y={d['y']}, w={d['width']}, h={d['height']}, conf={d['confidence']}")
            total_detected += 1
        else:
            print("  未检测到 LCD")

        if os.path.exists(label_path):
            with open(label_path, "r") as f:
                data = json.load(f)
            bbox = data["bbox"]
            print(f"  标注: x={bbox[0]}, y={bbox[1]}, w={bbox[2]}, h={bbox[3]}")
            center_x = bbox[0] + bbox[2] // 2
            center_y = bbox[1] + bbox[3] // 2
            print(f"  标注中心: ({center_x}, {center_y})")
            if detections:
                det_cx = detections[0]["x"] + detections[0]["width"] // 2
                det_cy = detections[0]["y"] + detections[0]["height"] // 2
                err_x = abs(det_cx - center_x)
                err_y = abs(det_cy - center_y)
                print(f"  检测中心: ({det_cx}, {det_cy}) 误差: ({err_x}, {err_y})")

        if img_vis is not None:
            out_path = os.path.join(out_dir, f"onnx_{img_name}")
            cv2.imwrite(out_path, img_vis)
        print()

    print("=" * 60)
    print(f"检测结果: {total_detected}/{len(test_images)} 张图片检测到 LCD")
    print("验证完成！")


if __name__ == "__main__":
    main()
