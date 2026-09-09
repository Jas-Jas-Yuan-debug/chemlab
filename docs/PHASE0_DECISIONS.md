# Phase 0 决策记录

检查日期：2026-09-09。用户已明确选择：**保留 AGPL-3.0，改用 Godot，不保留 Unreal**。随后明确要求使用 Git 创建并推送至 GitHub 公有仓库 `chemlab`，协议 AGPL-3.0。

执行决定：原创代码采用 AGPL-3.0-only；科学核心 C++ + IPhreeqc；Godot 场景与 Control 界面替代蓝图与 UMG。以下原始检查保留用于说明决策依据。Unreal 缺失不再是实施阻碍；不安装 Unreal 或 Epic Launcher。

## 许可证阻碍

目标是 Unreal C++/蓝图/UMG 产品，原创代码拟采用 AGPL-3.0。

Epic 当前标准 Unreal EULA 第 6(c) 条禁止将引擎与会直接或间接要求引擎受其他条款约束的代码组合、分发或使用；示例包含 GPL。AGPL 虽未在示例中单独列名，其第 5(c) 条要求受覆盖的组合整体采用 AGPL，第 6 条涉及对应源代码的提供。因此，将 AGPL-only 的实验室模块直接链接 Unreal 并把整体作为 AGPL 程序发布，不是本项目可以认定兼容的路线。免费发布、只公开自己的源码、动态链接，均不能自动解除这个冲突。

依据：[Unreal EULA §6(c), §4–5](https://www.unrealengine.com/eula/unreal)、[AGPL-3.0 §5–6](https://www.gnu.org/licenses/agpl-3.0.html)。这是依据公开条款作出的项目集成判断；没有获得 Epic 的定制授权。

## 原始可选路线（已选择路线 2）

1. **保留 Unreal**：由用户批准将原创代码以 MIT 等相容条款提供给 Unreal 项目；Epic 引擎、第三方代码与资源仍各自保留原许可，不能将整个引擎重新标为 MIT。可继续 C++、蓝图与 UMG 目标。也可以另行讨论原创代码的双重授权，但不能擅自添加例外或改许可。
2. **保留 AGPL-3.0**：由用户批准换用相容的引擎，例如 MIT 许可的 Godot，原创实验室代码继续 AGPL。科学 C++ 与 PHREEQC 可保留，场景配置及 UI 需替代蓝图和 UMG，视觉目标重新验证。Godot 与其第三方许可及署名仍须随发布保留。依据：[Godot 官方许可](https://godotengine.org/license/)。

独立进程不是默认的许可规避方案：通信的内容和耦合程度也影响是否构成组合程序；这里只进行不依赖 Unreal 的技术验证，未据此认定未来组合产品兼容。依据：[GNU FAQ, MereAggregation / GPLPlugins](https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation)。

## 必要软件阻碍

- 项目目录最初为空，没有旧代码需要修复。
- 常见安装目录、用户 Epic 注册目录及 Spotlight 未发现 Unreal Editor / UnrealBuildTool，也未发现 Epic Games Launcher。若用户有自定义安装，可提供路径复核。
- 本机：Apple M4 10 核 CPU / 10 核 GPU，16GB；macOS 26.6.2；Xcode 26.5 (17F42)；Apple clang 21.0.0；CMake 4.2.3；项目所在磁盘可用约 172 GiB。
- Epic 的 UE 5.8 macOS 要求页推荐 Xcode 26.1.1，并明确排除 26.4；页面未明确验证本机 26.5，不能推断较新就兼容。M4 达到列出的 Apple Silicon 硬件门槛，16GB 处于最低内存，低于推荐 32GB。引擎版本、完整工具链和启动仍待实测。[官方要求](https://dev.epicgames.com/documentation/unreal-engine/macos-development-requirements-for-unreal-engine?lang=en-US)。
- 保留 Unreal 后仍需用户授权大型安装，或提供已有引擎路径。未安装大型软件、未变更全局 Xcode 选择、未接受账户条款。

## 允许继续的独立工作

下载官方小型 IPhreeqc 源码包到项目内，检查许可证，固定哈希，在 arm64 上编译并运行 C++ 测试；建立 30 项数据库覆盖与验证矩阵。此工作不包含 Unreal 依赖，不代表 Phase 0 全部完成或任何原料已经在产品中可操作。
