# 源码、图标和成品差异

先复制整个 `counter_demo` 到自己的工作目录。进到能看见 `pubspec.yaml` 的那一级再开终端。此份练习工程面向 iOS，`lib/main.dart`、依赖清单与计数测试取自本课实录；起步外观和通用 Xcode 配置取自本课起步归档。签名时选择自己的 Team、唯一的 Bundle Identifier。

```sh
flutter pub get
flutter test
open ios/Runner.xcworkspace
flutter devices
```

第一次运行跟提示词 05–07 完成配对及签名。要从主屏独立打开，在同一工程目录输入下列命令，把引号中的示例文字改为上一步查到的真机 ID。

```sh
flutter run --release -d "你的真机ID"
```

## 对照实录成品

- `成品对照/ios/Runner/Info.plist` 保留实录的显示名字段。对照 `CFBundleDisplayName`，把自己副本中该字段设为「随手数」。如果已经有自己的项目设置，只改这一项。
- `成品对照/ios/Runner/Assets.xcassets/AppIcon.appiconset/` 是实录的成套头像图标。在随包起步工程的副本中，可以替换同名图标集，再重新构建。已有工程先保留自己的图标备份。
- `图标/随手数-iOS图标-1024.png` 是第 09 条默认使用的紫色练习图。`图标/随手数-实录卡通图标.png` 是讲师头像，也可改用自己的方形 PNG。选择哪张取决于你实际要做的 App。
- SDK 在自己的工具目录，App 在 `counter_demo`。签发给教师账号的配置、证书、描述文件、设备记录和已签名安装包不属于学员工程；真机运行时让 Xcode 生成你自己的配置。

[安装入口](安装与官方入口.md) · [实测记录](实测记录.md)
