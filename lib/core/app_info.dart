/// 应用版本与仓库信息（单一来源）
///
/// **发布新版本时只改这里**：`tool/build_release.sh` 会读 `kAppVersionCode`
/// 传给 `flutter build --build-number`，保证「App 里显示的版本」和「APK 的
/// versionCode」永远一致 —— 否则自动更新会一直提示「有新版本」或者永远不提示。
library;

/// 版本名（给人看的）
const String kAppVersionName = '1.0.7';

/// 版本号（给机器比的，必须单调递增）
///
/// **这是「基础版本号」**：`--split-per-abi` 打包时 Flutter 会给每个 ABI 加偏移
/// （armeabi-v7a +1000、arm64-v8a +2000、x86_64 +4000），所以手机里实际装上的
/// versionCode 是 4001（arm64）。公告清单里的 versionCode 也用**基础号**比较，
/// 这样无论用户装的是哪个 ABI 都能正确判断「有没有新版本」。
const int kAppVersionCode = 2008;

/// 仓库（公告与更新清单都从这里取）
const String kRepoOwner = 'xxcyou';
const String kRepoName = 'piecework';

/// 公告清单在仓库里的路径
const String kManifestPath = 'announcements/manifest.json';

/// GitHub 加速前缀（用户提供的）
const String kGhProxy = 'https://gh.y4cc.cc/gh/';

/// 项目主页
const String kProjectUrl = 'https://github.com/$kRepoOwner/$kRepoName';

/// 原始清单地址（raw.githubusercontent）
String get kManifestRawUrl =>
    'https://raw.githubusercontent.com/$kRepoOwner/$kRepoName/master/$kManifestPath';

/// 加速后的清单地址
String get kManifestAcceleratedUrl => '$kGhProxy$kManifestRawUrl';

/// 给下载地址套加速（已经是加速地址就不重复套）
String accelerateUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith(kGhProxy)) return url;
  return '$kGhProxy$url';
}
