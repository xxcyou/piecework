# 部署与构建说明

## 0. 环境要求

| 项 | 版本 |
|---|---|
| Flutter | **≥ 3.35**（推荐 3.38+；camera 0.11/0.12 要求 3.35+） |
| Dart | 随 Flutter |
| JDK | 17 |
| Android SDK | compileSdk 35 / targetSdk 35 |
| 最低运行版本 | Android 7.0（API 24） |

> 本项目**不含** `android/` 的完整 Gradle 工程（只有 `AndroidManifest.xml`），
> 因为 Gradle 模板随 Flutter 版本变化，硬塞进来反而容易冲突。
> 用 `flutter create` 生成一份，再把本项目的 `lib/` 和 `pubspec.yaml` 覆盖进去 —— 见下。

---

## 1. 组装工程（推荐流程）

```bash
# ① 用官方模板生成一个干净的 Android 工程
flutter create --org com.example --project-name piecework --platforms=android piecework_app
cd piecework_app

# ② 用本项目的 lib/ 覆盖模板的 lib/
rm -rf lib
cp -r /path/to/piecework/lib ./

# ③ 覆盖 pubspec / 分析配置 / Manifest
cp /path/to/piecework/pubspec.yaml .
cp /path/to/piecework/analysis_options.yaml .
cp /path/to/piecework/android/app/src/main/AndroidManifest.xml \
   android/app/src/main/AndroidManifest.xml

# ④ 拉依赖
flutter pub get

# ⑤ 生成 Isar 的 .g.dart（必须！否则编译报 part 文件缺失）
dart run build_runner build --delete-conflicting-outputs
```

第 ⑤ 步成功后，`lib/data/models/` 下会多出 7 个文件：

```
piece_record.g.dart
option_item.g.dart
filter_preset.g.dart
chat_message.g.dart
app_setting.g.dart
unit_item.g.dart      ← 计量单位
unit_rule.g.dart      ← 换算规则
```

## 1.5 跑测试（建议每次改动后都跑）

```bash
# 纯逻辑测试：过滤 / 排序 / 分组 / 财务精度 / 单位换算 / JSON 往返
flutter test

# 真机端到端：录入 → 列表 → 缺图筛选 → 四个标签页
flutter test integration_test/app_test.dart -d <device-id>
```

当前基线：**40 项单元测试 + 3 项报表渲染测试 + 1 项真机集成测试**全部通过。

`test/report_render_test.dart` 会把三套报表离屏渲染成 PNG 到 `build/preview/`，
改完排版直接看图验收，不用装到手机上：

```
build/preview/report_external.png   对外版（带缩略图）
build/preview/report_compact.png    自用紧凑版
build/preview/report_by_style.png   按型号分组
```

---

## 2. 修改 Gradle（重要）

打开 `android/app/build.gradle`（新版 Flutter 是 `build.gradle.kts`），确认：

### Groovy（`build.gradle`）
```gradle
android {
    namespace "com.example.piecework"
    compileSdk 35
    ndkVersion flutter.ndkVersion

    defaultConfig {
        applicationId "com.example.piecework"
        minSdk 24          // ← camera / gal / isar 都要求 ≥21，这里取 24 更稳
        targetSdk 35
        versionCode flutter.versionCode
        versionName flutter.versionName
    }
}
```

### Kotlin DSL（`build.gradle.kts`）
```kotlin
android {
    namespace = "com.example.piecework"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.piecework"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}
```

> **关于 NDK**：`isar_community_flutter_libs` 自带预编译 `.so`，
> 一般不需要手动指定 NDK 版本。如果构建时报 NDK 版本不匹配，
> 在 `android/app/build.gradle` 里写死一个已安装的版本，例如
> `ndkVersion "27.0.12077973"`。

---

## 3. 运行

```bash
# 真机（相机必须在真机上测，模拟器没有摄像头）
flutter devices
flutter run -d <device-id>

# 或者直接装 release 包
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

分架构瘦身（可选）：
```bash
flutter build apk --release --split-per-abi
# 产物：app-armeabi-v7a-release.apk / app-arm64-v8a-release.apk / app-x86_64-release.apk
```

### 3.1 release 编译报 `integration_test does not exist` 怎么办

`dev_dependencies` 里的 `integration_test` 会被写进
`android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`，
但 release 的 Java 编译路径上没有它的源码，于是：

```
error: package dev.flutter.plugins.integration_test does not exist
```

直接用它打 release，别手动改 pubspec：

```bash
tool/build_release.sh              # 三种 ABI
tool/build_release.sh --target-platform android-arm64
```

脚本会在构建期临时摘掉 `integration_test`，结束（无论成败）自动恢复 `pubspec.yaml`。

---

## 4. 权限说明

`AndroidManifest.xml` 里已声明：

| 权限 | 用途 |
|---|---|
| `CAMERA` | 内置相机拍照 |
| `INTERNET` / `ACCESS_NETWORK_STATE` | 仅用于调用你自建的 AI 接口 |
| `WRITE_EXTERNAL_STORAGE` (maxSdk 28) | 旧系统导出 PNG 到相册 |
| `READ_EXTERNAL_STORAGE` (maxSdk 32) | 旧系统选择图片/备份文件 |
| `READ_MEDIA_IMAGES` | Android 13+ 选择图片 |

首次拍照会弹相机授权；首次导出报表会弹相册授权。
**照片存 App 私有目录，不需要任何存储权限。**

---

## 5. 首次启动会看到什么

1. 空记录列表 + 底部 4 个标签（记录 / AI 助手 / 报表 / 设置）
2. 「设置 → 选项管理」里已有默认码数 `S M L XL XXL` 和 10 个常用颜色
3. 「设置 → AI 接口配置」是空的，填完才能用 AI

建议第一次这样走：
```
录入 2~3 条记录（带照片）
→ 设置里配好 AI 接口并「测试连接」
→ AI 页问「本周一共多少件」
→ 报表页选「对外版」→ 导出 PNG
→ 设置页做一次备份
```

---

## 6. 常见问题

### Q1. `Error: Couldn't resolve the package 'isar_community'`
没执行 `flutter pub get`，或网络问题。国内可配镜像：
```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### Q2. 编译报 `Target of URI hasn't been generated: 'piece_record.g.dart'`
没跑代码生成。执行：
```bash
dart run build_runner build --delete-conflicting-outputs
```
如果报 analyzer 版本冲突，删掉 `pubspec.lock` 重来，或把
`isar_community_generator` 固定为 `3.4.1`。

