import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piecework/core/app_info.dart';
import 'package:piecework/data/services/remote_manifest.dart';

/// 公告 / 更新清单解析 + 加速地址
void main() {
  Map<String, dynamic> manifestJson({
    Object? operating = true,
    Object? notice,
    Object? latest,
  }) =>
      <String, dynamic>{
        'operating': operating,
        'operatingMessage': '维护中',
        'publicNotice': notice,
        'latest': latest,
        'fetchedAt': DateTime(2026, 11, 24).toIso8601String(),
      };

  group('清单解析', () {
    test('完整清单', () {
      final m = RemoteManifest.fromJson(manifestJson(
        notice: <String, dynamic>{
          'id': 'n1',
          'level': 'critical',
          'title': '口径更正',
          'body': '请重新核对',
          'active': true,
        },
        latest: <String, dynamic>{
          'versionCode': kAppVersionCode + 1,
          'versionName': '1.0.1',
          'apkUrl': 'https://x/y.apk',
          'notes': '修复',
        },
      ));
      expect(m, isNotNull);
      expect(m!.operating, isTrue);
      expect(m.publicNotice!.level, NoticeLevel.critical);
      expect(m.publicNotice!.visible, isTrue);
      expect(m.latest!.versionCode, kAppVersionCode + 1);
      expect(m.latest!.isNewer, isTrue);
    });

    test('operating=false 会被识别（停运）', () {
      final m = RemoteManifest.fromJson(manifestJson(operating: false));
      expect(m!.operating, isFalse);
      expect(m.operatingMessage, '维护中');
    });

    test('公告 active=false / 过期 都不弹', () {
      final off = RemoteManifest.fromJson(manifestJson(
        notice: <String, dynamic>{
          'id': 'n2',
          'title': 't',
          'body': 'b',
          'active': false,
        },
      ));
      expect(off!.publicNotice!.visible, isFalse);

      final expired = RemoteManifest.fromJson(manifestJson(
        notice: <String, dynamic>{
          'id': 'n3',
          'title': 't',
          'body': 'b',
          'active': true,
          'expiresAt': '2020-01-01',
        },
      ));
      expect(expired!.publicNotice!.visible, isFalse);
    });

    test('versionCode 不大于当前版本 → 不提示更新', () {
      final m = RemoteManifest.fromJson(manifestJson(
        latest: <String, dynamic>{'versionCode': kAppVersionCode},
      ));
      expect(m!.latest!.isNewer, isFalse);
    });

    test('没有 latest / 坏数据不炸', () {
      expect(RemoteManifest.fromJson(manifestJson())!.latest, isNull);
      expect(RemoteManifest.fromJson(null), isNull);
      expect(RemoteManifest.fromJson('x'), isNull);
      expect(RemoteManifest.fromJson(<String, dynamic>{}), isNotNull);
    });

    test('JSON 往返（缓存用）', () {
      final m = RemoteManifest.fromJson(manifestJson(
        notice: <String, dynamic>{'id': 'n1', 'title': 't', 'body': 'b'},
        latest: <String, dynamic>{
          'versionCode': kAppVersionCode + 10,
          'versionName': '3.0.0',
          'apkUrl': 'https://x',
        },
      ))!;
      final back = RemoteManifest.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
      )!;
      expect(back.operating, m.operating);
      expect(back.publicNotice!.id, 'n1');
      expect(back.latest!.versionCode, kAppVersionCode + 10);
    });
  });

  group('加速地址', () {
    test('套上 gh 前缀', () {
      expect(
        accelerateUrl('https://github.com/a/b/releases/download/v1/x.apk'),
        'https://gh.y4cc.cc/gh/https://github.com/a/b/releases/download/v1/x.apk',
      );
    });

    test('已经加速过的不重复套', () {
      final once = accelerateUrl('https://github.com/a/b');
      expect(accelerateUrl(once), once);
    });

    test('清单地址两个版本都在', () {
      expect(kManifestRawUrl, contains('raw.githubusercontent.com'));
      expect(kManifestAcceleratedUrl, startsWith(kGhProxy));
    });
  });
}
