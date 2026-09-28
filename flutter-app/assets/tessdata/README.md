# Assets/Tessdata 目录

此目录存放 Tesseract OCR 语言数据和配置。

## 文件说明

| 文件 | 说明 |
|------|------|
| eng.traineddata | 英文语言包（数字识别）|
| tessdata_config.json | Tesseract 配置文件 |
| bp_test_photo.png | 测试照片 |

## 使用方式

Flutter App 使用 Tesseract OCR 进行血压计数字识别。

语言包从 Tesseract 官方下载：https://github.com/tesseract-ocr/tessdata

**注意**：`.traineddata` 文件较大（约 12MB），建议使用精简版语言包。