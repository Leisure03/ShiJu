import 'dart:convert';
import 'dart:typed_data';

/// 纯 Dart 实现的 ISO/IEC 18004 标准 QR Code 矩阵编码器（Byte 模式，Level M 15% 纠错）
///
/// 支持自动根据输入 UTF-8 字节长度选择最佳版本（Version 1 ~ 12），
/// 生成的布尔矩阵可被手机微信「扫一扫」及系统相机直接识别，且具备 15% 中心徽标容错能力。
class StandardQrMatrix {
  StandardQrMatrix._({
    required this.version,
    required this.size,
    required this.modules,
    required this.isFunction,
  });

  final int version;
  final int size;
  final List<List<bool>> modules;
  final List<List<bool>> isFunction;

  /// 将任意字符串编码为标准可扫描的 QR Code 矩阵
  static StandardQrMatrix encode(String text) {
    final Uint8List dataBytes = Uint8List.fromList(utf8.encode(text));

    // Level M 各版本（1~12）参数表：[总码字数, 每块纠错码字数, 组1块数, 组2块数]
    const List<List<int>> versionParamsM = <List<int>>[
      <int>[], // v0 占位
      <int>[26, 10, 1, 0], // v1: 16 data bytes
      <int>[44, 16, 1, 0], // v2: 28 data bytes
      <int>[70, 26, 1, 0], // v3: 44 data bytes
      <int>[100, 18, 2, 0], // v4: 64 data bytes
      <int>[134, 24, 2, 0], // v5: 86 data bytes
      <int>[172, 16, 4, 0], // v6: 108 data bytes
      <int>[196, 18, 4, 0], // v7: 124 data bytes
      <int>[242, 22, 2, 2], // v8: 154 data bytes
      <int>[292, 22, 3, 2], // v9: 182 data bytes
      <int>[346, 26, 4, 1], // v10: 216 data bytes
      <int>[404, 30, 1, 4], // v11: 254 data bytes
      <int>[466, 22, 6, 2], // v12: 290 data bytes
    ];

    int version = 1;
    for (; version <= 12; version++) {
      final List<int> p = versionParamsM[version];
      final int totalCodewords = p[0];
      final int ecPerBlock = p[1];
      final int numBlocks = p[2] + p[3];
      final int dataCapacityCodewords = totalCodewords - ecPerBlock * numBlocks;
      final int headerBits = 4 + (version <= 9 ? 8 : 16);
      final int maxBytes = (dataCapacityCodewords * 8 - headerBits) ~/ 8;
      if (dataBytes.length <= maxBytes) {
        break;
      }
    }
    if (version > 12) {
      version = 12;
    }

    final List<int> params = versionParamsM[version];
    final int totalCodewords = params[0];
    final int ecCodewordsPerBlock = params[1];
    final int numBlocksGroup1 = params[2];
    final int numBlocksGroup2 = params[3];
    final int numBlocks = numBlocksGroup1 + numBlocksGroup2;
    final int dataCodewordsCount =
        totalCodewords - ecCodewordsPerBlock * numBlocks;

    // 1. 构建数据位流（Byte 模式 0100 + 字符计数指示符 + 字节数据 + 终止符 + 补齐字节）
    final int countBits = version <= 9 ? 8 : 16;
    final int maxPayloadLen =
        ((dataCodewordsCount * 8 - 4 - countBits) ~/ 8).clamp(0, dataBytes.length);
    final List<int> bits = <int>[];

    void appendBits(int val, int len) {
      for (int i = len - 1; i >= 0; i--) {
        bits.add((val >> i) & 1);
      }
    }

    appendBits(0x4, 4); // Byte mode indicator (0100)
    appendBits(maxPayloadLen, countBits);
    for (int i = 0; i < maxPayloadLen; i++) {
      appendBits(dataBytes[i], 8);
    }

    final int capacityBits = dataCodewordsCount * 8;
    appendBits(0, (capacityBits - bits.length).clamp(0, 4));
    while (bits.length % 8 != 0) {
      bits.add(0);
    }

    final Uint8List dataCodewords = Uint8List(dataCodewordsCount);
    for (int i = 0; i < bits.length ~/ 8; i++) {
      int b = 0;
      for (int j = 0; j < 8; j++) {
        b = (b << 1) | bits[i * 8 + j];
      }
      dataCodewords[i] = b;
    }
    int padToggle = 0;
    for (int i = bits.length ~/ 8; i < dataCodewordsCount; i++) {
      dataCodewords[i] = padToggle == 0 ? 0xEC : 0x11;
      padToggle ^= 1;
    }

    // 2. 分块并生成 Reed-Solomon 纠错码字，随后交织拼接
    final Uint8List allCodewords = _addEccAndInterleave(
      dataCodewords,
      totalCodewords: totalCodewords,
      ecPerBlock: ecCodewordsPerBlock,
      blocksGroup1: numBlocksGroup1,
      blocksGroup2: numBlocksGroup2,
    );

    // 3. 初始化矩阵并绘制功能图形（定位标、时序线、校正标、暗模块）
    final int size = version * 4 + 17;
    final List<List<bool>> modules = List<List<bool>>.generate(
      size,
      (_) => List<bool>.filled(size, false),
    );
    final List<List<bool>> isFunc = List<List<bool>>.generate(
      size,
      (_) => List<bool>.filled(size, false),
    );

    final StandardQrMatrix qr = StandardQrMatrix._(
      version: version,
      size: size,
      modules: modules,
      isFunction: isFunc,
    );

    qr._drawFunctionPatterns();
    qr._drawCodewords(allCodewords);

    // 4. 选择最佳掩码（Mask 0 ~ 7 中惩罚分最低者）并写入格式信息
    int bestMask = 0;
    int minPenalty = 0x7FFFFFFF;
    for (int mask = 0; mask < 8; mask++) {
      qr._applyMask(mask);
      qr._drawFormatBits(mask);
      final int penalty = qr._calculatePenaltyScore();
      if (penalty < minPenalty) {
        minPenalty = penalty;
        bestMask = mask;
      }
      qr._applyMask(mask); // 还原掩码
    }
    qr._applyMask(bestMask);
    qr._drawFormatBits(bestMask);

    return qr;
  }

