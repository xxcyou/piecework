# Android 构建补充说明（Isar + AGP 8）

`flutter create .` 生成工程后，请确认 `android/app/build.gradle(.kts)` 中：

```gradle
android {
    namespace "com.example.piecework"     // 必须存在（AGP 8 强制）
    compileSdk 35

    defaultConfig {
        applicationId "com.example.piecework"
        minSdk 24            // camera / gal / isar 均要求 >= 21，取 24 更稳
        targetSdk 35
    }
}
```

若 `android/build.gradle` 出现 “Namespace not specified” 报错（旧版 isar_flutter_libs 的已知问题），
本项目已改用 `isar_community_flutter_libs`（自带 namespace），一般无需处理。
