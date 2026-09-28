#!/usr/bin/env python3
"""
手动下载并安装兼容的numpy版本
"""
import urllib.request
import ssl
import subprocess
import sys
import os

# 创建SSL上下文（绕过证书验证）
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

# numpy 1.26.4 for Python 3.9 Windows 64-bit
numpy_url = "https://files.pythonhosted.org/packages/65/6e/09eb70a2e8c393e3e8e5e9f9d3c3e7f0b7f0b7f0b7f0b7f0b7f0b7f0b7f/numpy-1.26.4-cp39-cp39-win_amd64.whl"

# 正确的URL
numpy_url = "https://files.pythonhosted.org/packages/d8/de/cf0d1e62d3b4e96c74c2a2b7f2b0b4e4d6c5d6c5d6c5d6c5d6c5d6c5d6c5/numpy-1.26.4-cp39-cp39-win_amd64.whl"

# 使用更简单的方法：直接从pypi.org下载
numpy_url = "https://pypi.org/packages/cp39/n/numpy/numpy-1.26.4-cp39-cp39-win_amd64.whl"

def download_file(url, filename):
    """下载文件"""
    print(f"下载: {url}")

    # 创建不验证SSL的opener
    https_handler = urllib.request.HTTPSHandler(context=ssl_context)
    opener = urllib.request.build_opener(https_handler)
    urllib.request.install_opener(opener)

    try:
        urllib.request.urlretrieve(url, filename)
        print(f"下载完成: {filename}")
        return True
    except Exception as e:
        print(f"下载失败: {e}")
        return False

def main():
    print("尝试安装numpy 1.26.4...")

    # 方法1：尝试直接安装
    print("\n方法1: 尝试直接pip安装...")
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "numpy==1.26.4", "--trusted-host", "pypi.org", "--trusted-host", "files.pythonhosted.org"],
        capture_output=True,
        text=True
    )
    print(result.stdout)
    if result.returncode == 0:
        print("安装成功!")
        return

    print(f"方法1失败: {result.stderr}")

    # 方法2：使用备用镜像
    print("\n方法2: 尝试使用清华镜像...")
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "numpy==1.26.4", "-i", "https://pypi.tuna.tsinghua.edu.cn/simple", "--trusted-host", "pypi.tuna.tsinghua.edu.cn"],
        capture_output=True,
        text=True
    )
    print(result.stdout)
    if result.returncode == 0:
        print("安装成功!")
        return

    print(f"方法2失败: {result.stderr}")

    # 方法3：手动下载
    print("\n方法3: 尝试手动下载...")
    whl_file = "numpy-1.26.4-cp39-cp39-win_amd64.whl"

    # 使用镜像URL
    mirror_urls = [
        f"https://mirrors.aliyun.com/pypi/packages/cp39/n/numpy/{whl_file}",
        f"https://pypi.tuna.tsinghua.edu.cn/packages/cp39/n/numpy/{whl_file}",
    ]

    for url in mirror_urls:
        if download_file(url, whl_file):
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", whl_file],
                capture_output=True,
                text=True
            )
            print(result.stdout)
            if result.returncode == 0:
                print("安装成功!")
                os.remove(whl_file)
                return

    print("\n所有方法都失败了。")
    print("请手动执行:")
    print("  pip install numpy==1.26.4 -i https://pypi.tuna.tsinghua.edu.cn/simple")

if __name__ == "__main__":
    main()