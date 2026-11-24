import 'dart:async';
import 'dart:io';

import 'package:isar_community/isar.dart';

import '../models/app_setting.dart';
import 'backup_service.dart';
import 'device_backup_service.dart';
import 'secure_backup_service.dart';
import 'webdav_service.dart';

/// 自动备份触发器。
///
/// **只有一个备份通道**：加密后写进用户授权的公共目录
/// （见 [SecureBackupService]）。以前那套「应用私有目录里的 auto_*.zip」
/// 已经删掉 —— 私有目录一卸载就没了，留着只会让人以为有两份备份。
///
/// 触发：数据一有变动就排一次（防抖 25 秒）。
class AutoBackupService {
  AutoBackupService._();

  static final AutoBackupService instance = AutoBackupService._();

  /// 防抖窗口：连续改 10 条只备份一次
  static const Duration debounce = Duration(seconds: 25);

  Isar? _isar;
  Timer? _timer;
  bool _running = false;

  /// 云备份配置（main() 注入；null = 没开云备份）
  WebDavConfig? _webdav;

  void attach(Isar isar) => _isar = isar;

  /// 设置变化时更新云备份配置
  void setWebDav(AppSetting? setting) {
    if (setting == null) return;
    _webdav = WebDavConfig(
      url: setting.webdavUrl,
      username: setting.webdavUser,
      password: setting.webdavPass,
      dir: setting.webdavDir,
      enabled: setting.webdavEnabled,
    );
  }

  /// 数据有变动时调用（防抖）
  void schedule() {
    if (_isar == null) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      // 失败不打扰用户，下次变动会再试
      unawaited(run());
    });
  }

  /// 立刻做一次加密备份。
  ///
  /// 返回写入公共目录的文件名；没配置（没选文件夹 / 没设密码）时返回 null。
  /// 权限失效等异常会抛出来，由调用方决定是提示还是静默。
  Future<String?> run() async {
    final isar = _isar;
    if (isar == null || _running) return null;
    _running = true;
    try {
      // ① 免设置备份（公共目录，卸载重装也在）—— 不依赖任何用户配置
      await DeviceBackupService.instance.run(isar);

      final bytes = await BackupService(isar).createBackup();
      final name = await SecureBackupService.instance.runAuto(bytes);

      // 本地写完再传云端（失败不影响本地备份）
      final cloud = _webdav;
      if (cloud != null && cloud.ready) {
        try {
          final enc = await SecureBackupService.instance
              .encryptWithSavedKey(bytes);
          final svc = WebDavService(cloud);
          await svc.upload(enc, SecureBackupService.stampName());
          await svc.prune(SecureBackupService.keepCount);
        } catch (_) {
          // 网络问题不该让本地备份失败
        }
      }
      return name;
    } finally {
      _running = false;
    }
  }

  /// 上次成功备份时间（从加密备份配置里读）
  Future<DateTime?> latestTime() async {
    final cfg = await SecureBackupService.instance.load();
    return cfg.lastAt;
  }

  /// 兼容旧调用：现在没有「私有目录备份」可删
  Future<int> clearAll() async => 0;

  /// 兼容旧调用：私有目录已不再使用
  Future<List<File>> list() async => const <File>[];

  Future<int> totalBytes() async => 0;
}