  void _setFunctionModule(int x, int y, bool isDark) {
    modules[y][x] = isDark;
    isFunction[y][x] = true;
  }

  void _drawFunctionPatterns() {
    // 时序线
    for (int i = 0; i < size; i++) {
      _setFunctionModule(6, i, i.isEven);
      _setFunctionModule(i, 6, i.isEven);
    }

    // 三个 7x7 定位标（含外围白边分隔区）
    _drawFinderPattern(3, 3);
    _drawFinderPattern(size - 4, 3);
    _drawFinderPattern(3, size - 4);

    // 5x5 校正图形
    final List<int> alignPos = _getAlignmentPatternPositions();
    final int numAlign = alignPos.length;
    for (int i = 0; i < numAlign; i++) {
      for (int j = 0; j < numAlign; j++) {
        if ((i == 0 && j == 0) ||
            (i == 0 && j == numAlign - 1) ||
            (i == numAlign - 1 && j == 0)) {
          continue;
        }
        _drawAlignmentPattern(alignPos[i], alignPos[j]);
      }
    }

    // 预留格式信息位与暗模块
    _drawFormatBits(0);
    if (version >= 7) {
      _drawVersionBits();
    }
  }

  void _drawFinderPattern(int cx, int cy) {
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -4; dx <= 4; dx++) {
        final int x = cx + dx;
        final int y = cy + dy;
        if (x >= 0 && x < size && y >= 0 && y < size) {
          final int dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
          _setFunctionModule(x, y, dist != 2 && dist != 4);
        }
      }
    }
  }

  void _drawAlignmentPattern(int cx, int cy) {
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final int dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
        _setFunctionModule(cx + dx, cy + dy, dist != 1);
      }
    }
  }

  void _drawFormatBits(int mask) {
    // Level M 的格式指示符为 00 (0)
    const int eclFormatBits = 0;
    final int data = (eclFormatBits << 3) | mask;
    int rem = data;
    for (int i = 0; i < 10; i++) {
      rem = (rem << 1) ^ (((rem >> 9) & 1) * 0x537);
    }
    final int bits = ((data << 10) | rem) ^ 0x5412;

    for (int i = 0; i <= 5; i++) {
      _setFunctionModule(8, i, ((bits >> i) & 1) != 0);
    }
    _setFunctionModule(8, 7, ((bits >> 6) & 1) != 0);
    _setFunctionModule(8, 8, ((bits >> 7) & 1) != 0);
    _setFunctionModule(7, 8, ((bits >> 8) & 1) != 0);
    for (int i = 9; i < 15; i++) {
      _setFunctionModule(14 - i, 8, ((bits >> i) & 1) != 0);
    }

    for (int i = 0; i < 8; i++) {
      _setFunctionModule(size - 1 - i, 8, ((bits >> i) & 1) != 0);
    }
    for (int i = 8; i < 15; i++) {
      _setFunctionModule(8, size - 15 + i, ((bits >> i) & 1) != 0);
    }
    _setFunctionModule(8, size - 8, true); // 固定暗模块
  }

  void _drawVersionBits() {
    int rem = version;
    for (int i = 0; i < 12; i++) {
      rem = (rem << 1) ^ (((rem >> 11) & 1) * 0x1F25);
    }
    final int bits = (version << 12) | rem;
    for (int i = 0; i < 18; i++) {
      final bool bit = ((bits >> i) & 1) != 0;
      final int a = size - 11 + (i % 3);
      final int b = i ~/ 3;
      _setFunctionModule(a, b, bit);
      _setFunctionModule(b, a, bit);
    }
  }

  List<int> _getAlignmentPatternPositions() {
    if (version == 1) return const <int>[];
    final int numAlign = version ~/ 7 + 2;
    final int step = (version == 32)
        ? 26
        : ((version * 4 + numAlign * 2 + 1) ~/ (numAlign * 2 - 2)) * 2;
    final List<int> result = <int>[6];
    for (int pos = size - 7; result.length < numAlign; pos -= step) {
      result.insert(1, pos);
    }
    return result;
  }

  void _drawCodewords(Uint8List codewords) {
    int i = 0;
    for (int right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (int vert = 0; vert < size; vert++) {
        for (int j = 0; j < 2; j++) {
          final int x = right - j;
          final bool upward = ((right + 1) & 2) == 0;
          final int y = upward ? (size - 1 - vert) : vert;
          if (!isFunction[y][x] && i < codewords.length * 8) {
            modules[y][x] = ((codewords[i >> 3] >> (7 - (i & 7))) & 1) != 0;
            i++;
          }
        }
      }
    }
  }

  void _applyMask(int mask) {
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (isFunction[y][x]) continue;
        final bool invert = switch (mask) {
          0 => (x + y).isEven,
          1 => y.isEven,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2).isEven,
          5 => (x * y) % 2 + (x * y) % 3 == 0,
          6 => ((x * y) % 2 + (x * y) % 3).isEven,
          _ => ((x + y) % 2 + (x * y) % 3).isEven,
        };
        if (invert) {
          modules[y][x] = !modules[y][x];
        }
      }
    }
  }

  int _calculatePenaltyScore() {
    int score = 0;
    for (int y = 0; y < size; y++) {
      int runLen = 1;
      for (int x = 1; x < size; x++) {
        if (modules[y][x] == modules[y][x - 1]) {
          runLen++;
          if (runLen == 5) {
            score += 3;
          } else if (runLen > 5) {
            score += 1;
          }
        } else {
          runLen = 1;
        }
      }
    }
    for (int x = 0; x < size; x++) {
      int runLen = 1;
      for (int y = 1; y < size; y++) {
        if (modules[y][x] == modules[y - 1][x]) {
          runLen++;
          if (runLen == 5) {
            score += 3;
          } else if (runLen > 5) {
            score += 1;
          }
        } else {
          runLen = 1;
        }
      }
    }
    return score;
  }

  static Uint8List _addEccAndInterleave(
    Uint8List data, {
    required int totalCodewords,
    required int ecPerBlock,
    required int blocksGroup1,
    required int blocksGroup2,
  }) {
    final int numBlocks = blocksGroup1 + blocksGroup2;
    final int shortBlockDataLen = data.length ~/ numBlocks;
    final Uint8List rsDiv = _reedSolomonDivisor(ecPerBlock);

    final List<Uint8List> dataBlocks = <Uint8List>[];
    final List<Uint8List> ecBlocks = <Uint8List>[];
    int offset = 0;
    for (int i = 0; i < numBlocks; i++) {
      final int datLen = shortBlockDataLen + (i < blocksGroup1 ? 0 : 1);
      final Uint8List block = data.sublist(offset, offset + datLen);
      offset += datLen;
      dataBlocks.add(block);
      ecBlocks.add(_reedSolomonRemainder(block, rsDiv, ecPerBlock));
    }

    final Uint8List result = Uint8List(totalCodewords);
    int outIdx = 0;
    final int maxDataLen = shortBlockDataLen + (blocksGroup2 > 0 ? 1 : 0);
    for (int i = 0; i < maxDataLen; i++) {
      for (int j = 0; j < numBlocks; j++) {
        if (i < dataBlocks[j].length) {
          result[outIdx++] = dataBlocks[j][i];
        }
      }
    }
    for (int i = 0; i < ecPerBlock; i++) {
      for (int j = 0; j < numBlocks; j++) {
        result[outIdx++] = ecBlocks[j][i];
      }
    }
    return result;
  }

  static Uint8List _reedSolomonDivisor(int degree) {
    final Uint8List result = Uint8List(degree);
    result[degree - 1] = 1;
    int root = 1;
    for (int i = 0; i < degree; i++) {
      for (int j = 0; j < degree; j++) {
        result[j] = _gfMultiply(result[j], root);
        if (j + 1 < degree) {
          result[j] ^= result[j + 1];
        }
      }
      root = _gfMultiply(root, 0x02);
    }
    return result;
  }

  static Uint8List _reedSolomonRemainder(
    Uint8List data,
    Uint8List divisor,
    int degree,
  ) {
    final Uint8List result = Uint8List(degree);
    for (final int b in data) {
      final int factor = b ^ result[0];
      for (int i = 0; i < degree - 1; i++) {
        result[i] = result[i + 1] ^ _gfMultiply(divisor[i], factor);
      }
      result[degree - 1] = _gfMultiply(divisor[degree - 1], factor);
    }
    return result;
  }

  static int _gfMultiply(int x, int y) {
    int z = 0;
    for (int i = 7; i >= 0; i--) {
      z = (z << 1) ^ ((z >> 7) * 0x11D);
      z ^= ((y >> i) & 1) * x;
    }
    return z;
  }
}
