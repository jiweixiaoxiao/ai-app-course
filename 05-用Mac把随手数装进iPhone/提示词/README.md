# 豆包分步提示词｜Mac 与 iPhone

在豆包电脑版的同一个「工作」项目里，一次只发送当前步骤。复制边界之间的正文，检查结果和下一步留给自己。

第 04 步分 A、B、C 三选一；09 是选做。重装和排错两段在遇到对应情况时使用。

[下载 TXT](分步提示词.txt) · [返回第五课](../README.md)

## 01 先看这台 Mac 有什么

已在豆包选好本课的工作目录。

```text
我想在这台 Mac 上用 Flutter 把计数器装到自己的 iPhone。请先只检查，分行列出 Mac 的芯片与系统、Flutter SDK、完整 Xcode、当前命令行工具路径、iPhoneOS SDK。Git 随 Xcode 一起验证；如果还没装好 Xcode，请将 Git 标为「第 02 条验证」，此时跳过 Git 命令。给每项写上实际版本或位置，注明可用、缺少或要配置。把接下来要做的第一件事告诉我。
```

检查结果。知道哪些可以跳过，哪些需要安装。若提示安装工具，先回到清单对照。

下一步。先发送 02。

## 02 装好 Xcode 并确认 iOS 工具

01 已列出 Xcode 的安装状态。若已手装，附一句“我已经安装，请只核验”。

```text
只帮我处理 Xcode。在 Apple 的 Xcode 系统要求页核对当前 macOS 和我手机的 iOS，选择两端都支持的版本。下载前指出 App Store 标注的大小，提醒我本体安装、组件下载各需等待。已装完整 Xcode 就沿用。首次打开若出现平台选择，请指出 iOS 行和安装按钮；若只显示可选 Simulator Runtime，解释它装在 Mac 上，做真机练习可先继续。没弹窗就带我到 Xcode → Settings → Components 查看 Platform Support 的 iOS，缺少时点 Get，已有就继续；需要等进度完成。需要登录、同意条款、输入密码时让我在系统窗口操作。Xcode 自带 Git，完成首次设置后直接验证即可。检查 xcode-select -p、xcodebuild -version、xcrun --sdk iphoneos --show-sdk-version、git --version。只有当前工具路径选错时才告诉我怎样切到刚装的 Xcode。
```

检查结果。有 Xcode 版本、iPhoneOS SDK 版本和 Git 版本。仅有 CommandLineTools 路径时，继续选完整 Xcode。

下一步。四项检查完成后发 03。

## 03 让新终端找到 Flutter

Xcode、Git 和 iPhoneOS SDK 已经就绪。

```text
检查已有 Flutter。缺少时帮我从 Flutter 官网选适合这台 Mac 芯片的稳定版，解压到我能写入的目录，用实际 SDK 路径把 bin 加入我使用的 shell 的 PATH，避免重复添加。请让我新开终端验证 flutter --version，再用 flutter doctor -v 解释与 iOS 构建有关的输出。如果有提示，请区分阻止这次真机构建的问题和其他平台提示。工程确实依赖 CocoaPods 时再按提示补齐。 如果我已有从官方归档取得的匹配本机芯片的 SDK ZIP，请先用它安装并验证版本。
```

检查结果。新开终端也能读出 Flutter 版本，Xcode 和 iOS 工具可用。

下一步。04A／B／C 只选一种。

## 04A 用上节课的工程副本

你已经留存了上节课的 Flutter 源工程。

```text
我把自己的 counter_demo 项目副本放到 Mac 上了。请找到同时含 pubspec.yaml 和 lib/main.dart 的项目根目录。保留计数代码、资源及已有平台设置。检查 ios/Runner.xcworkspace，如果没有 iOS 工程，先在副本中用 Flutter 补 iOS 平台，告诉我改动了哪些文件，检查已有 Dart 和 Android 文件。回到项目根目录运行 flutter pub get，打开 iOS workspace。
```

检查结果。能在 Xcode 左侧找到 Runner 工程。使用第四课资料的同学可以选 B 或 C；A 指自己另存的源码。

下一步。看到 Runner 后发 05。

## 04B 从默认计数器开始

你从本课开始，想按视频现场生成。

```text
请在我选中的工作文件夹下，用 flutter create counter_demo 生成 Flutter 默认计数器。若已有同名目录先检查内容，有项目就沿用，其他情况先用一个空目录。进入含 pubspec.yaml 的根目录，运行 flutter pub get，确认有 lib/main.dart 和 ios/Runner.xcworkspace，然后打开这个 workspace。
```

检查结果。能在 Xcode 左侧找到 Runner 工程。使用第四课资料的同学可以选 B 或 C；A 指自己另存的源码。

下一步。看到 Runner 后发 05。

## 04C 用包内起步工程

把资料里的 counter_demo 文件夹复制到自己的练习目录。

```text
我已把标准资料包「03-源代码与图标」里的 counter_demo 起步工程复制到练习目录。请定位含 pubspec.yaml 的 counter_demo，核对本机 Flutter 是否满足 pubspec.yaml 的 SDK 约束。在这个目录运行 flutter pub get，打开 ios/Runner.xcworkspace。如果 SDK 偏旧，请解释兼容选择，保留这份源码。
```

检查结果。能在 Xcode 左侧找到 Runner 工程。使用第四课资料的同学可以选 B 或 C；A 指自己另存的源码。

