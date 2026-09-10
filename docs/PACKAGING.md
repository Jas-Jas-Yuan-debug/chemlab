# macOS 打包

`python3 scripts/build_macos.py` 生成 `dist/ChemLab.app`。内含官方 Godot release 运行程序、项目 PCK、arm64 GDExtension、固定数据库和第三方声明，不需要在目标机器上安装编辑器。当前在 Apple M4 / macOS 26.6.2 上验证；不承诺未经测试的旧系统或 Intel 机器。

脚本从官方 Godot 4.7.2 `export_templates.tpz` 以 HTTP Range 只读取 `templates/macos.zip`。拒绝不尊重 Range 的服务器，避免意外下载约 1.2 GiB 的全平台包；成员约 117 MiB，检查 ZIP CRC 和 `dependencies.lock.json` 固定的 SHA-256。

官方 macOS 成员提供 universal 二进制，而此版本导出器的 arm64 选项要求 `.arm64` 命名。脚本用 macOS `lipo -thin arm64` 从官方二进制生成项目内专用模板，未改动引擎源代码或其他体系结构内容。模板在 `tools/`，不会安装到用户全局模板目录。扩展库也明确为 arm64。

导出使用 Xcode `codesign`、临时身份 `-`。加入第三方声明后重签并执行 `codesign --verify --deep --strict`。`artifacts/build-receipt.json` 记录源文件指纹、每个应用文件的大小与哈希、架构和签名方式。临时签名不是 Apple Developer ID 公证，未经公证的下载文件可能受 Gatekeeper 限制；没有在此项目中关闭系统安全设置。

源码运行与发布应用共用主场景和数据库字节。`LabCore` 从 `res://data/phreeqc.dat` 与 `res://data/pitzer.dat` 分别读取原始字节、验证各自校验值，再加载两个独立 IPhreeqc 实例，适用于源目录和 PCK，避免把编辑器路径当作发布文件路径。

性能脚本仅在显式命令参数启用时运行，普通启动不会读写测试文件或自动操作实验。项目内测试与下载缓存不进入应用。原料数据库和 JSON 注册表显式包含在导出清单中。

参考：[Godot macOS 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)、[macOS 导出参数](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformmacos.html)、[命令行运行](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)。
