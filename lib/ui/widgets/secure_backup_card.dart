import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/public_folder.dart';
import '../../data/services/secure_backup_service.dart';
import '../../providers/chat_providers.dart';
import '../../providers/db_providers.dart';
import '../../providers/options_providers.dart';
import '../../providers/presets_providers.dart';
import '../../providers/records_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/units_providers.dart';
import '../tour_keys.dart';

/// 加密自动备份区（**唯一的自动备份通道**）。
///
/// * 落点：/storage/emulated/0/ 下用户自己授权的文件夹（SAF 持久化权限）
/// * 加密：AES-256-GCM，密钥由备份密码经 PBKDF2 派生
/// * 数据一变就自动写一份（防抖 25 秒），留最近 10 份
class SecureBackupSection extends ConsumerStatefulWidget {
  const SecureBackupSection({super.key});

  @override
  ConsumerState<SecureBackupSection> createState() => _SecureBackupSectionState();
}

class _SecureBackupSectionState extends ConsumerState<SecureBackupSection> {
  SecureBackupConfig? _cfg;
  List<FolderFile> _files = const <FolderFile>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final cfg = await SecureBackupService.instance.load();
    var files = const <FolderFile>[];
    if (cfg.folderReady) {
      try {
        files = await SecureBackupService.instance.listBackups();
      } catch (_) {
        files = const <FolderFile>[];
      }
    }
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _files = files;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> pickFolder() async {
    if (!PublicFolder.supported) {
      _toast('只有 Android 支持写公共目录');
      return;
    }
    setState(() => _busy = true);
    try {
      final grant = await PublicFolder.pick();
      if (grant == null) return;
      final cfg = await SecureBackupService.instance.load();
      cfg.folderUri = grant.uri;
      cfg.folderLabel = grant.label;
      await SecureBackupService.instance.save(cfg);
      await reload();
      _toast('已授权文件夹：${grant.label}');
    } catch (e) {
      _toast('授权失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> setPassword() async {
    final ctrl = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置备份密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '备份文件用这个密码派生的密钥加密（AES-256-GCM）。\n'
              '密码本身不保存，只保存派生出的密钥。\n'
              '换手机/重装后输入同一个密码就能解开旧备份 —— 别忘了它。',
              style: TextStyle(fontSize: 12, height: 1.55),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '备份密码（至少 6 位）'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: '再输一次'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final pwd = ctrl.text.trim();
    if (pwd.length < 6) {
      _toast('密码至少 6 位');
      return;
    }
    if (pwd != confirm.text.trim()) {
      _toast('两次输入不一致');
      return;
    }
    await SecureBackupService.instance.setPassword(pwd);
    await reload();
    _toast('备份密码已设置');
  }

  Future<void> backupNow() async {
    final cfg = _cfg;
    if (cfg == null || !cfg.ready) {
      _toast(cfg == null || !cfg.folderReady ? '先选择备份文件夹' : '先设置备份密码');
      return;
    }
    setState(() => _busy = true);
    try {
      final isar = ref.read(isarProvider);
      final zip = await BackupService(isar).createBackup();
      final name = await SecureBackupService.instance.runAuto(zip);
      await reload();
      _toast(name == null ? '备份失败：还没配置好' : '已加密备份：$name');
    } catch (e) {
      _toast('备份失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cfg = _cfg;
    final ready = cfg?.ready ?? false;

    return Column(
      key: TourKeys.backupCard,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 7),
            const Text(
              '加密自动备份',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (ready ? const Color(0xFF10B981) : scheme.error)
                    .withAlpha(28),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ready ? '已开启' : '未开启',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: ready ? const Color(0xFF0F9D68) : scheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '数据一变就自动加密写一份到公共目录（/storage/emulated/0/ 下你选的文件夹）。'
          '卸载、换机、清数据都还在，是唯一防丢失通道。',
          style: TextStyle(
            fontSize: 11,
            height: 1.55,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        _row(
          scheme,
          icon: Icons.folder_outlined,
          label: '备份文件夹',
          value: (cfg?.folderLabel.isNotEmpty ?? false)
              ? cfg!.folderLabel
              : '未选择（要先授权）',
          ok: cfg?.folderReady ?? false,
        ),
        _row(
          scheme,
          icon: Icons.key_outlined,
          label: '备份密码',
          value: (cfg?.hasPassword ?? false) ? '已设置' : '未设置',
          ok: cfg?.hasPassword ?? false,
        ),
        _row(
          scheme,
          icon: Icons.schedule,
          label: '上次备份',
          value: cfg?.lastAt == null ? '还没有' : Fmt.dateTime(cfg!.lastAt!),
          ok: cfg?.lastAt != null,
        ),
        _row(
          scheme,
          icon: Icons.inventory_2_outlined,
          label: '公共目录',
          value: '${_files.length} 份',
          ok: _files.isNotEmpty,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            OutlinedButton.icon(
              key: TourKeys.backupFolder,
              onPressed: _busy ? null : pickFolder,
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('选择文件夹'),
            ),
            OutlinedButton.icon(
              key: TourKeys.backupPassword,
              onPressed: _busy ? null : setPassword,
              icon: const Icon(Icons.password, size: 16),
              label: const Text('设置密码'),
            ),
            FilledButton.icon(
              key: TourKeys.backupNow,
              onPressed: _busy ? null : backupNow,
              icon: const Icon(Icons.lock_outline, size: 16),
              label: const Text('立即备份'),
            ),
            OutlinedButton.icon(
              key: TourKeys.backupRestore,
              onPressed: _busy
                  ? null
                  : () => SecureBackupFlow.restoreFromFolder(
                        context: context,
                        ref: ref,
                        onDone: reload,
                      ),
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('从备份恢复'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    required String value,
    required bool ok,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ok ? scheme.onSurface : scheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 恢复流程：选目录 → 挑文件 → 输密码 → 覆盖恢复
class SecureBackupFlow {
  SecureBackupFlow._();

  static Future<void> restoreFromFolder({
    required BuildContext context,
    required WidgetRef ref,
    VoidCallback? onDone,
  }) async {
    if (!PublicFolder.supported) {
      _toast(context, '只有 Android 支持从公共目录恢复');
      return;
    }
    final grant = await PublicFolder.pick();
    if (grant == null) return;

    final cfg = await SecureBackupService.instance.load();
    cfg.folderUri = grant.uri;
    cfg.folderLabel = grant.label;
    await SecureBackupService.instance.save(cfg);

    final files = await SecureBackupService.instance.listBackups();
    if (files.isEmpty) {
      _toast(context, '这个文件夹里没有 ${SecureBackupService.filePrefix}*.pwb');
      return;
    }
    if (!context.mounted) return;

    final picked = await showModalBottomSheet<FolderFile>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '选一份备份恢复',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            for (final f in files)
              ListTile(
                dense: true,
                leading: const Icon(Icons.lock_outline, size: 18),
                title: Text(f.name, style: const TextStyle(fontSize: 12.5)),
                subtitle: Text(
                  '${(f.size / 1024).toStringAsFixed(1)} KB · '
                  '${Fmt.dateTime(f.modifiedAt)}',
                  style: const TextStyle(fontSize: 10.5),
                ),
                onTap: () => Navigator.of(ctx).pop(f),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    await restoreFile(
      context: context,
      ref: ref,
      name: picked.name,
      onDone: onDone,
    );
  }

  static Future<void> restoreFile({
    required BuildContext context,
    required WidgetRef ref,
    required String name,
    VoidCallback? onDone,
  }) async {
    final cfg = await SecureBackupService.instance.load();
    final pwdCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复这份备份？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(name, style: const TextStyle(fontSize: 11.5)),
            const SizedBox(height: 10),
            const Text('当前记录会被这份备份覆盖。', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '备份密码',
                helperText: cfg.hasPassword
                    ? '留空用本机已保存的密钥'
                    : '重装后要输入当初设置的密码',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final report = await SecureBackupService.instance.restore(
        name,
        password: pwdCtrl.text.trim().isEmpty ? null : pwdCtrl.text.trim(),
      );
      _refreshAll(ref);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('恢复完成'),
          content: Text(report.summary),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
      onDone?.call();
    } catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('恢复失败'),
          content: Text('$e'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  static void _refreshAll(WidgetRef ref) {
    ref.invalidate(recordsProvider);
    ref.invalidate(optionsProvider);
    ref.invalidate(unitsProvider);
    ref.invalidate(presetsProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(chatProvider);
    ref.invalidate(aiConfigProvider);
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
