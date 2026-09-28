"""
牛津大学血压计LCD识别算法 - Python完整实现
基于论文: "Automated method for detecting and reading seven-segment digits
from images of blood glucose meters and blood pressure monitors" - E.Finnegan

流程:
1. Blob提取 (MSER + Sauvola二值化两条路径)
2. Blob过滤 (规则过滤 + 特征向量分类)
3. Blob组合 (椭圆拟合组合)
4. 数字分类 (HOG + MLP)
5. 数字组合为读数
"""

import cv2
import numpy as np
from scipy import ndimage
from skimage import measure
from skimage.feature import hog
from skimage.morphology import binary_dilation, disk
import matplotlib.pyplot as plt
from collections import defaultdict
import warnings
warnings.filterwarnings('ignore')


class OxfordAlgorithm:
    """牛津大学血压计LCD识别算法"""

    def __init__(self, device_type='BP', params=None):
        """
        初始化算法参数

        Args:
            device_type: 'BP' 血压计 或 'BG' 血糖仪
            params: 自定义参数字典，None则使用牛津默认参数
        """
        self.device_type = device_type
        self.params = self._get_default_params() if params is None else params

    def _get_default_params(self):
        """牛津论文默认参数"""
        params = {
            # 图像尺寸
            'height': 500,
            'width': None,  # 根据原图比例计算

            # Sauvola路径参数
            'blob_extraction': {
                'Sauv': {
                    'sigma_s': 30,    # 双边滤波空间方差
                    'sigma_r': 0.1,   # 双边滤波范围方差
                    'gamma': 1.5,     # Retinex gamma
                    'k': 0.34,        # Sauvola k参数
                    'alpha': 0.059,   # Sauvola窗口比例
                },
                'MSER': {
                    'sigma_s': 30,
                    'sigma_r': 0.1,
                    'gamma': 0.7,
                    'T': 0.3,         # MSER最大面积变化
                    'Delta': 0.02,    # MSER阈值步长 (0.02 * 100 = 2)
                }
            },

            # Blob聚类参数
            'blob_clustering': {
                'major_axis': 1.6,   # 主轴放大因子
                'minor_axis': 1.3,   # 副轴放大因子
                'thresholds': {
                    'Hue': 0.3,
                    'SW': 0.2,
                    'D': 0.01,
                }
            },

            # 数字聚类参数
            'digit_clustering': {
                'minor_axis': 2,
                'minor_axis_one': 10,  # 数字1副轴放大
                'major_axis': 0.4,
                'thresholds': {
                    'Hue': 0.3,
                    'h': 0.1,           # 高度差阈值
                }
            },

            # 过滤参数 - Round 1 (BP设备)
            'filtering_round1': {
                'MinArea': 0.0001,    # 相对总面积
                'MaxArea': 0.4,
                'MinHeight': 0.01,    # 相对图像高度
                'MaxHeight': 0.7,
                'MinWidth': 0.001,    # 相对图像宽度
                'MaxWidth': 0.5,
                'RatioMin': 0.1,
                'RatioMax': 8,
                'NormalisedVariance': 5,
                'DiameterMedian': 6,
            },

            # 过滤参数 - Round 2 (BP设备)
            'filtering_round2': {
                'MinArea': 0.001,
                'MaxArea': 0.3,
                'MinHeight': 0.05,
                'MaxHeight': 0.5,
                'MinWidth': 0.01,
                'MaxWidth': 0.5,
                'RatioMin': 0.5,
                'RatioMax': 5,
                'NormalisedVariance': 10,
                'DiameterMedian': 15,
            },

            # 血压值范围
            'bp_ranges': {
                'Sys': (70, 210),
                'Dia': (40, 130),
                'HR': (40, 200),
            },

            # 血糖值范围
            'bg_range': (2.8, 21.1),
        }
        return params

    def retinex_filter(self, img, sigma_s=30, sigma_r=0.1, gamma=1.5):
        """
        Retinex滤波器 - 使用双边滤波增强对比度

        Args:
            img: 灰度图像 (0-1范围)
            sigma_s: 空间方差
            sigma_r: 范围方差
            gamma: gamma校正参数

        Returns:
            滤波后的图像
        """
        # 确保图像在正确范围
        img = np.clip(img, 0, 1)

        # 使用双边滤波近似Retinex
        # I_retinex = log(I) - log(BilateralFilter(I))
        img_uint8 = (img * 255).astype(np.uint8)

        # 双边滤波
        filtered = cv2.bilateralFilter(img_uint8, d=-1, sigmaColor=sigma_r*255, sigmaSpace=sigma_s)

        # Retinex: log(I) - log(filtered)
        img_float = img.astype(np.float64) + 1e-6
        filtered_float = filtered.astype(np.float64) / 255.0 + 1e-6

        retinex = np.log(img_float) - np.log(filtered_float)

        # 归一化到0-1范围
        retinex = (retinex - retinex.min()) / (retinex.max() - retinex.min() + 1e-6)

        # Gamma校正
        retinex = np.power(retinex, gamma)

        return retinex

    def sauvola_binarization(self, img, window_size=None, k=0.34):
        """
        Sauvola自适应二值化

        Args:
            img: 灰度图像
            window_size: 窗口大小，None则根据参数计算
            k: Sauvola参数

        Returns:
            二值化图像
        """
        if window_size is None:
            alpha = self.params['blob_extraction']['Sauv']['alpha']
            window_size = int(self.params['height'] * alpha)

        window_size = max(3, window_size)

        # 计算局部均值和标准差
        img_float = img.astype(np.float64)

        # 使用积分图加速
        integral = cv2.integral(img_float)
        integral_sq = cv2.integral(img_float ** 2)

        h, w = img.shape
        result = np.zeros_like(img, dtype=np.uint8)

        half_w = window_size // 2

        for y in range(h):
            for x in range(w):
                y1 = max(0, y - half_w)
                y2 = min(h, y + half_w + 1)
                x1 = max(0, x - half_w)
                x2 = min(w, x + half_w + 1)

                area = (y2 - y1) * (x2 - x1)

                sum_val = integral[y2, x2] - integral[y1, x2] - integral[y2, x1] + integral[y1, x1]
                sum_sq = integral_sq[y2, x2] - integral_sq[y1, x2] - integral_sq[y2, x1] + integral_sq[y1, x1]

                mean = sum_val / area
                std = np.sqrt(max(0, sum_sq / area - mean ** 2))

                # Sauvola阈值
                threshold = mean * (1 + k * ((std / 128) - 1))

                result[y, x] = 255 if img[y, x] > threshold else 0

        return result

    def extract_blobs_mser(self, img):
        """
        MSER blob提取

        Args:
            img: BGR图像

        Returns:
            blobs列表，每个blob包含PixelList和各种统计信息
        """
        p = self.params['blob_extraction']['MSER']

        # 获取HSV V通道
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float64)
        hsv[:,:,0] /= 180.0  # H归一化
        hsv[:,:,1] /= 255.0  # S归一化
        hsv[:,:,2] /= 255.0  # V归一化

        value = hsv[:,:,2]
        hue = hsv[:,:,0]

        # Retinex滤波
        v_retinex = self.retinex_filter(value, p['sigma_s'], p['sigma_r'], p['gamma'])

        # MSER检测
        v_uint8 = (v_retinex * 255).astype(np.uint8)

        # OpenCV MSER参数
        delta = int(p['Delta'] * 100)  # 阈值步长
        min_area = int(self.params['height'] * self.params['width'] * 0.0001)
        max_area = int(self.params['height'] * self.params['width'] * 0.4)
        max_variation = p['T']

        mser = cv2.MSER_create(
            delta=delta,
            min_area=min_area,
            max_area=max_area,
            max_variation=max_variation
        )

        regions, _ = mser.detectRegions(v_uint8)

        # 处理每个region
        blobs = []
        for region in regions:
            # 计算统计信息
            blob_stats = self._compute_blob_stats(region, img.shape[:2], hue)

            # 去除重叠区域 (保留面积最大的)
            blobs.append({
                'PixelList': region,
                'stats': blob_stats
            })

        # 去重叠
        blobs = self._remove_overlapping_regions(blobs)

        return blobs

    def extract_blobs_sauvola(self, img):
        """
        Sauvola二值化blob提取

        Args:
            img: BGR图像

        Returns:
            blobs列表
        """
        p = self.params['blob_extraction']['Sauv']

        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float64)
        hsv[:,:,0] /= 180.0
        hsv[:,:,1] /= 255.0
        hsv[:,:,2] /= 255.0

        value = hsv[:,:,2]
        hue = hsv[:,:,0]

        # Retinex滤波
        v_retinex = self.retinex_filter(value, p['sigma_s'], p['sigma_r'], p['gamma'])

        # 自适应直方图均衡
        v_uint8 = (v_retinex * 255).astype(np.uint8)
        v_eq = cv2.createCLAHE(clipLimit=2.0).apply(v_uint8)

        # Sauvola二值化
        v_float = v_eq.astype(np.float64) / 255.0
        binary = self.sauvola_binarization(v_float, None, p['k'])

        # 连通组件分析
        num_labels, labels = cv2.connectedComponents(binary)

        blobs = []
        for label in range(1, num_labels):
            region = np.argwhere(labels == label)
            region = region[:, [1, 0]]  # 转换为(x,y)格式

            blob_stats = self._compute_blob_stats(region, img.shape[:2], hue)
            blobs.append({
                'PixelList': region,
                'stats': blob_stats
            })

        return blobs

    def _compute_blob_stats(self, region, img_shape, hue):
        """计算blob统计信息"""
        h, w = img_shape

        # 基本统计
        y_coords = region[:, 1]
        x_coords = region[:, 0]

        area = len(region)
        centroid = (np.mean(x_coords), np.mean(y_coords))

        # 边界框
        min_x, max_x = np.min(x_coords), np.max(x_coords)
        min_y, max_y = np.min(y_coords), np.max(y_coords)
        width = max_x - min_x + 1
        height = max_y - min_y + 1
        bbox = (min_x, min_y, width, height)

        # 创建blob图像
        blob_img = np.zeros((height + 2, width + 2), dtype=np.uint8)
        for x, y in region:
            blob_img[y - min_y + 1, x - min_x + 1] = 255

        # 计算形状属性
        moments = cv2.moments(blob_img)
        if moments['m00'] > 0:
            cx = moments['m10'] / moments['m00']
            cy = moments['m01'] / moments['m00']

            # 主轴/副轴长度和方向
            mu20 = moments['mu20'] / moments['m00']
            mu02 = moments['mu02'] / moments['m00']
            mu11 = moments['mu11'] / moments['m00']

            # 计算椭圆参数
            a = mu20 + mu02
            b = mu20 - mu02
            c = 4 * mu11

            major_axis = np.sqrt(2 * (a + np.sqrt(b*b + c*c)))
            minor_axis = np.sqrt(2 * (a - np.sqrt(b*b + c*c)))

            # 方向角度
            if b != 0:
                angle = 0.5 * np.arctan2(c, b) * 180 / np.pi
            else:
                angle = 0
        else:
            major_axis = max(width, height)
            minor_axis = min(width, height)
            angle = 0

        # Solidity (凸包面积比)
        contours, _ = cv2.findContours(blob_img, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            hull = cv2.convexHull(contours[0])
            hull_area = cv2.contourArea(hull)
            solidity = area / hull_area if hull_area > 0 else 1
        else:
            solidity = 1

        # Extent (边界框面积比)
        extent = area / (width * height) if width * height > 0 else 1

        # Euler number (孔洞数)
        num_holes = 1 - cv2.connectedComponents(blob_img)[0]
        euler = 1 - num_holes

        # Hue值 - 根据hue数组维度处理
        if hue.ndim == 2:  # hue是完整的图像通道
            pixel_indices = (y_coords.astype(int), x_coords.astype(int))
            hue_values = hue[pixel_indices]
        else:  # hue是预先收集的一维数组（组合blob情况）
            # 组合blob时hue已经包含所有像素的值
            hue_values = hue if len(hue) == area else np.zeros(area)

        stats = {
            'Area': area,
            'Centroid': centroid,
            'BoundingBox': bbox,
            'Width': width,
            'Height': height,
            'aspectRatio': height / width if width > 0 else 1,
            'MajorAxisLength': major_axis,
            'MinorAxisLength': minor_axis,
            'Orientation': angle,
            'Solidity': solidity,
            'Extent': extent,
            'EulerNumber': euler,
            'Hue': hue_values,
            'Image': blob_img,
            'PixelIdxList': region,
        }

        return stats

    def _remove_overlapping_regions(self, blobs, overlap_threshold=0.8):
        """去除重叠区域，保留面积最大的"""
        if len(blobs) == 0:
            return blobs

        keep = []
        n = len(blobs)

        for i in range(n):
            bbox_i = blobs[i]['stats']['BoundingBox']
            area_i = blobs[i]['stats']['Area']

            # 检查与其他区域的重叠
            max_overlap_area = area_i
            best_idx = i

            for j in range(n):
                if i == j:
                    continue

                bbox_j = blobs[j]['stats']['BoundingBox']

                # 计算重叠比例
                overlap_ratio = self._bbox_overlap_ratio(bbox_i, bbox_j)

                if overlap_ratio > overlap_threshold:
                    # 选择面积最大的
                    area_j = blobs[j]['stats']['Area']
                    if area_j > max_overlap_area:
                        max_overlap_area = area_j
                        best_idx = j

            if best_idx == i:
                keep.append(i)

        # 去重
        keep = list(set(keep))
        return [blobs[i] for i in keep]

    def _bbox_overlap_ratio(self, bbox1, bbox2):
        """计算两个边界框的重叠比例"""
        x1, y1, w1, h1 = bbox1
        x2, y2, w2, h2 = bbox2

        # 计算交集
        xi1 = max(x1, x2)
        yi1 = max(y1, y2)
        xi2 = min(x1 + w1, x2 + w2)
        yi2 = min(y1 + h1, y2 + h2)

        if xi2 <= xi1 or yi2 <= yi1:
            return 0

        inter_area = (xi2 - xi1) * (yi2 - yi1)
        area1 = w1 * h1

        return inter_area / area1 if area1 > 0 else 0

    def stroke_width_transform(self, blob_img):
        """
        笔画宽度变换 (SWT)

        Args:
            blob_img: blob的二值图像

        Returns:
            SWT映射
        """
        # 边缘检测
        edges = cv2.Canny(blob_img, 50, 150)

        # 计算梯度方向
        sobelx = cv2.Sobel(blob_img, cv2.CV_64F, 1, 0, ksize=3)
        sobely = cv2.Sobel(blob_img, cv2.CV_64F, 0, 1, ksize=3)

        angles = np.arctan2(sobely, sobelx)

        # SWT计算
        swt = np.zeros_like(blob_img, dtype=np.float64)
        swt.fill(np.inf)

        # 找边缘点
        edge_points = np.argwhere(edges > 0)

        for point in edge_points:
            y, x = point

            # 沿梯度反方向搜索
            angle = angles[y, x]
            dx = -np.cos(angle)
            dy = -np.sin(angle)

            step = 0
            max_steps = 50

            while step < max_steps:
                new_x = int(x + step * dx)
                new_y = int(y + step * dy)

                if new_x < 0 or new_x >= blob_img.shape[1] or \
                   new_y < 0 or new_y >= blob_img.shape[0]:
                    break

                if blob_img[new_y, new_x] == 0:
                    break

                if edges[new_y, new_x] > 0:
                    # 找到对边边缘点
                    stroke_width = step
                    swt[y, x] = stroke_width
                    swt[new_y, new_x] = stroke_width
                    break

                step += 1

        # 用中值填充无限值
        valid_swt = swt[swt < np.inf]
        if len(valid_swt) > 0:
            median_swt = np.median(valid_swt)
            swt[swt == np.inf] = median_swt

        return swt

    def filter_blobs_rule_based(self, blobs, round_num=1):
        """
        基于规则的blob过滤

        Args:
            blobs: blob列表
            round_num: 过滤轮次 (1或2)

        Returns:
            过滤后的blob列表
        """
        if len(blobs) == 0:
            return blobs

        h = self.params['height']
        w = self.params['width']
        total_area = h * w

        # 获取过滤参数
        if round_num == 1:
            f = self.params['filtering_round1']
        else:
            f = self.params['filtering_round2']

        # 计算绝对阈值
        min_area = int(total_area * f['MinArea'])
        max_area = int(total_area * f['MaxArea'])
        min_height = int(h * f['MinHeight'])
        max_height = int(h * f['MaxHeight'])
        min_width = int(w * f['MinWidth'])
        max_width = int(w * f['MaxWidth'])

        result_blobs = []

        for i, blob in enumerate(blobs):
            stats = blob['stats']

            # 面积过滤
            if stats['Area'] < min_area or stats['Area'] > max_area:
                continue

            # 高度过滤
            if stats['Height'] < min_height or stats['Height'] > max_height:
                continue

            # 宽度过滤
            if stats['Width'] < min_width or stats['Width'] > max_width:
                continue

            # 纵横比过滤
            ratio = stats['aspectRatio']
            if ratio < f['RatioMin'] or ratio > f['RatioMax']:
                continue

            result_blobs.append(blob)

        # Round 2: 去除重叠blob
        if round_num == 2 and len(result_blobs) > 0:
            result_blobs = self._remove_overlapping_blobs(result_blobs)

        # 提取HOG特征
        for blob in result_blobs:
            self.extract_hog_features(blob)

        return result_blobs

    def _remove_overlapping_blobs(self, blobs):
        """去除重叠blob"""
        if len(blobs) == 0:
            return blobs

        keep = []
        n = len(blobs)

        for i in range(n):
            pixels_i = set(map(tuple, blobs[i]['PixelList']))
            area_i = len(pixels_i)

            should_keep = True
            for j in range(i):
                pixels_j = set(map(tuple, blobs[j]['PixelList']))

                overlap = pixels_i & pixels_j
                if len(overlap) > 0:
                    # 选择面积较大的保留
                    area_j = len(pixels_j)
                    if area_j >= area_i:
                        should_keep = False
                        break

            if should_keep:
                keep.append(i)

        return [blobs[i] for i in keep]

    def combine_blobs_ellipse(self, blobs):
        """
        椭圆拟合组合 - 将邻近的blob组合成数字

        Args:
            blobs: blob列表

        Returns:
            组合后的blob列表
        """
        if len(blobs) == 0:
            return blobs

        p = self.params['blob_clustering']
        f_ma = p['major_axis']
        f_mi = p['minor_axis']
        T_H = p['thresholds']['Hue']
        T_SW = p['thresholds']['SW']
        T_D = p['thresholds']['D']

        h = self.params['height']
        w = self.params['width']
        D = np.sqrt(h**2 + w**2)

        # 计算每个blob的椭圆并检查与其他blob的距离
        n = len(blobs)
        min_dist_matrix = np.zeros((n, n))

        for i in range(n):
            stats_i = blobs[i]['stats']

            # 椭圆参数
            cx, cy = stats_i['Centroid']
            major = stats_i['MajorAxisLength'] / 2 * f_ma
            minor = stats_i['MinorAxisLength'] / 2 * f_mi
            angle = np.pi * stats_i['Orientation'] / 180

            # 椭圆方程: ((cos(a)*(x-cx)+sin(a)*(y-cy))/major)^2 +
            #           ((sin(a)*(x-cx)-cos(a)*(y-cy))/minor)^2 < 1

            for j in range(n):
                if i == j:
                    continue

                # 检查blob j是否在blob i的椭圆内
                pixels_j = blobs[j]['PixelList']

                inside = False
                min_dist = np.inf

                # 检查是否有像素在椭圆内
                for x, y in pixels_j:
                    # 椭圆距离
                    val = ((np.cos(angle)*(x-cx) + np.sin(angle)*(y-cy))/major)**2 + \
                          ((np.sin(angle)*(x-cx) - np.cos(angle)*(y-cy))/minor)**2

                    if val < 1:
                        inside = True

                        # 计算边界距离
                        boundary_i = self._get_boundary_pixels(blobs[i]['stats']['Image'])
                        for bx, by in boundary_i:
                            d = np.sqrt((x-bx)**2 + (y-by)**2)
                            min_dist = min(min_dist, d)

                if inside:
                    min_dist_matrix[i, j] = min_dist / D

        # 对称化距离矩阵
        min_dist_matrix = np.minimum(min_dist_matrix, min_dist_matrix.T)

        # 应用条件过滤
        # 条件1: 距离阈值
        dist_cond = min_dist_matrix < T_D

        # 条件2: Hue阈值
        ave_hue = [np.mean(blob['stats']['Hue']) for blob in blobs]
        hue_cond = np.abs(np.array(ave_hue) - np.array(ave_hue)[:, None]) < T_H

        # 条件3: SWT阈值
        ave_swt = []
        for blob in blobs:
            swt = blob['stats'].get('swtMap', None)
            if swt is not None:
                valid = swt[swt < np.inf]
                ave_swt.append(np.mean(valid) if len(valid) > 0 else 0)
            else:
                ave_swt.append(0)

        global_swt_mean = np.mean(ave_swt) if len(ave_swt) > 0 else 1
        swt_cond = np.abs(np.array(ave_swt) - np.array(ave_swt)[:, None]) / global_swt_mean < T_SW

        # 综合条件
        link_matrix = min_dist_matrix * dist_cond * hue_cond * swt_cond

        # 构建图并找连通分量
        from collections import defaultdict

        # 简化的连通分量算法
        visited = [False] * n
        components = []

        def dfs(node, comp):
            visited[node] = True
            comp.append(node)
            for neighbor in range(n):
                if not visited[neighbor] and link_matrix[node, neighbor] > 0:
                    dfs(neighbor, comp)

        for i in range(n):
            if not visited[i]:
                comp = []
                dfs(i, comp)
                components.append(comp)

        # 组合每个连通分量中的blob
        combined_blobs = []
        for comp in components:
            combined_pixels = []
            combined_hues = []
            combined_stats = {}

            for idx in comp:
                combined_pixels.extend(blobs[idx]['PixelList'].tolist())
                combined_hues.extend(blobs[idx]['stats']['Hue'].tolist())

            combined_pixels = np.array(combined_pixels)

            # 重新计算组合blob的统计信息
            if len(combined_pixels) > 0:
                stats = self._compute_blob_stats(combined_pixels, (h, w), np.array(combined_hues))
                combined_blobs.append({
                    'PixelList': combined_pixels,
                    'stats': stats,
                    'component_indices': comp,
                })

        return combined_blobs

    def _get_boundary_pixels(self, blob_img):
        """获取blob边界像素"""
        contours, _ = cv2.findContours(blob_img, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        if contours:
            boundary = []
            for point in contours[0]:
                boundary.append(tuple(point[0]))
            return boundary
        return []

    def extract_hog_features(self, blob):
        """
        提取HOG特征用于数字分类

        Args:
            blob: blob字典

        Returns:
            HOG特征向量
        """
        stats = blob['stats']
        blob_img = stats['Image']

        # 创建56x56场景
        scene = np.ones((56, 56), dtype=np.uint8)

        ClassificationHeight = 52
        aspect_ratio = stats['aspectRatio']

        if aspect_ratio > 1:
            # 纵向blob
            factor = ClassificationHeight / stats['Height']
            new_width = int(factor * stats['Width'])

            segment = cv2.resize(255 - blob_img, (new_width, ClassificationHeight))

            xstart = (56 - new_width) // 2
            ystart = (56 - ClassificationHeight) // 2

            scene[ystart:ystart+ClassificationHeight, xstart:xstart+new_width] = segment
        else:
            # 横向blob
            factor = ClassificationHeight / stats['Width']
            new_height = int(factor * stats['Height'])

            segment = cv2.resize(255 - blob_img, (ClassificationHeight, new_height))

            xstart = (56 - ClassificationHeight) // 2
            ystart = (56 - new_height) // 2

            scene[ystart:ystart+new_height, xstart:xstart+ClassificationHeight] = segment

        # HOG特征提取
        hog_features = hog(scene, pixels_per_cell=(8, 8), cells_per_block=(1, 1), feature_vector=True)

        blob['stats']['HOG'] = hog_features
        blob['stats']['Scene'] = scene

        return hog_features

    def classify_digit_template(self, blob):
        """
        使用七段显示模板分类数字

        Args:
            blob: blob字典

        Returns:
            数字值和概率
        """
        stats = blob['stats']
        scene = stats.get('Scene')

        if scene is None:
            self.extract_hog_features(blob)
            scene = blob['stats']['Scene']

        # 七段显示模板
        # 段位置: a(上), b(右上), c(右下), d(下), e(左下), f(左上), g(中)
        templates = self._get_seven_segment_templates()

        best_match = -1
        best_score = 0

        for digit, template in templates.items():
            score = self._template_match_score(scene, template)
            if score > best_score:
                best_score = score
                best_match = digit

        # 特殊处理: 1可能是7
        if best_match == 1:
            # 尝试拉伸和旋转检测是否为7
            stretched = cv2.resize(scene, (56 + 20, 56))
            stretched = stretched[:, 10:-10]

            rotated = ndimage.rotate(stretched, 35, reshape=False)

            score_7 = self._template_match_score(rotated, templates[7])
            if score_7 > best_score:
                best_match = 7
                best_score = score_7

        probability = best_score

        return best_match, probability

    def _get_seven_segment_templates(self):
        """获取七段显示数字模板"""
        templates = {}

        # 创建56x56模板
        for digit in range(10):
            template = np.zeros((56, 56), dtype=np.uint8)

            # 段位置定义
            segments_on = self._digit_segments(digit)

            # 绘制段
            # a: 上横线
            if 'a' in segments_on:
                template[5:10, 10:46] = 255
            # b: 右上竖线
            if 'b' in segments_on:
                template[10:28, 41:46] = 255
            # c: 右下竖线
            if 'c' in segments_on:
                template[28:46, 41:46] = 255
            # d: 下横线
            if 'd' in segments_on:
                template[46:51, 10:46] = 255
            # e: 左下竖线
            if 'e' in segments_on:
                template[28:46, 10:15] = 255
            # f: 左上竖线
            if 'f' in segments_on:
                template[10:28, 10:15] = 255
            # g: 中横线
            if 'g' in segments_on:
                template[26:31, 10:46] = 255

            templates[digit] = template

        return templates

    def _digit_segments(self, digit):
        """返回每个数字激活的段"""
        segments_map = {
            0: ['a', 'b', 'c', 'd', 'e', 'f'],
            1: ['b', 'c'],
            2: ['a', 'b', 'g', 'e', 'd'],
            3: ['a', 'b', 'g', 'c', 'd'],
            4: ['f', 'g', 'b', 'c'],
            5: ['a', 'f', 'g', 'c', 'd'],
            6: ['a', 'f', 'g', 'c', 'd', 'e'],
            7: ['a', 'b', 'c'],
            8: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
            9: ['a', 'b', 'c', 'd', 'f', 'g'],
        }
        return segments_map.get(digit, [])

    def _template_match_score(self, scene, template):
        """计算模板匹配分数"""
        # 归一化
        scene_norm = scene.astype(np.float64) / 255.0
        template_norm = template.astype(np.float64) / 255.0

        # 相关性计算
        correlation = np.sum(scene_norm * template_norm) / (np.sqrt(np.sum(scene_norm**2)) * np.sqrt(np.sum(template_norm**2)) + 1e-6)

        return correlation

    def combine_digits_to_reading(self, blobs):
        """
        将数字组合为血压读数

        Args:
            blobs: 分类后的blob列表

        Returns:
            血压读数 (收缩压, 舒张压, 心率)
        """
        if len(blobs) < 3:
            return None

        # 获取数字值和位置
        digits_info = []
        for blob in blobs:
            value = blob['stats'].get('Value', -1)
            prob = blob['stats'].get('Prob', 0)
            cx, cy = blob['stats']['Centroid']

            if value >= 0 and prob > 0.3:
                digits_info.append({
                    'value': value,
                    'x': cx,
                    'y': cy,
                    'prob': prob,
                })

        if len(digits_info) < 6:
            return None

        # 按x坐标排序
        digits_info.sort(key=lambda d: d['x'])

        # 尝试组合数字为读数
        # 假设血压计有3行数字: 收缩压、舒张压、心率

        # 按y坐标分组
        y_groups = self._group_by_y_position(digits_info)

        readings = []
        for group in y_groups:
            if len(group) >= 2 and len(group) <= 3:
                # 组合数字
                value = int(''.join(str(d['value']) for d in group))
                y_avg = np.mean([d['y'] for d in group])
                readings.append({
                    'value': value,
                    'y_avg': y_avg,
                })

        if len(readings) < 3:
            return None

        # 按y坐标排序 (从上到下)
        readings.sort(key=lambda r: r['y_avg'])

        # 验证范围
        ranges = self.params['bp_ranges']

        final_readings = []
        for i, (name, (min_v, max_v)) in enumerate(zip(['Sys', 'Dia', 'HR'], [ranges['Sys'], ranges['Dia'], ranges['HR']])):
            if i < len(readings):
                value = readings[i]['value']
                if min_v <= value <= max_v:
                    final_readings.append(value)
                else:
                    # 范围外的值，可能分组错误
                    # 尝试重新分配
                    pass

        if len(final_readings) >= 3:
            return final_readings[:3]

        # 如果简单分组失败，尝试智能分组
        return self._smart_group_digits(digits_info)

    def _group_by_y_position(self, digits_info, threshold=30):
        """按y坐标位置分组"""
        if len(digits_info) == 0:
            return []

        groups = []
        current_group = [digits_info[0]]

        for d in digits_info[1:]:
            if abs(d['y'] - current_group[0]['y']) < threshold:
                current_group.append(d)
            else:
                groups.append(current_group)
                current_group = [d]

        groups.append(current_group)
        return groups

    def _smart_group_digits(self, digits_info):
        """智能分组数字"""
        ranges = self.params['bp_ranges']

        # 尝试所有可能的组合
        best_combo = None
        best_score = 0

        n = len(digits_info)
        if n < 6:
            return None

        # 假设每行有2-3个数字
        for i in range(n):
            for j in range(i+1, min(i+4, n)):
                for k in range(j+1, min(j+4, n)):
                    for l in range(k+1, min(k+4, n)):
                        for m in range(l+1, min(l+4, n)):
                            if m + 2 <= n:
                                # 6个数字分成3组
                                group1 = digits_info[i:j]
                                group2 = digits_info[k:l]
                                group3 = digits_info[m:m+2]

                                val1 = int(''.join(str(d['value']) for d in group1))
                                val2 = int(''.join(str(d['value']) for d in group2))
                                val3 = int(''.join(str(d['value']) for d in group3))

                                # 检查范围
                                if ranges['Sys'][0] <= val1 <= ranges['Sys'][1] and \
                                   ranges['Dia'][0] <= val2 <= ranges['Dia'][1] and \
                                   ranges['HR'][0] <= val3 <= ranges['HR'][1]:
                                    score = sum(d['prob'] for d in group1 + group2 + group3)
                                    if score > best_score:
                                        best_score = score
                                        best_combo = [val1, val2, val3]

        return best_combo

    def process_image(self, img_path, verbose=True, return_intermediate=False):
        """
        处理单张图像的完整流程

        Args:
            img_path: 图像路径
            verbose: 是否打印详细信息
            return_intermediate: 是否返回中间结果

        Returns:
            血压读数或None
        """
        # 读取图像
        img = cv2.imread(img_path)
        if img is None:
            if verbose:
                print(f"无法读取图像: {img_path}")
            return None

        # 计算缩放尺寸
        h_orig, w_orig = img.shape[:2]
        target_h = self.params['height']
        f = target_h / h_orig
        target_w = int(f * w_orig)

        self.params['width'] = target_w

        # 缩放图像
        img = cv2.resize(img, (target_w, target_h))

        if verbose:
            print(f"图像尺寸: {target_w}x{target_h}")

        # ===== Step 1: Blob提取 =====
        if verbose:
            print("=== Step 1: Blob提取 ===")

        # MSER路径
        blobs_mser = self.extract_blobs_mser(img)
        if verbose:
            print(f"MSER提取: {len(blobs_mser)} blobs")

        # Sauvola路径
        blobs_sauvola = self.extract_blobs_sauvola(img)
        if verbose:
            print(f"Sauvola提取: {len(blobs_sauvola)} blobs")

        # 合并两条路径的结果
        blobs = blobs_mser + blobs_sauvola
        if verbose:
            print(f"合并后: {len(blobs)} blobs")

        # ===== Step 2: Round 1过滤 =====
        if verbose:
            print("=== Step 2: Round 1过滤 ===")

        blobs = self.filter_blobs_rule_based(blobs, round_num=1)
        if verbose:
            print(f"Round 1过滤后: {len(blobs)} blobs")

        if len(blobs) == 0:
            return None

        # 提取HOG特征
        for blob in blobs:
            self.extract_hog_features(blob)

        # ===== Step 3: Blob组合 =====
        if verbose:
            print("=== Step 3: Blob组合 ===")

        blobs = self.combine_blobs_ellipse(blobs)
        if verbose:
            print(f"椭圆组合后: {len(blobs)} blobs")

        if len(blobs) == 0:
            return None

        # ===== Step 4: Round 2过滤 =====
        if verbose:
            print("=== Step 4: Round 2过滤 ===")

        blobs = self.filter_blobs_rule_based(blobs, round_num=2)
        if verbose:
            print(f"Round 2过滤后: {len(blobs)} blobs")

        if len(blobs) == 0:
            return None

        # ===== Step 5: 数字分类 =====
        if verbose:
            print("=== Step 5: 数字分类 ===")

        classified_blobs = []
        for blob in blobs:
            value, prob = self.classify_digit_template(blob)
            blob['stats']['Value'] = value
            blob['stats']['Prob'] = prob

            if verbose:
                print(f"  Blob位置: {blob['stats']['Centroid']}, 分类: {value}, 置信度: {prob:.2f}")

            if prob > 0.3:
                classified_blobs.append(blob)

        if verbose:
            print(f"有效数字: {len(classified_blobs)}")

        # ===== Step 6: 组合读数 =====
        if verbose:
            print("=== Step 6: 组合读数 ===")

        reading = self.combine_digits_to_reading(classified_blobs)

        if reading and verbose:
            print(f"\n最终读数:")
            print(f"  收缩压: {reading[0]} mmHg")
            print(f"  舒张压: {reading[1]} mmHg")
            print(f"  心率: {reading[2]} bpm")

        if return_intermediate:
            return {
                'reading': reading,
                'blobs': classified_blobs,
                'image': img,
            }

        return reading


def test_oxford_algorithm():
    """测试牛津算法"""
    import os

    # 测试图像路径
    test_dir = "digit_display"

    if not os.path.exists(test_dir):
        print(f"测试目录不存在: {test_dir}")
        return

    # 创建算法实例
    algo = OxfordAlgorithm(device_type='BP')

    # 测试几张图像
    test_files = [f for f in os.listdir(test_dir) if f.endswith(('.jpg', '.png'))][:5]

    results = []
    for filename in test_files:
        img_path = os.path.join(test_dir, filename)

        print(f"\n{'='*60}")
        print(f"处理: {filename}")
        print('='*60)

        reading = algo.process_image(img_path, verbose=True)

        results.append({
            'filename': filename,
            'reading': reading,
        })

    print("\n" + "="*60)
    print("测试结果汇总:")
    print("="*60)

    for r in results:
        if r['reading']:
            print(f"{r['filename']}: {r['reading'][0]}/{r['reading'][1]} {r['reading'][2]}")
        else:
            print(f"{r['filename']}: 无法识别")


if __name__ == "__main__":
    test_oxford_algorithm()