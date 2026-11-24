import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/format.dart';
import '../../data/models/filter_preset.dart';
import '../../data/models/piece_record.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/photo_service.dart';
import '../../providers/chat_providers.dart';
import '../../providers/db_providers.dart';
import '../../providers/options_providers.dart';
import '../../providers/presets_providers.dart';
import '../../providers/records_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/ui_providers.dart';
import 'ai_settings_page.dart';
import 'about_page.dart';
import 'gallery_page.dart';
import 'onboarding_page.dart';
import 'profiles_page.dart';
import 'webdav_page.dart';
import '../widgets/tutorials.dart';
import 'tutorials_page.dart';
import '../widgets/backup_panel.dart';
import 'op_history_page.dart';
import 'trash_page.dart';
import 'options_page.dart';
import 'units_page.dart';

/// 设置页：AI 配置入口、主题、选项管理、筛选预设、备份恢复、缓存清理
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// 正在执行的长任务名（null 表示空闲）
  String? _busy;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────────────────────── 备份 ─────────────────────────

  Future<void> _backup() async {
    if (_busy != null) return;
    setState(() => _busy = '正在打包备份…');
    try {
      final bytes = await ref.read(backupServiceProvider).createBackup();
      final name = BackupService.defaultFileName();
      final saved = await _saveBytes(bytes, name, 'zip');
      ref.invalidate(settingsProvider);
      _toast(saved == null ? '已取消保存' : '备份完成：$saved');
    } catch (e) {
      _toast('备份失败：$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _restore() async {
    if (_busy != null) return;

    Uint8List? bytes;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      final Object? raw = f.bytes;
      bytes = raw is Uint8List ? raw : null;
      if (bytes == null) {
        final path = f.path;
        if (path != null) {
          bytes = await File(path).readAsBytes();
        }
      }
    } catch (e) {
      _toast('读取文件失败：$e');
      return;
    }
    if (bytes == null) return;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: const Text(
          '恢复会**覆盖**当前所有记录、选项、预设和对话记录。\n'
          '建议先做一次备份再恢复。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('继续恢复'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = '正在恢复…');
    try {
      final report = await ref.read(backupServiceProvider).restore(bytes);
      ref.invalidate(recordsProvider);
      ref.invalidate(optionsProvider);
      ref.invalidate(presetsProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(chatProvider);
      _toast('恢复完成：${report.summary}');
    } catch (e) {
      _toast('恢复失败：$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// 优先走系统「保存到…」，不可用时退回应用文档目录
  Future<String?> _saveBytes(Uint8List bytes, String name, String ext) async {
    String? saved;
    try {
      saved = await FilePicker.saveFile(
        dialogTitle: '保存到',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: <String>[ext],
        bytes: bytes,
      );
    } catch (_) {
      saved = null;
    }
    if (saved != null) return saved;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ───────────────────────── 清理 ─────────────────────────

  Future<void> _cleanImages() async {
    if (_busy != null) return;
    setState(() => _busy = '正在清理图片…');
    try {
      final records =
          ref.read(recordsProvider).valueOrNull ?? const <PieceRecord>[];
      final repo = ref.read(recordRepoProvider);

      // 1) 记录引用了但文件已丢失 → 把引用置空
      var repaired = 0;
      for (final r in records) {
        if (r.photoName.isEmpty) continue;
        final f = PhotoService.instance.syncFile(r.photoName);
        final exists = f != null && await f.exists();
        if (!exists) {
          r.photoName = '';
          await repo.save(r);
          repaired++;
        }
      }

      // 2) 没有任何引用（含回收站里的记录）的孤儿文件 → 删除
      final gc = ref.read(photoGcProvider);
      final removedPhotos = await gc.cleanOrphans();
      final removedChat = await gc.cleanOrphans(sub: PhotoService.chatDir);

      _toast('已修复 $repaired 条记录引用，清理 ${removedPhotos + removedChat} 张无主图片');
    } catch (e) {
      _toast('清理失败：$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _clearAllRecords() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有记录'),
        content: const Text('会删除全部计件记录和照片，不可恢复。\n强烈建议先备份。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = '正在清空…');
    try {
      await ref.read(recordRepoProvider).clear();
      // 记录清空后所有图都没人引用了，走同一套引用计数逻辑
      final gc = ref.read(photoGcProvider);
      final removed = await gc.cleanOrphans();
      _toast('已清空全部记录（清理 $removed 张图片）');
    } catch (e) {
      _toast('清空失败：$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final aiConfig = ref.watch(aiConfigProvider);
    final scheme = Theme.of(context).colorScheme;
    final presets = ref.watch(presetsProvider).valueOrNull ?? <FilterPreset>[];
    final recordCount =
        ref.watch(recordsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
            children: <Widget>[
              _sectionTitle('新手教程', scheme),
              _tile(
                scheme,
                icon: Icons.waving_hand_outlined,
                title: '重看首次引导',
                subtitle: '数据安全 / 身份卡 那几步，重新走一遍',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingPage(),
                  ),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.school_outlined,
                title: '教程关卡',
                subtitle: '开启备份 / 重装恢复 / 录入 / 问 AI —— 点哪条教哪条',
                onTap: () async {
                  final t = await Navigator.of(context).push<Tutorial>(
                    MaterialPageRoute<Tutorial>(
                      builder: (_) => const TutorialsPage(),
                    ),
                  );
                  if (t != null && context.mounted) {
                    await runTutorial(context, ref, t);
                  }
                },
              ),

              _sectionTitle('AI 助手', scheme),
              _tile(
                scheme,
                icon: Icons.auto_awesome,
                title: 'AI 接口配置',
                subtitle: aiConfig.model.trim().isEmpty
                    ? '未配置'
                    : '${aiConfig.providerName.isEmpty ? "" : "${aiConfig.providerName} · "}'
                        '${aiConfig.model}',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
                ),
              ),

              _sectionTitle('外观', scheme),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: _cardDecoration(scheme),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.palette_outlined,
                            size: 19, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        const Text('主题',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<int>(
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment<int>(value: 0, label: Text('跟随系统')),
                        ButtonSegment<int>(value: 1, label: Text('亮色')),
                        ButtonSegment<int>(value: 2, label: Text('暗色')),
                      ],
                      selected: <int>{settings?.themeModeIndex ?? 0},
                      onSelectionChanged: (s) {
                        ref
                            .read(settingsProvider.notifier)
                            .mutate((st) => st.themeModeIndex = s.first);
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      showSelectedIcon: false,
                    ),
                  ],
                ),
              ),

              _sectionTitle('数据', scheme),
              const BackupPanel(),
              const SizedBox(height: 8),
              _tile(
                scheme,
                icon: Icons.backup_outlined,
                title: '备份到文件',
                subtitle: settings == null || settings.lastBackupMs == 0
                    ? '包含数据库 + 全部照片（zip）'
                    : '上次备份：${Fmt.dateTime(DateTime.fromMillisecondsSinceEpoch(settings.lastBackupMs))}',
                onTap: _backup,
              ),
              _tile(
                scheme,
                icon: Icons.restore_outlined,
                title: '从备份恢复',
                subtitle: '选择之前导出的 .zip 文件',
                onTap: _restore,
              ),
              _tile(
                scheme,
                icon: Icons.info_outline,
                title: '关于',
                subtitle: '版本 / 项目链接 / 加我微信 / 检查更新',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.badge_outlined,
                title: '身份卡（多人管理）',
                subtitle: '每个人一张卡，记录/报表/AI 全部隔离',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const ProfilesPage()),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.cloud_outlined,
                title: '云备份（WebDAV）',
                subtitle: '把加密备份传到自己的网盘，换机也不怕',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const WebDavPage()),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.photo_library_outlined,
                title: '图库（图片编号）',
                subtitle: '看所有图片、查关联记录、复制编号给 AI 用',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const GalleryPage()),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.delete_sweep_outlined,
                title: '回收站',
                subtitle: '删除的记录保留 30 天，可随时恢复',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const TrashPage()),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.history,
                title: '操作历史',
                subtitle: '所有新增/修改/删除/上报都能撤回（保留 30 天）',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const OpHistoryPage()),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.cleaning_services_outlined,
                title: '清理无效图片缓存',
                subtitle: '修复丢失的图片引用，删除无主图片',
                onTap: _cleanImages,
              ),
              _tile(
                scheme,
                icon: Icons.delete_forever_outlined,
                title: '清空所有记录',
                subtitle: '当前共 $recordCount 条',
                danger: true,
                onTap: _clearAllRecords,
              ),

              _sectionTitle('选项管理', scheme),
              _tile(
                scheme,
                icon: Icons.list_alt_outlined,
                title: '型号 / 颜色 / 码数',
                subtitle: '维护录入时的可选列表',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const OptionsPage()),
                ),
              ),
              _tile(
                scheme,
                icon: Icons.straighten_outlined,
                title: '单位与换算',
                subtitle: '件 / 片 / 打，以及「100 片 = 30 件」这类折算规则',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const UnitsPage()),
                ),
              ),

              _sectionTitle('筛选预设', scheme),
              if (presets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(scheme),
                  child: Text(
                    '还没有预设。到「记录 → 筛选」设好条件后，点右上角书签图标即可保存。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Container(
                  decoration: _cardDecoration(scheme),
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < presets.length; i++) ...<Widget>[
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.bookmark_outline,
                              size: 19, color: scheme.primary),
                          title: Text(presets[i].name,
                              style: const TextStyle(fontSize: 13.5)),
                          subtitle: Text(
                            PresetsNotifier.decode(presets[i])?.summary ??
                                '（预设已损坏）',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 17),
                            onPressed: () => ref
                                .read(presetsProvider.notifier)
                                .remove(presets[i].id),
                          ),
                          onTap: () {
                            final f = PresetsNotifier.decode(presets[i]);
                            if (f == null) return;
                            ref.read(filterProvider.notifier).apply(f);
                            ref.read(tabIndexProvider.notifier).go(0);
                          },
                        ),
                        if (i != presets.length - 1)
                          Divider(
                            height: 1,
                            color: scheme.outlineVariant.withAlpha(110),
                          ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 26),
              Center(
                child: Text(
                  '计件助手 · 全部数据仅存本机\n不联网同步，不上传云端',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: scheme.onSurfaceVariant.withAlpha(170),
                  ),
                ),
              ),
            ],
          ),
          if (_busy != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withAlpha(60),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 18),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        const SizedBox(height: 12),
                        Text(_busy!,
                            style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _sectionTitle(String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(ColorScheme scheme) {
    return BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B1E24)
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
    );
  }

  Widget _tile(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? scheme.error : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            decoration: _cardDecoration(scheme),
            child: Row(
              children: <Widget>[
                Icon(icon,
                    size: 20,
                    color: danger ? scheme.error : scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant.withAlpha(150)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
