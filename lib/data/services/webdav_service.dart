import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 云端（WebDAV）上的一个备份文件
class WebDavFile {
  const WebDavFile({
    required this.name,
    required this.size,
    required this.modified,
  });

  final String name;
  final int size;
  final DateTime? modified;
}

/// 云备份配置（存在 AppSetting 里，UI 直接读写）
class WebDavConfig {
  const WebDavConfig({
    required this.url,
    required this.username,
    required this.password,
    required this.dir,
    required this.enabled,
  });

  final String url;
  final String username;
  final String password;

  /// 远程目录，例如 `/piecework/`（自动补前后斜杠）
  final String dir;
  final bool enabled;

  bool get ready =>
      enabled &&
      url.trim().isNotEmpty &&
      url.trim().startsWith('http') &&
      password.isNotEmpty;

  WebDavConfig copyWith({bool? enabled}) => WebDavConfig(
        url: url,
        username: username,
        password: password,
        dir: dir,
        enabled: enabled ?? this.enabled,
      );
}

/// 极简 WebDAV 客户端：够用就好（PUT / GET / PROPFIND / MKCOL / DELETE）。
///
/// 只依赖 http 包，不做复杂的 XML 解析 —— 只从 PROPFIND 的响应里挑出
/// `<d:href>` 和 `getcontentlength`，够列备份列表用了。
class WebDavService {
  WebDavService(this.config);

  final WebDavConfig config;

  /// 规范化后的目录（前后都有斜杠）
  String get dir {
    var d = config.dir.trim();
    if (d.isEmpty) d = '/piecework/';
    if (!d.startsWith('/')) d = '/$d';
    if (!d.endsWith('/')) d = '$d/';
    return d;
  }

  Uri uriFor(String name) => Uri.parse('${_base()}/${dir.substring(1)}$name');

  Uri dirUri() => Uri.parse('${_base()}/${dir.substring(1)}');

  String _base() {
    final u = config.url.trim();
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  Map<String, String> get _auth {
    if (config.username.isEmpty) return <String, String>{};
    final raw = '${config.username}:${config.password}';
    return <String, String>{
      'Authorization': 'Basic ${base64Encode(utf8.encode(raw))}',
    };
  }

  /// 测试连接：目录存在就返回 null，不存在尝试创建
  Future<String?> test() async {
    try {
      final res = await _request('PROPFIND', dirUri(), headers: <String, String>{
        'Depth': '0',
      });
      if (res.statusCode == 207 || res.statusCode == 200) return null;
      if (res.statusCode == 404) {
        final made = await _request('MKCOL', dirUri());
        if (made.statusCode == 201 ||
            made.statusCode == 200 ||
            made.statusCode == 405) {
          return null; // 405 = 已存在
        }
        return '创建目录失败：HTTP ${made.statusCode}';
      }
      if (res.statusCode == 401) return '用户名或密码不对（401）';
      return '连接失败：HTTP ${res.statusCode}';
    } catch (e) {
      return '连接失败：$e';
    }
  }

  /// 上传一份备份；返回最终文件名
  Future<String> upload(Uint8List bytes, String name) async {
    await _ensureDir();
    final res = await _request('PUT', uriFor(name), body: bytes, headers: <String, String>{
      'Content-Type': 'application/octet-stream',
    });
    if (res.statusCode >= 300) {
      throw FormatException('上传失败：HTTP ${res.statusCode}');
    }
    return name;
  }

  Future<Uint8List> download(String name) async {
    final res = await _request('GET', uriFor(name));
    if (res.statusCode != 200) {
      throw FormatException('下载失败：HTTP ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  Future<void> delete(String name) async {
    await _request('DELETE', uriFor(name));
  }

  /// 列目录里的备份文件（按名字倒序 = 最新在前）
  Future<List<WebDavFile>> list() async {
    final res = await _request('PROPFIND', dirUri(), headers: <String, String>{
      'Depth': '1',
    });
    if (res.statusCode != 207 && res.statusCode != 200) {
      throw FormatException('列目录失败：HTTP ${res.statusCode}');
    }
    final xml = utf8.decode(res.bodyBytes, allowMalformed: true);
    return parseListing(xml);
  }

  /// 解析 PROPFIND 响应（Nextcloud / 坚果云 / 通用 WebDAV 都能用）
  static List<WebDavFile> parseListing(String xml) {
    final out = <WebDavFile>[];
    // 每个 <d:response> 块里取 href / getcontentlength / getlastmodified
    for (final block in xml.split(RegExp(r'</[a-zA-Z0-9]+:response>|<response>'))) {
      final href = _pick(block, 'href');
      if (href == null) continue;
      final name = Uri.decodeComponent(href.split('/').last);
      if (name.isEmpty || !name.endsWith('.pwb')) continue;
      final size = int.tryParse(_pick(block, 'getcontentlength') ?? '') ?? 0;
      // getlastmodified 是 RFC 1123（Mon, 17 Nov 2026 22:00:00 GMT），
      // DateTime.tryParse 不认，得用 HttpDate；也兼容 ISO 写法的服务端
      final rawModified = _pick(block, 'getlastmodified') ?? '';
      DateTime? modified;
      try {
        modified = rawModified.isEmpty ? null : HttpDate.parse(rawModified);
      } catch (_) {
        modified = DateTime.tryParse(rawModified);
      }
      out.add(WebDavFile(name: name, size: size, modified: modified));
    }
    out.sort((a, b) => b.name.compareTo(a.name));
    return out;
  }

  /// 只保留最新 [keep] 份
  Future<void> prune(int keep) async {
    try {
      final files = await list();
      for (final f in files.skip(keep)) {
        await delete(f.name);
      }
    } catch (_) {
      // 清理失败不影响本次上传
    }
  }

  Future<void> _ensureDir() async {
    final err = await test();
    if (err != null) throw FormatException(err);
  }

  static String? _pick(String block, String tag) {
    final m = RegExp(
      '<(?:[a-zA-Z0-9]+:)?$tag[^>]*>([^<]*)<',
      caseSensitive: false,
    ).firstMatch(block);
    return m?.group(1)?.trim();
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) async {
    final req = http.Request(method, uri);
    req.headers.addAll(_auth);
    req.headers.addAll(headers);
    if (body != null) req.bodyBytes = body;
    final streamed = await req.send().timeout(const Duration(seconds: 25));
    return http.Response.fromStream(streamed);
  }
}
