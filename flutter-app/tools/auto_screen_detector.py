"""
自动显示屏区域检测工具

使用图像处理自动检测血压计显示屏区域
检测结果保存为标注文件，可手动修正
"""

import cv2
import numpy as np
import json
from pathlib import Path

class AutoScreenDetector:
    def __init__(self, image_dir='dataset/images', label_dir='dataset/labels_screen'):
        self.image_dir = Path(image_dir)
        self.label_dir = Path(label_dir)
        self.label_dir.mkdir(parents=True, exist_ok=True)

    def detect_screen(self, image_path):
        """自动检测显示屏区域"""
        img = cv2.imread(str(image_path))
        if img is None:
            return None

        h, w = img.shape[:2]

        # 转灰度图
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # 方法1: 找到高亮区域（LCD屏幕通常较亮）
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        # 形态学操作，连接相邻区域
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (20, 10))
        closed = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

        # 查找轮廓
        contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # 找到最可能是屏幕的轮廓
        best_box = None
        best_score = 0

        for cnt in contours:
            x, y, bw, bh = cv2.boundingRect(cnt)

            # 过滤条件
            area = bw * bh
            if area < 10000:  # 太小
                continue
            if area > w * h * 0.8:  # 太大
                continue
            if bw < w * 0.1 or bh < h * 0.05:  # 太窄或太扁
                continue

            # 计算得分（面积适中 + 位置适中 + 长宽比）
            area_score = area / (w * h)  # 占比
            position_score = 1.0 - abs((y + bh/2) - h/2) / (h/2)  # 中心位置
            aspect_ratio = bw / bh if bh > 0 else 0
            # LCD屏幕通常宽大于高
            aspect_score = 1.0 if 1.5 < aspect_ratio < 10 else 0.5

            score = area_score * 0.4 + position_score * 0.3 + aspect_score * 0.3

            if score > best_score:
                best_score = score
                best_box = (x, y, bw, bh)

        # 如果没找到，使用默认策略：取图像下半部分的中央区域
        if best_box is None:
            # 假设屏幕在图像下半部分
            y_start = int(h * 0.4)
            y_end = int(h * 0.9)
            x_start = int(w * 0.1)
            x_end = int(w * 0.9)

            # 在这个区域内找最亮的部分
            roi = gray[y_start:y_end, x_start:x_end]

            # 使用局部阈值
            _, roi_binary = cv2.threshold(roi, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

            # 找轮廓
            roi_contours, _ = cv2.findContours(roi_binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

            if roi_contours:
                largest = max(roi_contours, key=cv2.contourArea)
                rx, ry, rw, rh = cv2.boundingRect(largest)
                best_box = (x_start + rx, y_start + ry, rw, rh)
            else:
                # 最后的备选：固定区域
                best_box = (int(w * 0.2), int(h * 0.5), int(w * 0.6), int(h * 0.3))

        return best_box

    def process_all(self, skip_existing=True):
        """处理所有图片"""
        img_files = sorted(self.image_dir.glob('*.jpg')) + sorted(self.image_dir.glob('*.png'))

        results = []
        skipped = 0

        print(f"=== 自动显示屏检测 ===")
        print(f"图片目录: {self.image_dir}")
        print(f"标注目录: {self.label_dir}")
        print(f"图片数量: {len(img_files)}")
        print()

        for img_file in img_files:
            label_file = self.label_dir / f'{img_file.stem}.json'

            if skip_existing and label_file.exists():
                skipped += 1
                continue

            print(f"处理: {img_file.name}")

            box = self.detect_screen(img_file)

            if box:
                x, y, w, h = box
                label_data = {
                    'image': img_file.name,
                    'bbox': [int(x), int(y), int(w), int(h)]
                }

                with open(label_file, 'w') as f:
                    json.dump(label_data, f, indent=2)

                print(f"  检测到: x={x}, y={y}, w={w}, h={h}")

                # 可视化结果（保存到preview目录）
                preview_dir = self.image_dir.parent / 'preview_detections'
                preview_dir.mkdir(exist_ok=True)

                img = cv2.imread(str(img_file))
                cv2.rectangle(img, (x, y), (x+w, y+h), (0, 255, 0), 3)
                cv2.putText(img, f"Screen ({x},{y},{w},{h})", (x, y-10),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                preview_path = preview_dir / img_file.name
                cv2.imwrite(str(preview_path), img)

                results.append({'file': img_file.name, 'box': box})
            else:
                print(f"  未检测到屏幕")

        print()
        print(f"=== 处理完成 ===")
        print(f"新检测: {len(results)} 张")
        print(f"跳过已存在: {skipped} 张")

        # 生成预览图说明
        preview_dir = self.image_dir.parent / 'preview_detections'
        if preview_dir.exists():
            print(f"\n预览图已保存到: {preview_dir}")
            print("请检查预览图，如需修正请运行:")
            print("  python tools/screen_annotator.py")

        return results


def main():
    import sys

    image_dir = sys.argv[1] if len(sys.argv) > 1 else 'dataset/images'

    detector = AutoScreenDetector(image_dir=image_dir)
    detector.process_all(skip_existing=True)


if __name__ == '__main__':
    main()
