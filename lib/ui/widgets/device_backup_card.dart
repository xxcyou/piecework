import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/services/device_backup_service.dart';
import '../../providers/db_providers.dart';

/// 「自动备份（免设置）」卡片：不需要用户做任何事，数据一变就备份到
/// 下载/Piecework/，卸载重装也能恢复。
class DeviceBackupCard extends ConsumerStatefulWidget {
  const DeviceBackupCard({super.key});

  @override
  ConsumerState<DeviceBackupCard> createState() => _DeviceBackupCardState();
}

class _DeviceBackupCardState extends ConsumerState<DeviceBackupCard> {
  List<DeviceBackupFile> _files = const <DeviceBackupFile>[];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DeviceBackupService.instance.list();
    if (!mounted) return;
    setState(() {
      _files = list.where((f) => f.name.startsWith(DeviceBackupService.prefix))
          .toList();
      _loading = false;
    });
  }

  Future<void> _restore(DeviceBackupFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从这个备份恢复？'),
        content: Text(
          '${f.name}\n${Fmt.dateTime(f.modified)} · '
          '${(f.size / 1024).toStringAsFixed(0)} KB\n\n'
          '会用备份里的数据覆盖当前数据。',
          style: const TextStyle(fontSize: 12, height: 1.5),
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
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final report = await DeviceBackupService.instance
          .restore(ref.read(isarProvider), f.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复：${report.records} 条记录')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = _files.isEmpty ? null : _files.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              const Text('自动备份（免设置）',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _loading ? '…' : '已开启',
                  style: TextStyle(fontSize: 9.5, color: scheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _loading
                ? '读取中…'
                : latest == null
                    ? '还没有备份，改一条记录就会自动生成'
                    : '共 ${_files.length} 份 · 最近 ${Fmt.dateTime(latest.modified)}',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '存在「下载/Piecework」，卸载重装也还在；文件用本机密钥加密。',
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
          if (_files.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pickAndRestore(),
                icon: const Icon(Icons.restore, size: 16),
                label: Text(_busy ? '恢复中…' : '从自动备份恢复',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndRestore() async {
    final pick = await showModalBottomSheet<DeviceBackupFile>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final f in _files)
              ListTile(
                leading: const Icon(Icons.archive_outlined, size: 18),
                title: Text(f.name, style: const TextStyle(fontSize: 12)),
                subtitle: Text(
                  '${Fmt.dateTime(f.modified)} · '
                  '${(f.size / 1024).toStringAsFixed(0)} KB',
                  style: const TextStyle(fontSize: 10.5),
                ),
                onTap: () => Navigator.of(ctx).pop(f),
              ),
          ],
        ),
      ),
    );
    if (pick != null) await _restore(pick);
  }
}
