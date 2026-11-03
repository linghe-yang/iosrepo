TuneLab 3.2 原样移植工程

当前 iOS 移植工程版本：0.2.0~alpha1（系统版本号 0.2.0，构建号 2）。
上个 PianoLab 原型版本：0.1.0~beta1。
原 Android 样本版本仍为 3.2，独立记录，不与 iOS 移植版本混用。
本版本尚未生成 DEB；版本标记不表示完整精准移植已经完成。

用户要求：原软件名、图标、全部页面及菜单、交互和状态变化、软件功能及算法都按 APK 精准移植。
此前 PianoLab 是独立界面/部分独立算法的原型，不满足这个要求。
本目录是重新按原应用建立的移植工程，不把旧原型改名后冒充完成版。

原 APK 的准确身份

桌面名称：Piano Tuner（AndroidManifest.xml → @string/app_name）。
应用内标识：TuneLab / TuneLab Piano Tuner。
版本：3.2。
Android 包名：com.realtimespecialties.tunelab。
原 icon：res/mipmap-xxxhdpi/ic_launcher.png；另保留圆形及 adaptive icon 的原始资源。
桌面名称不能凭 APK 文件名推测为 TuneLab，也不能改成 PianoLab。

已完成的基础工作

1. 提取 42 个 Activity 的标题、主题、布局引用、菜单、页面跳转和公开处理方法。
2. 提取 69 个布局变体、673 个布局节点、13 组菜单和 109 个公开点击/导航方法。
3. 冻结 37 个 JNI 接口清单；不将“有相近功能”计为原接口行为移植完成。
4. 直接复制并逐个校验 847 个资源文件；图片、字符串和菜单没有重画、改写或自动翻译。
5. resources/Icon.png 与原 APK 的高密度 launcher 图标逐字节相同。
6. resources/Info.plist 按原桌面名称和原图标声明；该文件是工程资源准备，不是已发布应用。
7. src/TLOriginalLayout.m 已实现读取原布局树的 UIKit 适配骨架，以及原 PhaseDisplayV 单相位绘制几何。
   它尚未复刻所有 Android Holo 控件外观、字体、动态监听器和所有资源限定符的行为。
8. 已在校验过的官方 Android 35 参考环境实际运行未改动 APK，保存原截图和 UIAutomator 控件树。
   41 次非主页启动中 39 页停留成功；Spectrum Update Rate 在原初始化状态稳定后补抓成功。
   加上 Main，目前有 41 个不同页面的运行参考；DBXfer 在没有原 Dropbox 客户端状态时自行退出，仍缺认证状态参考。
   另保存原文件/帮助菜单，以及手机横屏、大屏横竖屏；大屏竖屏为 744dp×1133dp。
9. 保存参考系统实际 Roboto 字体和对应声明；字体登记已加入工程资源，字形/行距仍需 iOS 排版对照。

当前状态

尚未完成全部页面的原样 UI 与动态交互。
尚未用原 Android 运行画面和 iOS 实机画面逐页做像素/状态对照。
原实时解调、自动换音、自动泛音、锁定和多泛音状态机尚未全部移植。
尚未生成满足本要求的新 DEB；之前的 PianoLab 包仍只属于实验原型。
verification/original_assets.json 中的 assets 校验通过，只证明原始资源相同，不能解释为全部移植完成。

验收规则

每页必须固定设备尺寸/密度、横竖屏、主题、字体缩放、数据及操作序列。
对照标题、字体、颜色、间距、图片和按下态、菜单顺序、可见/隐藏/禁用状态。
原始布局中的 invisible 与 gone 必须区别；前者保留空间，后者参与重新排版。
逐项移植手势、长按、对话框、键盘、返回路径、保存提示和中断/恢复行为。
不能用系统设置列表或中文重写菜单代替原页面，并计作精准 UI。
算法按同输入比较原中间状态和最终输出；已通过的冻结样本不是所有功能已经等价的证明。
自编实时音高、频差驱动动画和泛音中位值合并不能代替原解调、锁定与多泛音算法的移植。
Android 与 iOS 的系统权限、系统状态栏、输入法、桌面图标圆角等由各自系统管理，单列平台差异。

目录

resources/Original/identity.json：名称、icon 引用及身份要求。
resources/Original/activities.json：全部 42 个 Activity 和原源代码哈希。
resources/Original/layouts.json：原布局的完整树，包含横竖屏与大屏变体。
resources/Original/controls.json：逐控件属性、文字和 onClick。
resources/Original/menus.json：完整原菜单树。
resources/Original/settings_items.json：原 Settings.h 顺序和分隔项。
resources/Original/callbacks.json：需要实现/验证的原监听方法清单。
resources/Original/native_api.json：原 JNI 接口清单。
resources/Original/apk/：原 res、帮助、预置文件及 Manifest。
verification/：资源一致性与工程当前状态，不表示全功能验收通过。
reference/android35-phone/：原 APK 的真实运行截图、控件像素边界和启动记录。
verification/algorithm_gaps.json：前期独立实现与原算法的具体差异及待移植模块。

复现

先在原分析工作区运行 migration/scripts/extract_original_spec.py。
再运行本目录 prepare_original_resources.py；这个步骤复制原资源并检查哈希。
bash check_ui_compile.sh 只检查布局适配源码能否编译为 ARM64 iOS 16 对象文件。
运行截图、控件外观和功能验收需要另外完成。

此前的原算法对照资料仍在 tunelab_analysis/migration；C++ 数值原型在 sources/PianoLab。
可复用已验证的数值代码，但每个入口都要核对完整原语义，不能直接按函数名认定已等价。