下一步。看到 Runner 后发 05。

## 05 让 Mac 认出手里的 iPhone

工程已打开，手机已解锁并接线。

```text
我用能传数据的线把已解锁的 iPhone 接到 Mac 了。请带我完成信任这台电脑、在 Xcode 发起配对、在 iPhone 的「设置 → 隐私与安全性 → 开发者模式」开启并重启确认，再回到 Xcode 看设备就绪。运行 flutter devices，指出物理 iPhone 对应的那一行。若同时出现模拟器或另一台手机，请等我确认目标。
```

检查结果。手机重启后已解锁并确认，目标 iPhone 在设备列表中可选。开发者模式本来已打开的直接核对状态。

下一步。确认物理 iPhone 后发 06。

## 06 给这个练习 App 签名

已确认手里的 iPhone 是目标设备。

```text
请带我给当前工程配置 iPhone 真机签名。我用免费个人团队装到自己的 iPhone。请带我打开 Xcode → Settings → Apple Accounts，我自己登录平时在 App Store 下 App 的苹果账号。接着在 Runner target 的 Signing & Capabilities 勾选 Automatically manage signing，从 Team 下拉框选自己名字后面标有 Personal Team 的一项。在 Bundle Identifier 填我自己的唯一标识，保留项目的计数逻辑。如果之前已用自己的 Personal Team 给这份练习工程签过名，沿用该团队和原来的 Bundle Identifier。请指出 Xcode 顶部在哪里选择刚才的真机，如有红字，按这一次的原文排查。
```

检查结果。运行目标是自己的物理 iPhone，Runner 的签名信息就绪，Bundle Identifier 与手机桌面显示名各有自己的字段。

下一步。签名错误先看图文手册第 06–07 节，状态就绪再发 07。

## 07 在真机上运行

Runner 已选原团队和唯一编号。

```text
在含 pubspec.yaml 的目录，使用 flutter devices 刚刚查到的这部物理 iPhone 的实际 ID，执行 flutter run -d 加该 ID。请等到 App 打开再报告结果。如有设备信任或调试授权提示，告诉我在哪一端处理。保留终端的首条具体报错供排查。
```

检查结果。看手里的 iPhone，数字从 0 开始，自己点两次加号，依次看到 1 和 2。

下一步。真机能从 0 点到 2 后发 08。

## 08 改桌面上的名字

计数功能已验证，准备改主屏显示名。

```text
请只把 iOS 桌面显示名改为「随手数」，告诉我你改的是哪个字段。保留页面标题、Bundle Identifier 和计数逻辑。等我决定要不要换图标，再一起重新构建。
```

检查结果。Runner 使用的 Display Name 或 Info.plist 的 CFBundleDisplayName 是「随手数」。重装后再看手机主屏幕。

下一步。想换图标就选 09，否则去 10。

## 09 换图标（选做）

准备好 1024 像素 PNG，发送时附上图片。

```text
附件是「随手数-iOS图标-1024.png」。请检查当前 Runner 使用的 AppIcon 资源集，按它的规格生成需要的尺寸，替换练习工程里的 iOS 主屏幕图标。保留显示名、Bundle Identifier 和计数逻辑。
```

检查结果。Xcode 的 Assets 里能看到自己的图标。跳过这条也可以做第 10 条。

下一步。重新安装核对主屏，再发 10。

## 10 从主屏幕独立打开

希望结束电脑上的调试后仍能从手机打开。

```text
沿用刚才签名成功的 Runner 和同一部物理 iPhone。请结束前一次调试运行，在项目根目录执行 flutter run --release -d 加刚才确认的真实设备 ID，用现有开发签名重装。等安装完成，我要断开数据线，结束手机上正在运行的 App，再从主屏幕打开「随手数」。
```

检查结果。主屏幕看到新名字（换过图标也核对图案）。从图标打开，看到 0，点两次看到 2。

下一步。拔线、划掉、从主屏重开后点两次加号。

## 重装 七天到期后重装

上次的免费测试安装到期，原工程仍在。

```text
我的「随手数」用免费 Personal Team 签发，七天有效期已过。我已在「工作」里选中上次的工程，也把原来的 iPhone 接回 Mac 并解锁了。请确认工程根目录里有 pubspec.yaml，Runner 使用自动签名、原来的 Personal Team 和原来的 Bundle Identifier。用 flutter devices 找出我的物理 iPhone，在项目根目录把这部手机的实际 ID 传给 flutter run --release -d，重新构建、签名并装回手机。若需要重新登录，我来输入账号和验证码。等安装完成再提醒我拔线验证。
```

检查结果。拔线，结束正在运行的 App，从 iPhone 主屏重新打开「随手数」，亲手从 0 点到 2。

下一步。按第 10 条的主屏方式验收。

## 排错 报错时单独发

某一步的实际结果与手册不同。

```text
我卡在第 __ 条。设备与系统是 __；上一项已看到 __；这次的首条具体错误是 __。请判断问题在 Mac 工具、手机配对、工程签名还是安装运行，只给我一个能验证原因的下一步，告诉我正常时会看到什么。我会隐去账号、设备 ID 和个人路径。
```

检查结果。已留下第一条原文、所处步骤及上一步结果。

下一步。核对一个原因，再回原步骤复测。
