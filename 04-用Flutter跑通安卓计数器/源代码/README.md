# Flutter 计数器的生成入口与素材

## 生成自己的计数器

先按手册配好环境，并让 `flutter devices` 识别手机。在自己建的练习目录里，发送提示词第 07 条，由豆包执行这些操作。

```powershell
flutter create counter_demo
cd counter_demo
flutter devices
flutter run -d "<换成你自己的安卓设备 ID>"
```

如果当前目录已有 `counter_demo`，进入已有项目继续。页面来自 Flutter 默认模板，代码入口是生成后的 `lib/main.dart`。课堂录制的完整工程未随素材归档。用本机工具生成自己的项目，继续按 08 和 09 改名或换图标。

## 随手数图标

[随手数 App 图标 PNG](assets/随手数-App图标原图.png)可作为第 09 条的附件。请豆包改 Android 启动图标，保持应用 ID、显示名和计数功能。

## 片尾的环境脚本

[Flutter全环境一键安装脚本.ps1](Flutter全环境一键安装脚本.ps1)是归档 v1.5 原件，以观众提示词引用的文件名提供。要执行前先让豆包通读并报告将下载的工具、读取或修改的目录、用户环境以及许可。由本人确认。已有开发项目或 SDK 时，优先复用可用工具，再按 [脚本使用说明](脚本使用说明.md)判断是否适用。
