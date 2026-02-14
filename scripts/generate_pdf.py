#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将Markdown文件转换为PDF的使用说明书
"""

from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen import canvas
from reportlab.lib.units import cm
import os

def create_manual_pdf():
    """创建产品使用说明书PDF"""

    # 输出路径
    output_path = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                                   'docs', '产品使用说明书.pdf')

    c = canvas.Canvas(output_path, pagesize=A4)
    width, height = A4

    # 字体设置
    try:
        c.setFont("STSong-Light", 24)
    except:
        c.setFont("Helvetica-Bold", 24)

    # 标题
    c.drawCentredString("家庭健康中心 APP", width / 2, height - 3*cm)
    c.setFont("STSong-Light", 16)
    c.drawCentredString("产品使用说明书", width / 2, height - 4*cm)

    y = height - 6*cm

    # 内容
    sections = [
        ("一、产品概述", ""),
        ("1.1 产品简介", "家庭健康中心是一款专为家庭设计的全方位健康管理应用。"),
        ("1.2 核心功能", ""),
        ("", "· 家庭管理 - 支持添加多名家庭成员"),
        ("", "· 数据记录 - 支持8种健康指标记录"),
        ("", "· 统计分析 - 可视化图表展示健康趋势"),
        ("", "· 智能预警 - 异常数据自动提醒"),
        ("", "· 数据导出 - 方便备份和分享"),
        ("", ""),
        ("1.3 支持的数据类型", ""),
        ("", "血压、心率、血糖、体温、体重、身高、步数、睡眠"),
        ("", ""),
        ("二、快速开始", ""),
        ("2.1 注册账号", "1. 打开应用 2. 填写手机号 3. 获取验证码"),
        ("", "4. 设置密码 5. 完成注册"),
        ("", ""),
        ("2.2 登录应用", "输入手机号和密码，点击登录"),
        ("", ""),
        ("三、功能使用指南", ""),
        ("3.1 应用导航", "首页、成员、数据、预警、我的 五个Tab"),
        ("", ""),
        ("3.2 添加成员", "1. 进入成员页面 2. 点击+按钮"),
        ("", "3. 填写信息 4. 保存"),
        ("", ""),
        ("3.3 录入健康数据", "1. 选择数据类型 2. 选择成员"),
        ("", "3. 输入数值 4. 保存"),
        ("", ""),
        ("3.4 健康统计", "1. 进入数据Tab 2. 点击统计图标"),
        ("", "3. 查看图表和趋势分析"),
        ("", ""),
        ("四、常见问题", ""),
        ("Q: 忘记密码？", "A: 使用忘记密码功能找回"),
        ("Q: 删除数据能恢复？", "A: 不能恢复，删除前请确认"),
        ("Q: 如何联系客服？", "A: 应用内帮助与反馈"),
        ("", ""),
        ("五、技术支持", ""),
        ("客服邮箱", "support@example.com"),
        ("服务时间", "周一至周日 9:00-21:00"),
        ("", ""),
        ("", "感谢您使用家庭健康中心！"),
    ]

    try:
        c.setFont("STSong-Light", 12)
    except:
        c.setFont("Helvetica", 12)

    for title, content in sections:
        if y < 5*cm:
            c.showPage()
            y = height - 3*cm

        if title:
            try:
                c.setFont("STSong-Light", 14)
            except:
                c.setFont("Helvetica-Bold", 14)
            c.drawString(2*cm, y, title)
            y -= 0.7*cm

        if content:
            try:
                c.setFont("STSong-Light", 11)
            except:
                c.setFont("Helvetica", 11)
            # 处理中文内容
            lines = content if len(content) < 50 else [content[i:i+45] for i in range(0, len(content), 45)]
            for line in lines:
                c.drawString(2.5*cm, y, line)
                y -= 0.6*cm
        else:
            y -= 0.3*cm

    c.save()
    print(f"PDF已生成: {output_path}")
    return output_path

if __name__ == "__main__":
    create_manual_pdf()
