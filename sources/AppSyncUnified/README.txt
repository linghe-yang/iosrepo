AppSync Unified 116.0 — 官方原版 Rootless 镜像

上游项目：https://github.com/akemin-dayo/AppSync
上游发布：https://github.com/akemin-dayo/AppSync/releases/tag/116.0
对应提交：235aca6cddfbdc9fa87fcb5b2aec2df37ed6d65a
获取日期：2026-11-02
授权：GPL-3.0-or-later
原作者：Karen/あけみ、Linus Yang；以 LICENSE 中的原始声明为准。

安装包：
../../debs/ai.akemi.appsyncunified_116.0_iphoneos-arm64.akemi-git-235aca6cddfbdc9fa87fcb5b2aec2df37ed6d65a.deb
大小：49,472 字节
SHA-256：2bdaac72a6d1b006309b7dd28f51b1e3d351d3d8758fc9f08ca670f1d71eb382

此文件从作者 GitHub Release 下载后逐字节保留，未修改控制信息、
二进制、签名、安装或卸载脚本。个人镜像不等于作者官方软件源。
包架构为 iphoneos-arm64，用于普通版 Dopamine 等兼容 Rootless 环境。
未将它改造成 Rootful 或 RootHide 包，也未运行包内安装脚本。

运行条件：
- 设备已越狱并开启插件注入。
- 原包 Depends：firmware (>= 5.0), mobilesubstrate (>= 0.9.5100), firmware (<= 18.2)。
- Rootless 环境需要 ElleKit >= 1.1；原包排除了 ellekit (< 1.1)。
- 依赖由设备已有越狱基础源提供，本目录不是全部依赖的离线集合。
- 对 iPad mini 6 / iPadOS 16.1 / 普通版 Dopamine，包架构与 Rootless 路径匹配；
  尚未进行该设备的真实安装运行验证。
- 原包 Homepage / Depiction 仍指向当前无法正常访问的 cydia.akemi.ai。
  APT 索引中的 Filename 指向本源 debs/，下载 DEB 不依赖该详情页。

配套文件：
- AppSync-235aca6cddfbdc9fa87fcb5b2aec2df37ed6d65a.tar.gz：对应提交的完整上游源码归档。
- LICENSE：从源码归档原样复制的版权和授权声明。
- COPYING：GPLv3 全文，取自 SPDX 官方许可证清单；来源记录在 provenance.json。
- UPSTREAM_README.txt：从该提交原样复制的上游 README。
- control.txt：从实际 DEB 读取的控制信息，仅供审阅。
- provenance.json：下载地址、文件大小、SHA-256、包载荷及本地检查记录。

源码与安装包一起通过同一软件源提供下载。上传 GitHub 时请完整保留本目录，
并在软件源首页保留源码和许可证入口，以便下载二进制的用户取得对应源码。
源码提交依据作者发布文件名中的提交号确定；本次没有从源码重新构建或声明
可复现出相同二进制。

构建参考：
源码归档包含上游 README、所有子项目 Makefile、安装/卸载代码及打包布局。
需要自行准备 Theos、兼容 Apple 工具链和 iOS SDK；这些构建环境未随源码镜像。
上游通用构建说明为 make / make package。Rootless 构建还需设置
THEOS_PACKAGE_SCHEME=rootless，并使用与目标兼容的 arm64 / arm64e 架构、
SDK 和工具链。Theos 文档：https://theos.dev/docs/rootless
这些是构建参考，不是本次已验证的可复现构建命令。

检查结果：
已读取 DEB 的 ar、control.tar.gz 与 data.tar.lzma；载荷文件均位于 /var/jb。
官方原始下载与发布目录中的 DEB 逐字节一致。索引通过仓库自带
tools/update_repo.py 和 --check 生成并检查；真实设备运行仍需自行验证。
