import 'package:flutter/widgets.dart';

/// 引导用的控件锚点。
///
/// 放在一个地方统一管理：教程步骤只认 key，UI 那边把 key 挂到对应控件上。
/// key 拿不到 context 时（控件还没渲染），引导会自动降级成「只显示说明卡」，
/// 不会崩。
class TourKeys {
  TourKeys._();

  // 备份（必做）
  static final GlobalKey backupCard = GlobalKey(debugLabel: 'backupCard');
  static final GlobalKey backupFolder = GlobalKey(debugLabel: 'backupFolder');
  static final GlobalKey backupPassword = GlobalKey(debugLabel: 'backupPassword');
  static final GlobalKey backupNow = GlobalKey(debugLabel: 'backupNow');
  static final GlobalKey backupRestore = GlobalKey(debugLabel: 'backupRestore');

  // 录入
  static final GlobalKey recordFab = GlobalKey(debugLabel: 'recordFab');
  static final GlobalKey recordPhoto = GlobalKey(debugLabel: 'recordPhoto');
  static final GlobalKey recordQty = GlobalKey(debugLabel: 'recordQty');
  static final GlobalKey recordSave = GlobalKey(debugLabel: 'recordSave');

  // AI
  static final GlobalKey aiInput = GlobalKey(debugLabel: 'aiInput');
  static final GlobalKey aiSend = GlobalKey(debugLabel: 'aiSend');

  // 底部导航
  static final GlobalKey navRecords = GlobalKey(debugLabel: 'navRecords');
  static final GlobalKey navAi = GlobalKey(debugLabel: 'navAi');
  static final GlobalKey navSettings = GlobalKey(debugLabel: 'navSettings');
}
