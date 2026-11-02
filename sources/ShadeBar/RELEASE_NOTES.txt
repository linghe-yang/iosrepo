ShadeBar / 遮挡条 0.3.0~beta1

目标设备：iPad mini 6 / iPadOS 16.1 / Dopamine Rootless。
本版包含显示链路修复候选、逐应用保存、百分比滑块、自由拖动与居中重置。
本地编译和检查已通过；此版本的真实设备显示、触摸和旋转仍需验证。

安装与使用
1. 安装新版 DEB 后重新加载 SpringBoard，打开桌面 ShadeBar App。
2. 等待约 5 秒，显示“等待启用”后打开“启用遮挡层”。每次重载 SpringBoard 后需手动启用。
   正常切换、退出、重开目标应用无需重新调整；每个应用的配置会保存在磁盘上。
3. 首次可关闭“仅在指定应用显示”，回到主屏幕检查。设置 App 内和锁屏时隐藏遮挡条。
4. 开启“仅在指定应用显示”后，在“选择显示应用”里勾选目标 App。空名单不显示。
5. 进入“设置各应用的遮挡条”，选择应用，为它单独设置宽度、高度、颜色和不透明度。
   应用列表支持搜索，缺少的应用可手动添加包标识；“主屏幕”也有自己的配置。
6. 宽高均使用 1–120% 滑动条，按当前方向下的屏幕宽和高计算，保持矩形直角形状。
   例如宽 100%、高 20%：横跨整个屏幕，高度等于当前屏幕高度的五分之一。
   旋转后保持比例，按旋转后的屏幕尺寸重新计算像素宽高；120% 超出的部分自然位于屏幕外。
7. 单指拖动矩形条即可移动。没有屏幕上的缩放手柄、锁定按钮或捏合缩放。
   位置不限制在屏幕内，允许完全拖出屏幕。条外触摸穿透，条内触摸用于拖动。
8. 若拖出屏幕后找不到，回到该应用的配置页，点“重置位置到屏幕正中央”。
   重置使矩形中心与屏幕中心重合，同时恢复横竖屏居中，保留宽高、颜色和不透明度。

逐应用保存规则
每个应用按包标识独立保存：宽度比例、高度比例、颜色、不透明度，以及横竖屏各自的中心位置。
同一应用的横竖屏共用宽高比例、颜色和不透明度，位置分别保存。
横屏左/右方向共用一套横屏位置；竖屏正/反方向共用一套竖屏位置。
新应用默认宽 80%、高 20%、黑色、不透明度 100%，居中显示。
修改 A 应用不会改变 B 应用；重置 A 的位置也不会修改 B 或 A 的尺寸、颜色。
旋转或切换应用时取消尚未完成的拖动，避免把一次拖动写进错误方向或另一个应用。
升级保留共享配置和名单；旧版全局位置/尺寸不直接套入新逐应用配置。

如果仍不显示
返回 App 查看显示状态，或点“重新启动遮挡层”。
状态可区分总开关关闭、锁屏、无法识别前台应用、应用未勾选、透明度为零、条在屏幕外等情况。
“窗口已请求显示”只表示程序已设置窗口可见，不代表屏幕已实际绘制成功。
请打开目标 App 停留几秒，再回 ShadeBar 从右上角“诊断”导出 ShadeBar-diagnostics.json。
导出仅包含本插件状态、当前/最近前台应用的包标识、名单匹配和数量、方向、窗口位置及自身错误。
不包含完整名单、全部逐应用配置、原始 SpringBoard 崩溃日志或其他应用数据。
最近目标记录在重新加载 SpringBoard 时清空。

