import 'dart:io';

/// 拾句 (ShiJu) · iPhone / 移动端局域网 PWA 静态资源服务器
Future<void> main(List<String> args) async {
  final int port = args.isNotEmpty ? (int.tryParse(args.first) ?? 8080) : 8080;
  final Directory webDir = Directory('build/web');

  if (!webDir.existsSync()) {
    stderr.writeln('未找到 build/web 目录，请先运行: flutter build web --release');
    exit(1);
  }

  final HttpServer server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    port,
    shared: true,
  );

  final List<String> lanIps = <String>[];
  try {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final NetworkInterface iface in interfaces) {
      for (final InternetAddress addr in iface.addresses) {
        if (!addr.address.startsWith('169.254.') &&
            !addr.address.startsWith('172.18.')) {
          lanIps.add('${addr.address} (${iface.name})');
        }
      }
    }
  } catch (_) {}

  stdout.writeln('============================================================');
  stdout.writeln('  拾句 (ShiJu) · iPhone 17 PWA 局域网服务已启动');
  stdout.writeln('============================================================');
  stdout.writeln('  本机访问: http://127.0.0.1:$port');
  if (lanIps.isNotEmpty) {
    for (final String ipInfo in lanIps) {
      final String ip = ipInfo.split(' ').first;
      stdout.writeln('  iPhone 17 Safari 访问: http://$ip:$port');
    }
  }
  stdout.writeln('------------------------------------------------------------');
  stdout.writeln('  在 iPhone 17 Safari 打开上述地址后：');
  stdout.writeln('  点击底部「分享」按钮 -> 选择「添加到主屏幕」即可全屏独立运行');
  stdout.writeln('============================================================');

  await for (final HttpRequest request in server) {
    _handleRequest(request, webDir);
  }
}

Future<void> _handleRequest(HttpRequest request, Directory webDir) async {
  try {
    String reqPath = Uri.decodeComponent(request.uri.path);
    if (reqPath.startsWith('/ShiJu/')) {
      reqPath = reqPath.substring('/ShiJu'.length);
    } else if (reqPath == '/ShiJu') {
      reqPath = '/index.html';
    }
    if (reqPath == '/' || reqPath.isEmpty) {
      reqPath = '/index.html';
    }

    final String cleanRelPath =
        reqPath.replaceFirst(RegExp(r'^/+'), '').replaceAll('/', Platform.pathSeparator);
    File file = File('${webDir.path}${Platform.pathSeparator}$cleanRelPath');

    if (!file.existsSync() || FileSystemEntity.isDirectorySync(file.path)) {
      file = File('${webDir.path}${Platform.pathSeparator}index.html');
    }

    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final String ext = _extensionOf(file.path);
    request.response.headers.set(HttpHeaders.contentTypeHeader, _mimeType(ext));
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Cache-Control', 'no-cache');

    await request.response.addStream(file.openRead());
    await request.response.close();
  } catch (_) {
    try {
      await request.response.close();
    } catch (_) {}
  }
}

String _extensionOf(String path) {
  final int dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}

String _mimeType(String ext) {
  return switch (ext) {
    '.html' || '.htm' => 'text/html; charset=utf-8',
    '.js' || '.mjs' => 'application/javascript; charset=utf-8',
    '.css' => 'text/css; charset=utf-8',
    '.json' => 'application/json; charset=utf-8',
    '.wasm' => 'application/wasm',
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.svg' => 'image/svg+xml',
    '.ico' => 'image/x-icon',
    '.ttf' => 'font/ttf',
    '.otf' => 'font/otf',
    '.woff' => 'font/woff',
    '.woff2' => 'font/woff2',
    _ => 'application/octet-stream',
  };
}
