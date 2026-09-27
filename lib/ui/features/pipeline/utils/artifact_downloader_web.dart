import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

void triggerArtifactDownloadImpl(String artifactRelativePath) {
  try {
    final String cleanPath = artifactRelativePath.startsWith('/')
        ? artifactRelativePath.substring(1)
        : artifactRelativePath;
    final String fileName = cleanPath.split('/').last;
    final String encodedUrl = cleanPath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');

    final web.HTMLAnchorElement anchor =
        web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = '/$encodedUrl?download=1';
    anchor.download = fileName;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } catch (_) {}
}

Future<bool> revealArtifactInExplorerImpl(String artifactRelativePath) async {
  try {
    final String cleanPath = artifactRelativePath.startsWith('/')
        ? artifactRelativePath.substring(1)
        : artifactRelativePath;
    final Uri uri = Uri.parse(
      '/api/reveal?path=${Uri.encodeQueryComponent(cleanPath)}',
    );
    final http.Response resp = await http
        .get(uri)
        .timeout(const Duration(seconds: 3));
    return resp.statusCode == 200;
  } catch (_) {
    return false;
  }
}
