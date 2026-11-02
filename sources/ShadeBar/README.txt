ShadeBar / 遮挡条 0.1.0~beta1

这是全新开发的独立插件。目标测试设备为 iPad mini 6、iPadOS 16.1、Dopamine Rootless。
源码：src/；安装包：packages/；打包清单及哈希：build/package_manifest.json。
它不依赖 OverlayIOSTOOL，也不修改其文件。

使用步骤
1. 安装 Rootless DEB，确保 PreferenceLoader 可用，重新加载 SpringBoard。
2. 打开系统“设置 → ShadeBar”，打开“启用遮挡条”。首次安装默认关闭。
3. 开启“编辑模式”，返回主屏幕或指定应用。拖动遮挡条移动，拖动四边/四角蓝色手柄调整宽高。
4. 点击“锁定”隐藏手柄。再次编辑时返回系统设置打开编辑模式。
5. 颜色选择器、HEX 色值和不透明度在设置页调整。不透明度 0 为透明，1 为完全遮挡。
6. 横屏/竖屏的位置与尺寸分别保存，也可以在设置里按屏幕百分比输入。
7. 可选择“锁定后允许触摸穿透”；关闭后，遮挡条本身会挡住触摸，条外不应影响操作。
8. 如果透明后找不到遮挡条，打开编辑模式即可看到蓝色手柄；也可重置横竖屏位置。

应用名单
“仅在指定应用显示”关闭：所有常规前台界面均可显示，锁屏除外。
打开：只在名单中的应用处于前台时显示；名单为空时不显示。
“选择应用”自动列出应用，也支持手动添加 com.example.app 格式的包标识。
名单中提供“主屏幕”选项。应用退到后台后不再因为它仍在运行而保持显示。
第一版按系统报告的前台/焦点应用判断，不取分屏中所有可见应用的并集。
当前轮询间隔 0.2 秒，切换显示可能有短暂延迟，暂不保证系统转场全过程无残留。
若无法获取前台应用，名单模式按不显示处理；若无法读取锁屏状态，也按不显示处理。

语言
默认英文；系统首选语言为 zh-Hans 或旧标识 zh-CN/zh-SG 时使用简体中文。
更改系统语言后，请退出设置并重新加载 SpringBoard。

开发与构建
Objective-C + C，SpringBoard 单进程注入，原生 Preferences 设置页。
无联网代码、广告或账号要求。设置通过本机 CFPreferences 和 Darwin 通知同步。
浮层采用固定屏幕坐标、FrontBoard 屏幕方向观察器和手动坐标变换。
仅在启用时启动前台应用轮询。锁屏隐藏，停用后停止轮询。

当前构建使用 Theos 推荐的 Linux iOS 工具链及 allemande 转换 arm64e ABI。
链接器会提示旧 ABI 警告；build.sh 在链接后运行转换器，再重新签名。
转换是 Theos 文档列出的方案，但其成功不等于已证明真机兼容。
本包只有 arm64e 切片，面向 A12 及更新设备；不是所有 Rootless 设备的通用包。
不依赖系统级 oldabi 插件。

Linux / WSL 构建命令（需要 Python 3.12+、git、g++、cc）：
  python3 bootstrap.py
  bash build.sh
  python3 package.py

bootstrap.py 将编译工具下载到 tools/，固定版本与压缩包 SHA256，不进行系统安装。
请在 WSL/Linux 内运行 bootstrap.py，避免 Windows Git 把 SDK 符号链接变成文本文件。
工具及 SDK 不包含在 iosrepo 源码副本中。

验证记录
已经完成：
- 两个 Objective-C 组件编译、arm64e ABI 转换和 ad-hoc 签名。
- 32 种启用/锁屏/应用名单规则组合，以及前后台切换、未知前台应用等逻辑测试。
- 5 万组移动、尺寸调整、横竖屏尺寸约束测试，启用 AddressSanitizer/UndefinedBehaviorSanitizer。
- 安装包中的二进制架构、所有代码签名页哈希和依赖检查。
- 实际 dpkg-deb 成功读取、列出和解包 DEB；文件路径、权限和控制信息符合 Rootless 布局。

iosrepo 内的源码副本另附 package_manifest.json，记录本次二进制与源码哈希。

尚未完成：
- 真实 iOS 的 dyld 加载、arm64e 指针认证和私有系统接口执行。
- SpringBoard 跨应用置顶、触摸穿透、设置页显示以及旋转手势的真机验证。
- 分屏焦点切换、控制中心、通知中心、系统弹窗及游戏转场测试。

建议的真机测试
先停用旧的 OverlayIOSTOOL 浮层，避免两个浮层互相干扰。
在“设置 → ShadeBar”启用，先用主屏幕测试移动、四边/四角调整、锁定和穿透。
分别旋转到两种横屏及竖屏，再测试设置中的颜色、不透明度和重置。
打开“仅在指定应用显示”，先选一个应用（例如 Safari），在它与未选应用间切换。
测试空名单、添加/移除应用、退出应用、锁屏解锁、重新加载 SpringBoard 后的设置保留。
如出现黑屏/崩溃或安全模式，先移除 ShadeBar 并重新加载 SpringBoard，再提供崩溃日志。

发布
已准备的 DEB 可加入本地 iosrepo/debs/，用 tools/update_repo.py 重建并校验源索引。
以 Beta 名称发布，源中的其他插件可以保留。远端推送由用户自行执行。

技术参考（只参考接口声明和用法，本项目包含独立实现的插件源码）：
https://theos.dev/docs/rootless
https://theos.dev/docs/arm64e-deployment
https://github.com/theos/headers
https://github.com/Lessica/TrollSpeed
https://github.com/kenn2305/ToolOverlayIOS
https://github.com/p0358/allemande
