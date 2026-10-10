import 'dart:typed_data';

/// JPEG 元数据剥离工具
///
/// 背景（真实照片实测发现）：
/// `package:image` 4.3.0 的 EXIF 解析器在部分真实手机照片上会抛
/// `RangeError`（InputBuffer.readUint16 越界），导致 `decodeImage` 直接失败。
/// App 内该异常被 catch 后表现为"无法解码图像 / 识别失败"，
/// 这类照片在真机上永远读不出结果（实测 60 张真实照片中有近 1/3 中招）。
///
/// 解决思路：正常解码失败时，把 JPEG 里的元数据段（APPn / COM）剥掉再解一次。
/// 这些段对像素解码没有作用，去掉后 `image` 包就不会走 EXIF 分支。
///
/// 注意：绝不改动 SOS 之后的压缩数据，保证像素完全一致。
class JpegSanitizer {
  JpegSanitizer._();

  /// 判断是否为 JPEG（SOI 标记 0xFFD8）
  static bool isJpeg(Uint8List bytes) =>
      bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  /// 剥离 APPn / COM 段；遇到 SOS（0xFFDA）后原样保留剩余全部数据。
  ///
  /// 返回 null 表示不是可识别的 JPEG 结构（调用方应回退到原数据）。
  static Uint8List? stripMetadata(Uint8List bytes) {
    if (!isJpeg(bytes)) return null;
    final out = BytesBuilder(copy: false);
    // SOI
    out.add(bytes.sublist(0, 2));

    var i = 2;
    while (i + 3 < bytes.length) {
      // 标记必须以 0xFF 开头；填充字节 0xFF 可重复出现
      if (bytes[i] != 0xFF) return null;
      var marker = bytes[i + 1];
      while (marker == 0xFF && i + 2 < bytes.length) {
        i++;
        marker = bytes[i + 1];
      }
      // 无长度字段的标记
      if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD9)) {
        out.addByte(0xFF);
        out.addByte(marker);
        i += 2;
        continue;
      }
      // SOS：后面是压缩数据，原样拷贝到结尾
      if (marker == 0xDA) {
        out.add(bytes.sublist(i));
        return out.toBytes();
      }
      if (i + 3 >= bytes.length) return null;
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      if (len < 2 || i + 2 + len > bytes.length) return null;
      final isAppOrComment = (marker >= 0xE0 && marker <= 0xEF) || marker == 0xFE;
      if (!isAppOrComment) {
        // 保留 DQT / DHT / SOFn 等解码必需段
        out.add(bytes.sublist(i, i + 2 + len));
      }
      i += 2 + len;
    }
    // 没有遇到 SOS，结构不完整
    return null;
  }
}
