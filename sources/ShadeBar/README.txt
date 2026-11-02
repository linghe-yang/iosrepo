ShadeBar / 遮挡条 0.2.0~beta1

本版本针对 iPad mini 6 / iPadOS 16.1 / Dopamine，包含带桌面图标的独立 App。
应用名单、颜色、不透明度、位置、宽高和编辑开关全部在桌面 ShadeBar App 内配置。
不再依赖 PreferenceLoader，也不再安装旧版系统设置面板。

已确认的旧版故障
用户提供的 SpringBoard-2026-11-02-143918.ips 显示：
SpringBoard 在 14:39:16 启动，在 14:39:17 主线程发生 EXC_BAD_ACCESS / SIGBUS。
调用链：ShadeManager init → FBSOrientationObserver setHandler: → objc_msgSend。
这证明旧版的屏幕方向回调注册路径触发崩溃；日志本身不足以单独证明所有底层 ABI 细节。
原始日志包含设备诊断信息，不随软件源发布。

本次修复
1. 移除 setHandler: 方向回调注册，改为在现有刷新周期读取当前界面方向。
2. 改用 Clang 23 + Apple ld64 956.6 直接生成 arm64e 原生二进制；不再使用 allemande 转换。
3. SpringBoard 启动时仅加载一个 C 组件，无 Objective-C 类、常量字符串和 UIKit 依赖。
4. 完整遮挡层放在 App 包内，仅在用户从 App 手动启用时加载；每次重载后默认关闭。
5. 加载前记录状态，未完成的加载会在 App 中提示；不会在下一次重载时自动重复加载。
6. App 可导出自己的启动状态和初始化错误，便于继续定位；不导出完整设备日志或应用名单。

安装与首次检查
1. 在安全模式下卸载旧版 ShadeBar。安装本版本后，重新加载 SpringBoard。
2. 在桌面找到“ShadeBar”图标并打开，先检查 App 能否正常进入。
3. 启动组件会在 SpringBoard 启动后约 5 秒就绪；App 显示“等待启用”后再打开启用开关。
4. 首次可关闭“仅在指定应用显示”，开启编辑模式，然后回到主屏幕观察遮挡条。
5. 拖动遮挡条移动，拖动四边/四角蓝色手柄分别调整宽高，点“锁定”结束编辑。
6. 再次编辑、换颜色、改不透明度或重置位置，都在桌面 App 中操作。
7. 横竖屏的位置与尺寸分别保存，App 中也可按屏幕百分比输入。

应用名单
开启“仅在指定应用显示”后，在“选择应用”勾选允许显示的应用。
名单支持名称/包标识搜索；缺少应用时可点右上角 + 手动添加包标识。
空名单不显示；应用退到后台不保持显示；可单独选中“主屏幕”。
分屏按系统报告的前台/焦点应用判断，不取所有可见应用的并集。
显示与方向刷新周期约 0.2 秒，转场时可能有短暂延迟。锁屏时隐藏。
每次重载 SpringBoard 后，都需要重新打开 App 手动启用遮挡层。

语言
默认英文；系统首选语言为简体中文时使用中文。
更改系统语言后退出并重开 App；遮挡层语言更新需重新加载 SpringBoard 后再次启用。

诊断
App 右上角“诊断”可分享 ShadeBar-diagnostics.json，内容仅限本插件的状态和错误。
如果仍进入安全模式，请先卸载 ShadeBar 并重新加载 SpringBoard，然后提供新崩溃日志：
设置 → 隐私与安全性 → 分析与改进 → 分析数据 → 同一时间的 SpringBoard-*.ips。
图标由安装脚本调用 uicache 注册；若桌面暂未出现，先重新加载 SpringBoard。

本地验证
已通过：原生 arm64e ABI 标记、代码签名页哈希、旧回调不存在、启动组件无 ObjC/UIKit
依赖、遮挡层无自动构造入口、App/iPad/横竖屏及图标声明、安装脚本、DEB 实际解包，
以及 32 种显示规则组合、5 万组移动/尺寸/旋转边界测试。
尚未完成新版真机验证：App 启动、方向读取、跨应用显示、触摸穿透和系统特殊界面。
这些检查不能代替真实 iPad 上的加载和显示测试，不能据此保证所有安全模式问题已消失。

源码和构建
src/App.m：桌面设置 App；src/Bootstrap.c：最小启动组件；src/ShadeBar.m：遮挡层。
src/Geometry.c：几何与显示规则；旧 Preferences 文件仅保留作历史参考，不参与构建。
build.sh 使用原生 arm64e 工具链；package.py 生成 DEB。
工具版本固定在 native-tools.lock.json；编译工具与 SDK 不随 iosrepo 发布。

在 Linux / WSL x86_64 上，需要 Python 3.12+、git、系统 clang/clang++、cc、make、dpkg-deb：
  python3 bootstrap.py
  bash build.sh
  python3 package.py
  python3 tests/verify_release.py

bootstrap.py 将工具放在 tools/ 并在项目内构建 Apple 链接器，不安装系统软件。
make_icons.py 使用 Pillow 根据资源中的几何图案重建 PNG 图标；现成 PNG 已包含在源码中。
build/package_manifest.json、build/release_verification.json 记录本次构建和校验；
iosrepo 的源码副本中，两个清单直接位于 sources/ShadeBar/ 下。

软件源
故障版 0.1.0~beta1 从活动软件源移除，移入 retired/ 留存，不再作为可安装版本推荐。
新包：debs/com.linghe.shadebar_0.2.0~beta1_iphoneos-arm64.deb。
由用户自行推送本地 iosrepo，等待 Pages 部署后在 Sileo 刷新软件源。
