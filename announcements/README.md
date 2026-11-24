# 公告 / 更新清单

App 启动时会拉取：

```
https://gh.y4cc.cc/gh/https://raw.githubusercontent.com/xxcyou/piecework/master/announcements/manifest.json
（失败自动回退到原始 raw 地址）
```

## 1. 发新版（更新公告）

1. 改 `lib/core/app_info.dart` 里的 `kAppVersionCode`（必须比上次大）和 `kAppVersionName`
2. `bash tool/build_release.sh`（脚本会把版本号传给 APK，保证一致）
3. 到 GitHub Releases 建 tag（例如 `v1.0.1`），上传 `app-arm64-v8a-release.apk`，重命名为 `piecework-release.apk`
4. 改本文件同目录的 `manifest.json`：

```json
"latest": {
  "versionCode": 2002,
  "versionName": "1.0.1",
  "apkUrl": "https://github.com/xxcyou/piecework/releases/latest/download/piecework-release.apk",
  "notes": "新增多身份卡、WebDAV 云备份",
  "force": false
}
```

5. 提交 `manifest.json` → 老用户下次打开 App 就会收到「发现新版本」弹窗，
   点「立即更新」走加速通道下载安装（覆盖安装，数据不丢）。

> `force: true` = 不能「稍后」，只能更新（严重问题才用）。

## 2. 发公关公告（平时没有）

```json
"publicNotice": {
  "id": "2026-11-24-01",
  "level": "critical",
  "title": "关于计件单价的计算口径更正",
  "body": "如果你在 11-20 之前用过分组汇总，请重新核对……",
  "active": true,
  "expiresAt": "2026-12-31"
}
```

- `id` 换了才会再弹一次（同一条不会反复骚扰）
- `level`：`info` / `warning` / `critical`（颜色不同）
- `active: false` 或过了 `expiresAt` 就不弹
- 平时保持 `null`

## 3. 停运

```json
"operating": false,
"operatingMessage": "系统维护中，预计今晚 22:00 恢复"
```

打开 App 直接显示停服页（只有「重试」），不进入功能。
恢复时改回 `true` 即可。

## 4. 离线兜底

App 会缓存上一次成功拉到的清单：

- 断网 / 清单地址挂了 → 沿用缓存（不会把用户挡在外面）
- 从来没拉成功过 → 当作「一切正常」
