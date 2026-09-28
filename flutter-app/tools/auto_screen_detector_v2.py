"""
改进版显示屏区域检测工具

使用多重策略检测血压计显示屏区域
"""

import cv2
import numpy as np
import json
from pathlib import Path

class ImprovedScreenDetector:
    def __init__(self, image_dir='dataset/images', label_dir='dataset/labels_screen'):
        self.image_dir = Path(image_dir)
        self.label_dir = Path(label_dir)
        self.label_dir.mkdir(parents=True, exist_ok=True)

    def detect_screen_v2(self, image_path):
        """改进的显示屏检测算法"""
        img = cv2.imread(str(image_path))
        if img is None:
            return None

        h, w = img.shape[:2]

        # 多尺度检测
        candidates = []

        # 策略1: 边缘检测 + 矩形检测
        box1 = self._detect_by_edges(img)
        if box1:
            candidates.append(('edges', box1))

        # 策略2: 颜色聚类（找LCD常见的绿色/蓝色背景）
        box2 = self._detect_by_color(img)
        if box2:
            candidates.append(('color', box2))

        # 策略3: 密度分析（找数字密集区域）
        box3 = self._detect_by_density(img)
        if box3:
            candidates.append(('density', box3))

        # 策略4: 默认位置（图像下半部分中央）
        box4 = self._default_position(img)
        if box4:
            candidates.append(('default', box4))

        # 选择最佳候选
        best_box = self._select_best_candidate(img, candidates)

        return best_box

    def _detect_by_edges(self, img):
        """基于边缘检测"""
        h, w = img.shape[:2]

        # 转灰度
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # 高斯模糊减少噪声
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)

        # Canny边缘检测
        edges = cv2.Canny(blurred, 50, 150)

        # 膨胀连接边缘
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
        closed = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel)

        # 查找轮廓
        contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        best_box = None
        best_score = 0

        for cnt in contours:
            # 近似为多边形
            peri = cv2.arcLength(cnt, True)
            approx = cv2.approxPolyDP(cnt, 0.02 * peri, True)

            x, y, bw, bh = cv2.boundingRect(cnt)

            # 过滤条件
            area = bw * bh
            if area < 10000:
                continue
            if area > w * h * 0.5:
                continue

            # 计算得分（矩形性 + 位置 + 面积）
            rect_score = len(approx) == 4  # 是矩形
            area_score = area / (w * h)
            position_score = 1.0 - abs((y + bh/2) - h/2) / (h/2)

            score = rect_score * 0.5 + area_score * 0.3 + position_score * 0.2

            if score > best_score:
                best_score = score
                best_box = (x, y, bw, bh)

        return best_box

    def _detect_by_color(self, img):
        """基于颜色检测（找LCD常见的绿色/蓝绿色背景）"""
        h, w = img.shape[:2]

        # 转换到HSV空间
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

        # LCD屏幕可能的颜色范围（绿色/蓝绿色）
        # 绿色: H=40-80, S=30-100, V=50-100
        lower_green = np.array([40, 30, 50])
        upper_green = np.array([80, 255, 255])

        # 蓝绿色
        lower_cyan = np.array([80, 30, 50])
        upper_cyan = np.array([100, 255, 255])

        # 创建掩码
        mask1 = cv2.inRange(hsv, lower_green, upper_green)
        mask2 = cv2.inRange(hsv, lower_cyan, upper_cyan)
        mask = cv2.bitwise_or(mask1, mask2)

        # 形态学操作
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (20, 20))
        closed = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)

        # 查找轮廓
        contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if not contours:
            return None

        # 找最大轮廓
        largest = max(contours, key=cv2.contourArea)
        x, y, bw, bh = cv2.boundingRect(largest)

        # 扩展边界框
        margin = 20
        x = max(0, x - margin)
        y = max(0, y - margin)
        bw = min(w - x, bw + 2 * margin)
        bh = min(h - y, bh + 2 * margin)

        return (x, y, bw, bh)

    def _detect_by_density(self, img):
        """基于密度分析（找暗像素密集区域）"""
        h, w = img.shape[:2]

        # 转灰度
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # 只关注图像下半部分（屏幕通常在下半部分）
        y_start = int(h * 0.4)
        y_end = int(h * 0.95)
        roi = gray[y_start:y_end, :]

        # 二值化（找暗像素，即数字）
        _, binary = cv2.threshold(roi, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

        # 垂直投影 - 找到数字区域的水平范围
        v_proj = np.sum(binary, axis=0)
        v_threshold = np.max(v_proj) * 0.3

        # 找到连续超过阈值的区域
        in_region = False
        regions = []
        start = 0

        for i, val in enumerate(v_proj):
            if val > v_threshold and not in_region:
                in_region = True
                start = i
            elif val <= v_threshold and in_region:
                in_region = False
                if i - start > w * 0.1:  # 最小宽度
                    regions.append((start, i))

        if in_region:
            regions.append((start, len(v_proj)))

        if regions:
            # 合并相邻或接近的区域
            merged = [regions[0]]
            for r in regions[1:]:
                if r[0] - merged[-1][1] < w * 0.05:
                    merged[-1] = (merged[-1][0], r[1])
                else:
                    merged.append(r)

            # 找最大区域
            largest = max(merged, key=lambda r: r[1] - r[0])
            x = largest[0]
            box_w = largest[1] - largest[0]

            # 水平投影 - 找到数字区域的垂直范围
            h_roi = binary[:, x:x + box_w]
            h_proj = np.sum(h_roi, axis=1)
            h_threshold = np.max(h_proj) * 0.3

            h_regions = []
            h_in_region = False
            h_start = 0

            for i, val in enumerate(h_proj):
                if val > h_threshold and not h_in_region:
                    h_in_region = True
                    h_start = i
                elif val <= h_threshold and h_in_region:
                    h_in_region = False
                    if i - h_start > len(h_proj) * 0.1:
                        h_regions.append((h_start, i))

            if h_in_region:
                h_regions.append((h_start, len(h_proj)))

            if h_regions:
                h_largest = max(h_regions, key=lambda r: r[1] - r[0])
                y = y_start + h_largest[0]
                box_h = h_largest[1] - h_largest[0]

                # 扩展边界
                margin = 30
                return (
                    max(0, int(x - margin)),
                    max(0, int(y - margin)),
                    min(w - x + margin, int(box_w + 2 * margin)),
                    min(h - y + margin, int(box_h + 2 * margin))
                )

        return None

    def _default_position(self, img):
        """默认位置策略"""
        h, w = img.shape[:2]

        # 图像下半部分的中央区域
        # LCD屏幕通常占图像宽度的40-70%，高度的20-40%
        x = int(w * 0.15)
        y = int(h * 0.45)
        box_w = int(w * 0.7)
        box_h = int(h * 0.35)

        return (x, y, box_w, box_h)

    def _select_best_candidate(self, img, candidates):
        """从候选框中选择最佳"""
        if not candidates:
            return None

        if len(candidates) == 1:
            return candidates[0][1]

        h, w = img.shape[:2]

        # 计算每个候选的得分
        scored = []
        for method, box in candidates:
            x, y, bw, bh = box

            # 得分标准：
            # 1. 面积适中 (10%-60%)
            area_ratio = (bw * bh) / (w * h)
            area_score = 1.0 - abs(area_ratio - 0.25) / 0.25

            # 2. 长宽比 (LCD通常宽>高，比例在1.5-5之间)
            aspect = bw / bh if bh > 0 else 0
            aspect_score = 1.0 if 1.5 < aspect < 5 else max(0, 1.0 - abs(aspect - 2.5) / 2.5)

            # 3. 位置 (下半部分中央)
            center_y = (y + bh / 2) / h
            position_score = 1.0 - abs(center_y - 0.65) / 0.35

            # 4. 方法权重
            method_weights = {
                'edges': 1.0,
                'color': 1.2,
                'density': 1.5,
                'default': 0.5
            }
            method_weight = method_weights.get(method, 0.5)

            total_score = (area_score * 0.3 + aspect_score * 0.2 +
                          position_score * 0.2) * method_weight

            scored.append((method, box, total_score))

        # 返回得分最高的
        scored.sort(key=lambda x: x[2], reverse=True)
        return scored[0][1]

    def process_all(self, skip_existing=True):
        """处理所有图片"""
        img_files = sorted(self.image_dir.glob('*.jpg')) + sorted(self.image_dir.glob('*.png'))

        results = []
        skipped = 0

        print(f"=== 改进版显示屏检测 ===")
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

            box = self.detect_screen_v2(img_file)

            if box:
                x, y, w, h = box
                label_data = {
                    'image': img_file.name,
                    'bbox': [int(x), int(y), int(w), int(h)]
                }

                with open(label_file, 'w') as f:
                    json.dump(label_data, f, indent=2)

                print(f"  检测到: x={x}, y={y}, w={w}, h={h}")

                # 保存预览
                preview_dir = self.image_dir.parent / 'preview_detections_v2'
                preview_dir.mkdir(exist_ok=True)

                img = cv2.imread(str(img_file))
                display = img.copy()
                cv2.rectangle(display, (x, y), (x+w, y+h), (0, 255, 0), 3)
                cv2.putText(display, f"Screen ({x},{y},{w},{h})", (x, max(10, y-10)),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                preview_path = preview_dir / img_file.name
                cv2.imwrite(str(preview_path), display)

                results.append({'file': img_file.name, 'box': box})
            else:
                print(f"  未检测到屏幕")

        print()
        print(f"=== 处理完成 ===")
        print(f"新检测: {len(results)} 张")
        print(f"跳过已存在: {skipped} 张")

        preview_dir = self.image_dir.parent / 'preview_detections_v2'
        if preview_dir.exists():
            print(f"\n预览图已保存到: {preview_dir}")

        return results


def main():
    import sys

    image_dir = sys.argv[1] if len(sys.argv) > 1 else 'dataset/images'

    detector = ImprovedScreenDetector(image_dir=image_dir)
    detector.process_all(skip_existing=False)


if __name__ == '__main__':
    main()
