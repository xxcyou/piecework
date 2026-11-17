import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/data/services/webdav_service.dart';

/// 云备份（WebDAV）：地址规范化 + PROPFIND 解析
void main() {
  WebDavConfig cfg({String url = 'https://dav.example.com/dav/', String dir = ''}) =>
      WebDavConfig(
        url: url,
        username: 'u',
        password: 'p',
        dir: dir,
        enabled: true,
      );

  group('地址与目录规范化', () {
    test('远程目录自动补前后斜杠', () {
      expect(WebDavService(cfg(dir: 'piecework')).dir, '/piecework/');
      expect(WebDavService(cfg(dir: '/piecework')).dir, '/piecework/');
      expect(WebDavService(cfg(dir: '/a/b/')).dir, '/a/b/');
      expect(WebDavService(cfg(dir: '')).dir, '/piecework/');
    });

    test('文件 URL 拼接正确（末尾斜杠不会重复）', () {
      final s = WebDavService(cfg(url: 'https://dav.example.com/dav/', dir: 'bak'));
      expect(s.uriFor('x.pwb').toString(),
          'https://dav.example.com/dav/bak/x.pwb');
      final s2 = WebDavService(cfg(url: 'https://dav.example.com/dav', dir: '/bak/'));
      expect(s2.uriFor('x.pwb').toString(),
          'https://dav.example.com/dav/bak/x.pwb');
    });

    test('ready 需要：开启 + http 地址 + 密码', () {
      expect(cfg().ready, isTrue);
      expect(cfg(url: '').ready, isFalse);
      expect(
        WebDavConfig(url: 'https://x', username: '', password: '', dir: '', enabled: true)
            .ready,
        isFalse,
      );
      expect(
        WebDavConfig(url: 'https://x', username: 'u', password: 'p', dir: '', enabled: false)
            .ready,
        isFalse,
      );
    });
  });

  group('PROPFIND 解析', () {
    test('Nextcloud 风格（d: 前缀）', () {
      const xml = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/me/piecework/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/me/piecework/piecework_backup_20261117_220000.pwb</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>20480</d:getcontentlength>
      <d:getlastmodified>Mon, 17 Nov 2026 22:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>
''';
      final files = WebDavService.parseListing(xml);
      expect(files.length, 1);
      expect(files.first.name, 'piecework_backup_20261117_220000.pwb');
      expect(files.first.size, 20480);
      expect(files.first.modified, isNotNull);
    });

    test('无前缀（通用 WebDAV）+ 目录条目被忽略', () {
      const xml = '''
<multistatus xmlns="DAV:">
  <response><href>/dav/piecework/</href></response>
  <response>
    <href>/dav/piecework/piecework_backup_20261110_090000.pwb</href>
    <propstat><prop><getcontentlength>1024</getcontentlength></prop></propstat>
  </response>
  <response>
    <href>/dav/piecework/readme.txt</href>
    <propstat><prop><getcontentlength>10</getcontentlength></prop></propstat>
  </response>
</multistatus>
''';
      final files = WebDavService.parseListing(xml);
      expect(files.length, 1);
      expect(files.first.name, 'piecework_backup_20261110_090000.pwb');
    });

    test('按名字倒序 = 最新在前', () {
      const xml = '''
<multistatus>
  <response><href>/p/piecework_backup_20260101_000000.pwb</href></response>
  <response><href>/p/piecework_backup_20261231_235959.pwb</href></response>
</multistatus>
''';
      final files = WebDavService.parseListing(xml);
      expect(files.first.name, contains('20261231'));
    });

    test('空响应不炸', () {
      expect(WebDavService.parseListing(''), isEmpty);
      expect(WebDavService.parseListing('<multistatus></multistatus>'), isEmpty);
    });
  });
}
