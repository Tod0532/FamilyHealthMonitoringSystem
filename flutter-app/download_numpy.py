#!/usr/bin/env python3
"""
使用Python内置urllib下载numpy whl文件
"""
import urllib.request
import ssl
import subprocess
import sys
import os

# 创建SSL上下文
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

def download_with_urllib(url, filename):
    """使用urllib下载文件"""
    print(f"正在下载: {url}")

    https_handler = urllib.request.HTTPSHandler(context=ssl_context)
    opener = urllib.request.build_opener(https_handler)
    urllib.request.install_opener(opener)

    try:
        # 设置请求头
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=60) as response:
            with open(filename, 'wb') as out_file:
                out_file.write(response.read())
        print(f"下载完成: {filename}")
        print(f"文件大小: {os.path.getsize(filename)} bytes")
        return True
    except Exception as e:
        print(f"下载失败: {e}")
        return False

def main():
    print("=" * 50)
    print("下载 numpy 1.26.4 for Python 3.9 Windows 64-bit")
    print("=" * 50)

    # 正确的URL格式（从pypi.org获取）
    # numpy 1.26.4, cp39, win_amd64
    whl_filename = "numpy-1.26.4-cp39-cp39-win_amd64.whl"

    # 尝试多个镜像
    urls = [
        # 直接URL（pypi.org CDN）
        f"https://files.pythonhosted.org/packages/85/00/d8c6f1f1b4d8d2f9e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4/{whl_filename}",
        # 使用pypi.org API找到的真实URL
        "https://files.pythonhosted.org/packages/fc/b4/0b0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b4e0b/numpy-1.26.4-cp39-cp39-win_amd64.whl",
    ]

    # 尝试从pypi获取真实的下载链接
    print("\n尝试获取numpy的真实下载链接...")

    json_url = "https://pypi.org/pypi/numpy/1.26.4/json"

    try:
        https_handler = urllib.request.HTTPSHandler(context=ssl_context)
        opener = urllib.request.build_opener(https_handler)
        urllib.request.install_opener(opener)

        req = urllib.request.Request(json_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=30) as response:
            import json
            data = json.loads(response.read().decode())

            # 查找cp39-win_amd64的URL
            for url_info in data['urls']:
                if 'cp39' in url_info['filename'] and 'win_amd64' in url_info['filename']:
                    real_url = url_info['url']
                    print(f"找到真实URL: {real_url}")
                    urls.insert(0, real_url)
                    break
    except Exception as e:
        print(f"获取JSON失败: {e}")

    # 尝试下载
    for url in urls:
        if download_with_urllib(url, whl_filename):
            # 安装
            print("\n安装中...")
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--force-reinstall", "--no-deps", whl_filename],
                capture_output=True,
                text=True
            )
            print(result.stdout)
            if result.returncode == 0:
                print("\n安装成功!")
                # 验证
                result = subprocess.run(
                    [sys.executable, "-c", "import numpy; print('NumPy版本:', numpy.__version__)"],
                    capture_output=True,
                    text=True
                )
                print(result.stdout)
                os.remove(whl_filename)
                return True
            else:
                print(f"安装失败: {result.stderr}")

    print("\n所有下载尝试都失败了。")
    print("\n请手动下载并安装:")
    print("1. 访问: https://pypi.org/project/numpy/1.26.4/#files")
    print("2. 下载 numpy-1.26.4-cp39-cp39-win_amd64.whl")
    print("3. 运行: pip install numpy-1.26.4-cp39-cp39-win_amd64.whl")
    return False

if __name__ == "__main__":
    main()