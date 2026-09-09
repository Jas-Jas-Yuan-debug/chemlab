# ChemLab · 三维化学与物理实验室

Godot + C++ + IPhreeqc，中文界面。原创代码 **AGPL-3.0-only**。

项目正在按阶段开发，当前为 **Phase 0：环境与科学求解器验证**。
目前还不是可交付的三维实验室；可操作且经验证的原料为 **0/30**。

用户已明确选择保留 AGPL 并从 Unreal 改为 Godot，详见
[决策记录](docs/PHASE0_DECISIONS.md)。原始目标保留于
[目标文件](docs/GOAL_OBJECTIVE.md)，其中 Unreal / 蓝图 / UMG 要求由该决定替代。

## 构建独立 C++ 验证程序

需要 CMake ≥3.20、C++17 编译器、Python 3（支持 tarfile 安全解压）、Ninja。

```sh
python3 scripts/bootstrap.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
```

输出数据位于 `build/artifacts/iphreeqc_results.csv`。初期采用 25°C、稀水溶液、
充分混合后的平衡模型；输入单位为 mol/kg 水，不冒充已验证 mol/L 配液。
[科学边界与验证方法](docs/VALIDATION_SCOPE.md)。

## 许可与数据

- [AGPL-3.0](LICENSE) 适用于原创代码。
- [第三方声明](THIRD_PARTY_NOTICES.md) 保留各依赖原许可与署名。
- 数据库有覆盖不代表实验已经验证，更不代表支持任意混合。
- 尚未测得编辑器/打包程序帧率，未宣称达到 30 FPS。