### Q3. `Namespace not specified` （AGP 8）
本项目用的是 `isar_community_flutter_libs`（自带 namespace），正常不会出现。
若你换回了官方 `isar_flutter_libs`，在 `android/build.gradle` 末尾加：
```gradle
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                if (namespace == null) namespace project.group
            }
        }
    }
}
```

### Q4. 相机预览黑屏 / 白屏
- 必须在**真机**上测，模拟器没有摄像头；
- 切到后台再回来会重新初始化（代码里已处理生命周期）；
- 检查是否授予了相机权限：`系统设置 → 应用 → 计件助手 → 权限`。

### Q5. AI 报 `400 / 422`：模型不支持 tools
换一个支持 **function calling** 的模型。国产模型中 `deepseek-chat`、
`qwen-max`、`glm-4` 等支持；部分轻量模型不支持。

### Q6. AI 报 `404`
接口地址要填到 `/v1`（如 `https://api.deepseek.com/v1`），
App 会自动补 `/chat/completions`。如果你填的地址本身已包含
`/chat/completions`，也能识别。

### Q7. 导出 PNG 提示「没有相册写入权限」
去系统设置给本应用开「照片/媒体」权限。Android 13+ 是
「照片和视频 → 允许管理所有照片」或「仅允许所选」。

### Q8. 报表导出后放大有点糊
导出宽度固定 2400px。若你的手机屏很宽，`pixelRatio` 会被夹到 8 倍上限。
可以在 `lib/data/services/report_service.dart` 里把
`targetWidthPx: 2400` 调到 `3200`（注意内存）。

### Q9. 备份文件很大
照片按 1600px / JPEG 85 压缩，一张约 200~400KB。
100 条记录大约 20~40MB，属于正常。可以在
`lib/data/services/photo_service.dart` 的 `maxSide` 调小（如 1280）。

### Q10. 恢复备份后列表没刷新
恢复逻辑会 `invalidate` 所有 Provider；如果界面没动，下拉一下或切个标签页。
（数据库写入是事务性的，恢复完成后数据一定已经在库里。）

---

## 7. 性能参考

| 场景 | 数据量 | 表现 |
|---|---|---|
| 列表滚动 | 1000 条 | 流畅（缩略图 `cacheWidth` 已限制） |
| 筛选/排序 | 5000 条 | < 10ms（内存过滤） |
| 报表渲染 | 500 条 | 约 0.6s 首次布局 |
| 导出 PNG | 500 条 | 约 1~2s（2400px 宽） |
| 备份 | 100 条 + 100 图 | 约 3~6s |

超过 2000 条建议用时间范围先筛一遍再导报表。

### 3.2 真机集成测试：**必须用 .dev 包**，否则会清掉用户数据

`flutter test integration_test/... -d <device>` 装的是 debug 包（versionCode=1），
遇到已装的 release（`--split-per-abi` 的 versionCode=2001）会触发
`INSTALL_FAILED_VERSION_DOWNGRADE` → flutter 自动 **卸载** 再装 → App 私有目录
（记录 / 照片 / 自动备份）全没，而且测试结束时还会再卸载一次。

安全做法：临时把 `android/app/build.gradle.kts` 的 `applicationId` 改成
`com.example.piecework.dev`，跑完再改回来。这样测试装的是另一个包，
真实数据一个字节都不会动：

```bash
sed -i 's/applicationId = "com.example.piecework"/applicationId = "com.example.piecework.dev"/' \
  android/app/build.gradle.kts
flutter test integration_test/provider_switch_test.dart -d <device>
# 改回真实包名，再打 release
git checkout android/app/build.gradle.kts   # 或用备份还原
tool/build_release.sh
```

另外：release 包（versionCode 2001）**覆盖安装**（`adb install -r`）是保留数据的，
已实测验证；危险的是「卸载」和「降级安装」。
