# sangeeeee iOS Repo

用于 Sileo、Zebra 等越狱包管理器的个人软件源，采用平面 APT 目录结构。

启用 GitHub Pages 后，软件源地址为：

```text
https://linghe-yang.github.io/iosrepo/
```

## 首次启用

在本仓库的 **Settings → Pages** 中，选择 **Deploy from a branch → main → /(root)**，然后保存。

等待部署完成，确认以下链接可访问，再在设备的包管理器中添加上面的源地址：

- [Release](https://linghe-yang.github.io/iosrepo/Release)
- [Packages](https://linghe-yang.github.io/iosrepo/Packages)

## 当前软件包

| 包标识 | 越狱环境 | 版本 |
| --- | --- | --- |
| `com.gamegod.igg` | 传统越狱，`iphoneos-arm` | `0.8.9.5+noads1` |
| `com.gamegod.igg.rootless` | Rootless，`iphoneos-arm64` | `0.8.9.5+noads1` |
| `com.gamegod.igg.roothide` | Roothide，`iphoneos-arm64e` | `0.8.9.5+noads1` |
| `com.vietanh.overlayiostool` | 传统越狱，`iphoneos-arm` | `5.8.12` |
| `com.vietanh.overlayiostool` | Rootless，`iphoneos-arm64` | `5.8.12` |

上述 iGameGod 包基于官方 0.8.9.5 制作，是本地去广告测试包，并非官方发布。原作者信息和软件包依赖保留在 DEB 中。

修改针对共享框架中的横幅、插屏、定时及闲置广告路径，保留完成回调以继续后续功能。已完成包结构、代码页哈希及局部 ARM64 控制流程模拟检查；尚未完成真实越狱设备运行验证，因此保留 **No Ads TEST** 标记。应按实际越狱环境选择包，不能只按 CPU 类型选择。

OverlayIOSTOOL 来自本地提供的两个 5.8.12 DEB，作者标注为 Viet Anh。对包内全部可执行文件、资源和通信路径做了静态检查，未发现广告组件，因此保留全部应用及插件内容。原普通版将包架构误标为 `iphoneos-arm64`；本源仅将其改为传统越狱使用的 `iphoneos-arm`，使两种环境可以区分。Rootless DEB 与提供的原文件逐字节一致。

对于 **iPad mini 6 / iPadOS 16.1 / Dopamine**，应选择 Rootless 版：ARM64、系统依赖范围和 `/var/jb` 加载路径符合该环境。App 仅声明 iPhone 设备族并限制竖屏，预计通过 iPhone 兼容模式运行；尚未真机验证，不能视为原生 iPad、横屏或分屏适配。

安装 Rootless 版后，重新加载 SpringBoard 并打开 Overlay Tool，选择图片测试悬浮显示、拖动和缩放。只有在设备启用越狱及插件注入后，跨应用浮层才有相应运行环境。

## 更新软件源

当前 OverlayIOSTOOL DEB 使用 Zstandard 压缩，需要 Python 3.14 或更新版本来读取并更新索引，不依赖额外 Python 包。

1. 将新增或更新的 DEB 放入 `debs/`。
2. 更新包时递增 DEB 内部的 `Version`，例如从 `0.8.9.5+noads1` 更新到 `0.8.9.5+noads2`；只改文件名不会改变包版本。
3. 在仓库目录执行：

```powershell
python tools/update_repo.py
python tools/update_repo.py --check
git add .
git commit -m "Update packages and repository indexes"
git push origin HEAD:main
```

脚本扫描 `debs/` 下的全部 DEB，读取实际控制信息，重新生成 `Packages`、其压缩版本以及 `Release` 中的大小和哈希。不要只上传更新后的 DEB 而保留旧索引。

`--check` 只检查本地文件，不联网、不安装软件。新增 DEB 若使用 Zstandard 压缩控制文件，需要支持该格式的 Python 版本或系统工具。

## 目录说明

- `debs/`：实际安装包。
- `Packages` 及压缩版本：包管理器读取的软件包索引。
- `Release`：软件源名称、支持架构和索引校验信息。
- `.nojekyll`：让 Pages 按静态文件发布。
- `tools/update_repo.py`：索引生成和校验工具。

当前未配置 GPG 仓库签名。DEB 内二进制的本地 ad-hoc 签名与 APT 仓库的 GPG 签名是不同机制。若以后启用 GPG 签名，需要在每次更新 `Release` 后重新签名；本脚本遇到已有签名文件会停止，避免发布过期签名。

## Sileo 提示 Couldn't parse release

`Release` 必须包含 `Components: main`；Sileo 即使面对平面源也会检查该字段。平面源的 `Packages` 仍放在根目录，不需要移动到 `dists/`。更新脚本会生成并校验这个字段。

修复后推送仓库，等待 GitHub Pages 部署完成，再确认线上 `Release` 出现 `Components: main`，然后在 Sileo 中刷新源。若仍保留旧结果，可移除这个源后重新添加。

项目参考：[GitHub Pages 发布设置](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)、[Sileo 官方软件源结构](https://github.com/Sileo/repo)、[iGameGod 官网](https://igamegod.app/)。
