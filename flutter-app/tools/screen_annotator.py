"""
显示屏区域标注工具

用法:
1. 运行此工具: python tools/screen_annotator.py
2. 点击并拖拽鼠标标注显示屏区域
3. 按 'y' 确认，按 'r' 重选，按 'n' 跳过，按 'q' 退出
4. 标注结果自动保存到 dataset/labels/
"""

import cv2
import os
import json
from pathlib import Path

class ScreenAnnotator:
    def __init__(self, image_dir='dataset/images', label_dir='dataset/labels_screen'):
        self.image_dir = Path(image_dir)
        self.label_dir = Path(label_dir)
        self.label_dir.mkdir(parents=True, exist_ok=True)

        self.current_image = None
        self.current_image_path = None
        self.start_point = None
        self.end_point = None
        self.drawing = False
        self.display = None

    def get_image_files(self):
        """获取所有图片文件"""
        files = list(self.image_dir.glob('*.jpg')) + list(self.image_dir.glob('*.png'))
        return sorted(files)

    def get_unlabeled_images(self):
        """获取未标注的图片"""
        unlabeled = []
        for img_file in self.get_image_files():
            label_file = self.label_dir / f'{img_file.stem}.json'
            if not label_file.exists():
                unlabeled.append(img_file)
        return unlabeled

    def mouse_callback(self, event, x, y, flags, param):
        """鼠标回调函数"""
        if event == cv2.EVENT_LBUTTONDOWN:
            self.drawing = True
            self.start_point = (x, y)
            self.end_point = (x, y)

        elif event == cv2.EVENT_MOUSEMOVE:
            if self.drawing:
                self.end_point = (x, y)
                self._redraw()

        elif event == cv2.EVENT_LBUTTONUP:
            self.drawing = False
            self.end_point = (x, y)
            self._redraw()

    def _redraw(self):
        """重绘显示区域"""
        self.display = self.current_image.copy()

        if self.start_point and self.end_point:
            cv2.rectangle(self.display, self.start_point, self.end_point, (0, 255, 0), 2)

            # 显示坐标信息
            x1, y1 = self.start_point
            x2, y2 = self.end_point
            w, h = abs(x2 - x1), abs(y2 - y1)
            x, y = min(x1, x2), min(y1, y2)

            text = f"({x}, {y}, {w}, {h})"
            cv2.putText(self.display, text, (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        cv2.imshow('Annotate Screen', self.display)

    def annotate_image(self, img_path):
        """标注单张图片"""
        self.current_image_path = img_path
        self.current_image = cv2.imread(str(img_path))

        if self.current_image is None:
            return False

        # 缩放以适应屏幕
        h, w = self.current_image.shape[:2]
        scale = min(1200 / w, 800 / h, 1.0)
        if scale < 1.0:
            new_w = int(w * scale)
            new_h = int(h * scale)
            self.current_image = cv2.resize(self.current_image, (new_w, new_h))
            self.scale_factor = 1.0 / scale
        else:
            self.scale_factor = 1.0

        self.start_point = None
        self.end_point = None
        self.drawing = False

        cv2.namedWindow('Annotate Screen')
        cv2.setMouseCallback('Annotate Screen', self.mouse_callback)
        self._redraw()

        print(f"\n当前图片: {img_path.name}")
        print("操作: 鼠标拖拽选区 | y=确认 r=重选 n=跳过 q=退出")

        while True:
            key = cv2.waitKey(0) & 0xFF

            if key == ord('y') and self.start_point and self.end_point:
                # 确认标注
                x1, y1 = self.start_point
                x2, y2 = self.end_point
                x = min(x1, x2)
                y = min(y1, y2)
                w = abs(x2 - x1)
                h = abs(y2 - y1)

                # 还原到原始尺寸
                x = int(x * self.scale_factor)
                y = int(y * self.scale_factor)
                w = int(w * self.scale_factor)
                h = int(h * self.scale_factor)

                # 保存标注
                label_data = {
                    'image': img_path.name,
                    'bbox': [x, y, w, h]
                }

                label_file = self.label_dir / f'{img_path.stem}.json'
                with open(label_file, 'w') as f:
                    json.dump(label_data, f, indent=2)

                print(f"  保存标注: {x}, {y}, {w}, {h}")
                cv2.destroyAllWindows()
                return True

            elif key == ord('r'):
                # 重选
                self.start_point = None
                self.end_point = None
                self._redraw()

            elif key == ord('n'):
                # 跳过
                cv2.destroyAllWindows()
                return None

            elif key == ord('q'):
                # 退出
                cv2.destroyAllWindows()
                return 'exit'

    def run(self):
        """运行标注流程"""
        unlabeled = self.get_unlabeled_images()

        if not unlabeled:
            print("没有需要标注的图片！")
            return

        print(f"=== 显示屏区域标注工具 ===")
        print(f"待标注图片: {len(unlabeled)} 张")
        print(f"图片目录: {self.image_dir}")
        print(f"标注目录: {self.label_dir}")

        completed = 0
        for img_file in unlabeled:
            result = self.annotate_image(img_file)

            if result == 'exit':
                break
            elif result is True:
                completed += 1

        print(f"\n=== 标注完成 ===")
        print(f"本次标注: {completed} 张")
        print(f"剩余未标注: {len(self.get_unlabeled_images())} 张")


if __name__ == '__main__':
    import sys

    # 支持命令行参数指定目录
    image_dir = sys.argv[1] if len(sys.argv) > 1 else 'dataset/images'

    annotator = ScreenAnnotator(image_dir=image_dir)
    annotator.run()
