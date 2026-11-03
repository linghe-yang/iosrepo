原 ARM64 数值及信号处理核心的静态平台适配

来源：用户提供 AndroidTuneLab-3.2.apk 中 arm64-v8a/libfftlib.so。
SHA-256：ef83110e3b105f0a6d17e0a5c90344c5cdda86be5ce9227082b45301f00de17f。

生成器：tunelab_analysis/migration/scripts/port_native_image.py。
OriginalDSP.s 把原只读/执行段和可写数据段转为普通 Mach-O 汇编输入。
原数学与信号处理指令保留，37 个原 JNI 入口全部保留。
修改限于页地址引用、链接器 NOP/ADR 放松对的逆变换，以及 Android TLS 栈保护存储地址。
原代码不使用 Darwin 保留的 X18 寄存器；生成器对此作检查。
代码直接链接在 iOS 的只读执行段，不在 iOS 运行时加载 ELF、修改代码、JIT 或模拟指令。

Platform.cpp 适配 Android/Darwin 边界：
  GOT 数据重定位；固定参数数学/内存函数；
  Android AArch64 va_list 与 Darwin 可变参数差异（%5.3f / %f）；
  Android clock id 到 Darwin clock id；
  直接音频缓冲区 JNI 地址；Android Bitmap 信息及像素缓冲区访问。
这些边界需要继续在实际 iOS 设备验证，不能把编译成功等同于真机运行通过。

check_native_compile.sh 已将该核心静态链接并签名为 ARM64 iOS 16 Mach-O。
validate_relocated_native.py 同时执行原 ELF、重新定位后的指令以及实际链接 Mach-O 内的指令。
11 段保存音频的 H 和 132 项泛音诊断逐字节一致；704 次模型调用结果一致。
测试使用明确的外部函数替身，没有模拟 UIKit 或完整 Darwin 系统库，也尚未验证全部实时状态。

本目录是精准移植的原核心组件；完整应用还需要原页面控制器、音频生命周期和文件/考试状态机。