显示链路调查与修改
用户确认 0.2.0 能安装并打开 App，但关闭名单后也完全不显示；不能只归因于名单。
现有反馈不足以唯一确定设备端根因，本版针对发现的显示和配置传递缺口进行了修正：
- 优先关联主屏幕 UIWindowScene，使用默认 UIKit 窗口托管；移除旧未托管窗口的私有覆盖方法。
- App、启动组件和遮挡层共用 /var/mobile/Library/ShadeBar/settings.plist。
  使用进程间文件锁、按字段合并和原子替换；不同应用以及宽高/位置的并发更新互不覆盖。
  旧 CFPreferences 仅在共享文件不存在时尝试迁移，避免不同进程缓存/容器差异影响后续读取。
- 从 SpringBoard.activeInterfaceOrientation 获取界面方向，不可用时读取窗口场景方向。
  用固定屏幕坐标转换到窗口，避免窗口场景已经旋转后重复旋转。未使用设备物理朝向强制旋转。
- 保留 C 启动组件和手动加载隔离；未恢复曾触发 0.1.0 崩溃的 FBSOrientationObserver setHandler:。

本地 iGameGod 参考
Rootless 包的 iGameGodLoader.plist 链接到可更新的 substrate.plist，App 中存在 preferredBundles。
框架中可见 initWithWindowScene:、setWindowScene:、interfaceOrientation、windowLevel、hitTest:withEvent:。
这些支持应用过滤和场景窗口的实现思路，但静态字符串不足以还原完整执行流程。
本项目没有复制或嵌入 iGameGod 二进制；仍由 SpringBoard 统一显示，以支持主屏幕及名单即时变更。

边界与验证
分屏按系统报告的焦点应用判断，不是所有可见应用的并集；显示/方向刷新周期约 0.2 秒。
未知前台应用时暂时隐藏，避免错误使用其他应用的配置。
强制竖屏应用按界面的竖屏尺寸工作，不随设备的物理朝向强行横屏。
外接显示器、特殊系统界面和所有窗口层级覆盖能力尚未真机验证。
已通过：原生 arm64e ABI 与代码签名页、启动隔离、旧崩溃回调移除、场景创建接口、共享文件路径、
桌面 App/iPad/图标声明、逐应用页面与滑块打包检查，以及 DEB 结构检查。
几何检查包括四个方向的角点/中心/轴映射、100%×20% 旋转尺寸、120% 超屏、完全拖出屏幕、居中重置、
保存中心还原、32 种显示规则和 5 万组随机尺寸/移动/旋转计算。
本地检查不能代替设备上的窗口托管、触摸、配置读写、逐应用切换与方向联调。

源码与构建
src/App.m：主设置页和应用选择；src/ProfileUI.m：逐应用滑块、颜色与位置重置。
src/Bootstrap.c：C 启动组件；src/ShadeBar.m：遮挡层与应用切换。
src/Store.h：共享配置；src/Common.h：逐应用字段；src/Geometry.c：百分比坐标与显示规则。
旧 Preferences 源码仅保留作历史参考，不参与构建。
Linux / WSL x86_64：python3 bootstrap.py；bash build.sh；python3 package.py；python3 tests/verify_release.py。
bootstrap.py 将固定工具和 SDK 放在本项目 tools/；原生 Clang 23 + Apple ld64 956.6，不使用 ABI 转换器。
sources/ShadeBar 含源码、资源、构建配方和校验清单，不包含工具、SDK 或用户原始日志。

发布
新包：debs/com.linghe.shadebar_0.3.0~beta1_iphoneos-arm64.deb。
0.1.0 崩溃版和 0.2.0 不显示版保存在 retired/，不列入活动索引。
推送 iosrepo 的本次完整变更，等待 Pages 部署，随后在 Sileo 刷新并升级。
语言默认英文；系统首选语言为简体中文时使用中文。

接口核对来源
https://github.com/theos/headers/blob/master/SpringBoard/SpringBoard.h
https://github.com/theos/headers/blob/master/SpringBoard/SBLockScreenManager.h
https://github.com/Lessica/AltSpringBoardServices/blob/main/AltSpringBoardServices.mm
