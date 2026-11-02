OverlayIOSTOOL 5.8.12+lang1 本地化组件

适用原包：见 package_manifest.json 的 source_sha256。
作者原包仍标注 Viet Anh；此目录为新增本地化组件及校验资料，不含原 App 的源码。

语言规则
系统首选语言为 zh-Hans（允许地区后缀）或旧式 zh-CN / zh-SG 时使用简体中文。
繁体中文、英文、越南文及其他语言默认使用英文。语言列表为空或读取失败也使用英文。
重新启动 App 和重新加载 SpringBoard 后生效，不支持已运行进程即时切换。
相册权限提示和桌面名称由 iOS 根据 .lproj 资源及系统语言列表选择。

实现
OverlayLocalization.c 为 C 源码，translations.json 为 24 项翻译，translations_generated.h
包括 UTF-16 字符串和四个原始 Mach-O UUID。两个宿主均增加
@loader_path/OverlayIOSTOOLLocalization.dylib 依赖；组件安装在各自旁边。
在 dyld 图像回调中，仅匹配已知 UUID 及指定 UI 常量，保留原类指针。
原 App 和插件的 __TEXT 各段字节未改变；加载命令及签名按新内容更新。
新增组件不连接网络、不全局修改 UIKit，不修改通知名称或配置键。

构建环境
WSL Ubuntu 24.04；clang 18.1.3，ld64.lld 18.1.3；目标 ARM64 iOS 14.0+。
libSystem.tbd、CoreFoundation.tbd 仅提供链接所需声明，运行时使用系统框架。
在本目录使用对应工具链可编译组件：

clang -target arm64-apple-ios14.0 -Os -ffreestanding -fno-builtin -fno-stack-protector -fvisibility=hidden -c OverlayLocalization.c -o OverlayLocalization.o
ld64.lld -dylib -arch arm64 -platform_version ios 14.0 14.5 -install_name @rpath/OverlayIOSTOOLLocalization.dylib -no_fixup_chains -adhoc_codesign -o OverlayIOSTOOLLocalization.dylib OverlayLocalization.o libSystem.tbd CoreFoundation.tbd

组件文件哈希见 component_manifest.json，两个完整 DEB 的哈希及改动清单见 package_manifest.json。
源码与清单供检查使用；原包解包、加载命令注入及重打包工具位于本地
overlayiostool_analysis/localization/ 子项目，未随软件源发布。

验证与限制
verification.json：21 种语言标识、24 组 ARM64 模拟场景、全部 24 项翻译、
未知图像不变、写保护失败时不修改、调用约定、原始脚本/元数据、签名哈希。
实际 dpkg-deb 已成功读取和解包两种 DEB。
模拟使用系统接口替身，不代替真机加载和 UIKit 显示测试。
尚未在真实越狱 iPad 上运行；主程序保留原有 iPhone 设备族、竖屏限制。
