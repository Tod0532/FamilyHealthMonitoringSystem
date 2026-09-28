"""
牛津算法调试脚本 - 分析blob提取和过滤情况
"""

import cv2
import numpy as np
from skimage import measure
import matplotlib.pyplot as plt
import os

def analyze_blobs(img_path, verbose=True):
    """分析单张图像的blob提取情况"""
    img = cv2.imread(img_path)
    if img is None:
        print(f"无法读取: {img_path}")
        return

    # 缩放
    target_h = 500
    f = target_h / img.shape[0]
    target_w = int(f * img.shape[1])
    img = cv2.resize(img, (target_w, target_h))

    print(f"图像尺寸: {target_w}x{target_h}")
    total_area = target_h * target_w

    # HSV提取
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    v = hsv[:,:,2].astype(np.float64) / 255.0

    # Retinex滤波
    v_uint8 = (v * 255).astype(np.uint8)
    filtered = cv2.bilateralFilter(v_uint8, d=-1, sigmaColor=25, sigmaSpace=30)
    v_float = v + 1e-6
    filtered_float = filtered.astype(np.float64) / 255.0 + 1e-6
    retinex = np.log(v_float) - np.log(filtered_float)
    retinex = (retinex - retinex.min()) / (retinex.max() - retinex.min())

    # Gamma校正 (MSER和Sauvola不同gamma)
    retinex_mser = np.power(retinex, 0.7)
    retinex_sauv = np.power(retinex, 1.5)

    # ===== MSER提取 =====
    v_mser = (retinex_mser * 255).astype(np.uint8)

    # 牛津参数: Delta=0.02 * 100 = 2, T=0.3, min/max area
    mser = cv2.MSER_create(
        delta=2,  # 牛津Delta=0.02*100
        min_area=int(total_area * 0.0001),
        max_area=int(total_area * 0.4),
        max_variation=0.3  # 牛津T=0.3
    )

    regions_mser, _ = mser.detectRegions(v_mser)

    print(f"\n=== MSER检测 ({len(regions_mser)} regions) ===")

    # 分析每个region
    mser_stats = []
    for i, region in enumerate(regions_mser[:20]):  # 只分析前20个
        y_coords = region[:, 1]
        x_coords = region[:, 0]

        area = len(region)
        min_x, max_x = np.min(x_coords), np.max(x_coords)
        min_y, max_y = np.min(y_coords), np.max(y_coords)
        width = max_x - min_x + 1
        height = max_y - min_y + 1
        aspect_ratio = height / width if width > 0 else 1

        rel_area = area / total_area
        rel_height = height / target_h
        rel_width = width / target_w

        mser_stats.append({
            'area': area,
            'rel_area': rel_area,
            'height': height,
            'rel_height': rel_height,
            'width': width,
            'rel_width': rel_width,
            'aspect_ratio': aspect_ratio,
        })

        if verbose and i < 10:
            print(f"  Region {i}: area={area}({rel_area:.4f}), "
                  f"h={height}({rel_height:.3f}), w={width}({rel_width:.3f}), "
                  f"ratio={aspect_ratio:.2f}")

    # 牛津Round 1过滤条件 (BP设备)
    print(f"\n=== 牛津过滤条件 (BP Round 1) ===")
    min_area_thresh = total_area * 0.0001
    max_area_thresh = total_area * 0.4
    min_height_thresh = target_h * 0.01
    max_height_thresh = target_h * 0.7
    min_width_thresh = target_w * 0.001
    max_width_thresh = target_w * 0.5
    ratio_min = 0.1
    ratio_max = 8

    print(f"  面积: {min_area_thresh} - {max_area_thresh}")
    print(f"  高度: {min_height_thresh} - {max_height_thresh}")
    print(f"  宽度: {min_width_thresh} - {max_width_thresh}")
    print(f"  纵横比: {ratio_min} - {ratio_max}")

    # 分析有多少region会通过过滤
    passed_mser = []
    for s in mser_stats:
        reasons = []

        if s['area'] < min_area_thresh or s['area'] > max_area_thresh:
            reasons.append(f"面积{ s['area']}超出范围")
        if s['height'] < min_height_thresh or s['height'] > max_height_thresh:
            reasons.append(f"高度{ s['height']}超出范围")
        if s['width'] < min_width_thresh or s['width'] > max_width_thresh:
            reasons.append(f"宽度{ s['width']}超出范围")
        if s['aspect_ratio'] < ratio_min or s['aspect_ratio'] > ratio_max:
            reasons.append(f"纵横比{ s['aspect_ratio']}超出范围")

        if len(reasons) == 0:
            passed_mser.append(s)
        else:
            if len(passed_mser) < 5 and verbose:
                print(f"  过滤掉: {reasons}")

    print(f"\n通过过滤的MSER regions: {len(passed_mser)}")

    # ===== Sauvola二值化 =====
    v_sauv = (retinex_sauv * 255).astype(np.uint8)

    # CLAHE
    clahe = cv2.createCLAHE(clipLimit=2.0)
    v_eq = clahe.apply(v_sauv)

    # Sauvola窗口大小: alpha=0.059 * height = 0.059 * 500 = 29.5
    window_size = int(target_h * 0.059)
    print(f"\n=== Sauvola二值化 (窗口={window_size}, k=0.34) ===")

    # 简化的Sauvola (使用OpenCV adaptiveThreshold近似)
    # 注意: OpenCV的ADAPTIVE_THRESH_MEAN_C不是真正的Sauvola，但可以近似
    binary = cv2.adaptiveThreshold(
        v_eq, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
        cv2.THRESH_BINARY_INV, window_size, 0
    )

    # 连通组件
    num_labels, labels = cv2.connectedComponents(binary)

    print(f"连通组件数: {num_labels - 1}")

    sauv_stats = []
    for label in range(1, min(num_labels, 21)):
        region = np.argwhere(labels == label)
        region = region[:, [1, 0]]  # (x,y)

        y_coords = region[:, 1]
        x_coords = region[:, 0]

        area = len(region)
        min_x, max_x = np.min(x_coords), np.max(x_coords)
        min_y, max_y = np.min(y_coords), np.max(y_coords)
        width = max_x - min_x + 1
        height = max_y - min_y + 1
        aspect_ratio = height / width if width > 0 else 1

        rel_area = area / total_area
        rel_height = height / target_h
        rel_width = width / target_w

        sauv_stats.append({
            'area': area,
            'rel_area': rel_area,
            'height': height,
            'rel_height': rel_height,
            'width': width,
            'rel_width': rel_width,
            'aspect_ratio': aspect_ratio,
        })

        if verbose and label <= 10:
            print(f"  CC {label}: area={area}({rel_area:.4f}), "
                  f"h={height}({rel_height:.3f}), w={width}({rel_width:.3f}), "
                  f"ratio={aspect_ratio:.2f}")

    # 分析Sauvola通过过滤的情况
    passed_sauv = []
    for s in sauv_stats:
        passed = True
        if s['area'] < min_area_thresh or s['area'] > max_area_thresh:
            passed = False
        if s['height'] < min_height_thresh or s['height'] > max_height_thresh:
            passed = False
        if s['width'] < min_width_thresh or s['width'] > max_width_thresh:
            passed = False
        if s['aspect_ratio'] < ratio_min or s['aspect_ratio'] > ratio_max:
            passed = False

        if passed:
            passed_sauv.append(s)

    print(f"\n通过过滤的Sauvola CCs: {len(passed_sauv)}")

    # 可视化
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))

    axes[0,0].imshow(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    axes[0,0].set_title('原图')
    axes[0,0].axis('off')

    axes[0,1].imshow(v_mser, cmap='gray')
    axes[0,1].set_title('MSER Retinex (gamma=0.7)')
    axes[0,1].axis('off')

    axes[0,2].imshow(v_sauv, cmap='gray')
    axes[0,2].set_title('Sauvola Retinex (gamma=1.5)')
    axes[0,2].axis('off')

    # MSER regions可视化
    mser_vis = np.zeros_like(img)
    for i, region in enumerate(regions_mser[:30]):
        color = plt.cm.hsv(i / 30)[:3]
        color = [int(c*255) for c in color]
        for x, y in region:
            if 0 <= y < target_h and 0 <= x < target_w:
                mser_vis[y, x] = color

    axes[1,0].imshow(cv2.cvtColor(mser_vis, cv2.COLOR_BGR2RGB))
    axes[1,0].set_title(f'MSER Regions ({len(regions_mser)})')
    axes[1,0].axis('off')

    axes[1,1].imshow(v_eq, cmap='gray')
    axes[1,1].set_title('CLAHE')
    axes[1,1].axis('off')

    axes[1,2].imshow(binary, cmap='gray')
    axes[1,2].set_title(f'Sauvola Binary ({num_labels-1} CCs)')
    axes[1,2].axis('off')

    plt.tight_layout()

    # 保存调试图像
    basename = os.path.basename(img_path).split('.')[0]
    debug_path = f"debug_oxford_{basename}.png"
    plt.savefig(debug_path, dpi=150)
    plt.close()

    print(f"\n调试图保存至: {debug_path}")

    return {
        'mser_regions': len(regions_mser),
        'sauvola_ccs': num_labels - 1,
        'passed_mser': len(passed_mser),
        'passed_sauv': len(passed_sauv),
    }


def batch_analyze():
    """批量分析"""
    test_dir = "digit_display"
    if not os.path.exists(test_dir):
        print(f"目录不存在: {test_dir}")
        return

    files = [f for f in os.listdir(test_dir) if f.endswith('.jpg')][:10]

    print("批量分析牛津算法blob提取...\n")

    for f in files:
        img_path = os.path.join(test_dir, f)
        print(f"\n{'='*60}")
        print(f"分析: {f}")
        print('='*60)

        stats = analyze_blobs(img_path, verbose=False)

        print(f"MSER提取: {stats['mser_regions']} regions, 通过过滤: {stats['passed_mser']}")
        print(f"Sauvola提取: {stats['sauvola_ccs']} CCs, 通过过滤: {stats['passed_sauv']}")


if __name__ == "__main__":
    # 分析单张图像
    test_path = "digit_display/100-71-74.jpg"
    if os.path.exists(test_path):
        analyze_blobs(test_path, verbose=True)

    print("\n" + "="*60)
    print("批量分析")
    print("="*60)
    batch_analyze()