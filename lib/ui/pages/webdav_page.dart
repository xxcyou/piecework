import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/services/auto_backup_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/secure_backup_service.dart';
import '../../data/services/webdav_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/records_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/webdav_providers.dart';

/// 云备份（WebDAV）：把加密备份传到自己的网盘
class WebDavPage extends ConsumerStatefulWidget {
  const WebDavPage({super.key});

  @override
  ConsumerState<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends ConsumerState<WebDavPage> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _dir;
  bool _busy = false;
  String? _msg;
  bool _msgError = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider).valueOrNull;
    _url = TextEditingController(text: s?.webdavUrl ?? '');
    _user = TextEditingController(text: s?.webdavUser ?? '');
    _pass = TextEditingController(text: s?.webdavPass ?? '');
    _dir = TextEditingController(
      text: (s?.webdavDir ?? '').isEmpty ? '/piecework/' : s!.webdavDir,
    );
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _dir.dispose();
    super.dispose();
  }

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _msg = text;
      _msgError = error;
    });
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).update((s) {
      s.webdavUrl = _url.text.trim();
      s.webdavUser = _user.text.trim();
      s.webdavPass = _pass.text;
      s.webdavDir = _dir.text.trim().isEmpty ? '/piecework/' : _dir.text.trim();
      return s;
    });
    ref.invalidate(webDavFilesProvider);
    _toast('已保存');
  }

  WebDavConfig get _cfg => WebDavConfig(
        url: _url.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        dir: _dir.text.trim().isEmpty ? '/piecework/' : _dir.text.trim(),
        enabled: true,
      );

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final err = await WebDavService(_cfg).test();
      _toast(err ?? '连接成功，目录可用', error: err != null);
      ref.invalidate(webDavFilesProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadNow() async {
    setState(() => _busy = true);
    try {
      final isar = ref.read(isarProvider);
      final zip = await BackupService(isar).createBackup();
      final enc = await SecureBackupService.instance.encryptWithSavedKey(zip);
      final name = await WebDavService(_cfg)
          .upload(enc, SecureBackupService.stampName());
      await WebDavService(_cfg).prune(SecureBackupService.keepCount);
      _toast('已上传：$name（${(enc.length / 1024).toStringAsFixed(1)} KB）');
      ref.invalidate(webDavFilesProvider);
    } catch (e) {
      _toast('上传失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(WebDavFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从云端恢复'),
        content: Text('用「${f.name}」覆盖本机数据？\n当前数据会被替换（云端文件不受影响）。'),
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

    setState(() => _busy = true);
    try {
      final blob = await WebDavService(_cfg).download(f.name);
      final report =
          await SecureBackupService.instance.restoreFromBytes(blob);
      ref.invalidate(recordsProvider);
      _toast('恢复完成：${report.records} 条记录');
    } catch (e) {
      _toast('恢复失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final setting = ref.watch(settingsProvider).valueOrNull;
    final enabled = setting?.webdavEnabled ?? false;
    final files = ref.watch(webDavFilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('云备份（WebDAV）')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            title: const Text('启用云备份'),
            subtitle: const Text('自动把加密备份传到你的网盘（同一份 AES-256 加密包）'),
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).update((s) {
                s.webdavEnabled = v;
                return s;
              });
              ref.invalidate(webDavFilesProvider);
            },
          ),
          const SizedBox(height: 6),
          _field('服务器地址', _url,
              hint: 'https://dav.example.com/remote.php/dav/files/me'),
          _field('用户名', _user, hint: '可留空（匿名/令牌写在地址里）'),
          _field('密码 / 应用密码', _pass, obscure: true),
          _field('远程目录', _dir, hint: '/piecework/'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_outlined, size: 17),
                  label: const Text('保存'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _test,
                  icon: const Icon(Icons.wifi_tethering, size: 17),
                  label: const Text('测试连接'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _uploadNow,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('立即上传一份'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          if (_msg != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _msg!,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: _msgError ? scheme.error : scheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Text(
                '云端备份',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref.invalidate(webDavFilesProvider),
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('刷新', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          files.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('读取失败：$e',
                  style: TextStyle(fontSize: 11.5, color: scheme.error)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '云端还没有备份。配好地址后点「立即上传一份」。',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (final f in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.cloud_outlined,
                          size: 20, color: scheme.primary),
                      title: Text(f.name,
                          style: const TextStyle(fontSize: 12)),
                      subtitle: Text(
                        '${(f.size / 1024).toStringAsFixed(1)} KB'
                        '${f.modified == null ? '' : ' · ${Fmt.dateTime(f.modified!)}'}',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _restore(f),
                        child: const Text('恢复',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            '说明：云端存的是和本地完全相同的 AES-256-GCM 加密包，'
            '没有备份密码谁也解不开；只保留最近 ${SecureBackupService.keepCount} 份。',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? hint,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}
