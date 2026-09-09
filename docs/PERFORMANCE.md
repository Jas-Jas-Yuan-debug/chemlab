# 性能与稳定性实测

硬件为 Apple M4、16 GiB 统一内存；实际渲染图像 1920×1080，Godot 4.7.2 / Metal Mobile。以下数据来自完整的运行记录，不从截图速度或无窗口执行推算。

编辑器模式是编辑器引擎运行游戏，同时保留一个最小化的编辑器窗口；包装模式使用独立 release 应用。测试脚本检查编辑器进程全程存活。帧间隔取实际 `frame_post_draw` 回调，测量区间不强制绘制；它是引擎渲染计时，不是外部显示器捕获。每场景预热，切换操作的间隔不纳入稳态帧率。

30 FPS 判据为：99% 帧间隔 ≤33.334 ms，且每个完整一秒窗口至少 30 帧。单独记录最长帧，避免平均值掩盖抖动。

| 模式 / 场景 | 平均 FPS | P99 / ms | 最长帧 / ms | 最低完整秒 FPS | 30 FPS 判据 |
|---|---:|---:|---:|---:|---|
| editor-run / chemistry_four_vessels | 119.83 | 9.45 | 20.89 | 118 | 通过 |
| editor-run / chemistry_twelve_vessels_and_pour | 120.01 | 10.06 | 10.26 | 119 | 通过 |
| editor-run / circuit | 120.04 | 10.07 | 10.26 | 120 | 通过 |
| editor-run / free_fall_repeat | 119.97 | 9.77 | 12.12 | 119 | 通过 |
| editor-run / heat | 120.03 | 10.02 | 10.12 | 120 | 通过 |
| editor-run / heater | 120.01 | 10.15 | 10.49 | 120 | 通过 |
| editor-run / heater_source_0 | 120.08 | 9.62 | 10.29 | 120 | 通过 |
| editor-run / heater_source_1 | 120.01 | 9.69 | 9.87 | 119 | 通过 |
| editor-run / heater_source_2 | 120.08 | 9.79 | 9.98 | 120 | 通过 |
| editor-run / heater_source_3 | 120.05 | 9.96 | 10.25 | 120 | 通过 |
| editor-run / heater_source_4 | 119.39 | 9.43 | 34.32 | 116 | 通过 |
| editor-run / heater_source_5 | 120.06 | 9.49 | 9.68 | 120 | 通过 |
| editor-run / lens | 119.99 | 9.62 | 10.06 | 119 | 通过 |
| editor-run / pendulum | 120.04 | 10.09 | 10.38 | 120 | 通过 |
| editor-run / precipitation | 120.03 | 9.43 | 10.22 | 120 | 通过 |
| editor-run / spring | 119.99 | 9.95 | 10.22 | 119 | 通过 |
| editor-run / stress_cycles | 120.08 | 9.99 | 14.41 | 119 | 通过 |
| packaged / chemistry_four_vessels | 119.76 | 9.45 | 26.22 | 118 | 通过 |
| packaged / chemistry_twelve_vessels_and_pour | 119.98 | 9.83 | 11.40 | 119 | 通过 |
| packaged / circuit | 120.04 | 9.84 | 10.10 | 120 | 通过 |
| packaged / free_fall_repeat | 119.96 | 9.71 | 12.37 | 119 | 通过 |
| packaged / heat | 120.03 | 9.92 | 10.11 | 120 | 通过 |
| packaged / heater | 120.01 | 10.08 | 10.30 | 120 | 通过 |
| packaged / heater_source_0 | 120.02 | 10.19 | 10.35 | 120 | 通过 |
| packaged / heater_source_1 | 120.07 | 9.71 | 9.90 | 120 | 通过 |
| packaged / heater_source_2 | 120.02 | 9.81 | 10.03 | 120 | 通过 |
| packaged / heater_source_3 | 120.01 | 9.96 | 10.12 | 119 | 通过 |
| packaged / heater_source_4 | 120.03 | 9.54 | 10.25 | 120 | 通过 |
| packaged / heater_source_5 | 120.03 | 9.39 | 9.44 | 120 | 通过 |
| packaged / lens | 119.98 | 9.61 | 9.82 | 119 | 通过 |
| packaged / pendulum | 120.03 | 9.76 | 10.16 | 120 | 通过 |
| packaged / precipitation | 120.03 | 9.61 | 10.00 | 120 | 通过 |
| packaged / spring | 119.99 | 9.85 | 10.07 | 119 | 通过 |
| packaged / stress_cycles | 120.05 | 9.77 | 12.76 | 119 | 通过 |

## 内存、响应与重复操作

- editor-run：总运行 165.1 秒，进程 RSS 峰值 535.2 MiB；求解器计算平均 5.58 ms、P99 6.75 ms；请求等待至主线程提交平均 30.29 ms、P99 74.01 ms。响应样本包括配液、分样、保存状态回放等，不能当作每种操作各自的统计。
- 编辑器窗口自身的 RSS 峰值 1116.1 MiB，游戏进程内存另计。
- packaged：总运行 742.9 秒，进程 RSS 峰值 512.9 MiB；求解器计算平均 6.02 ms、P99 8.14 ms；请求等待至主线程提交平均 31.38 ms、P99 44.90 ms。响应样本包括配液、分样、保存状态回放等，不能当作每种操作各自的统计。

打包程序完成 193 轮重复生命周期操作（约 600 秒）：重置 → 稀酸碱等量加入 → pH 与体积核对 → 保存/加载 → 轮换六个物理实验台模型。每次还原检查守恒状态，运行日志无脚本错误或泄漏警告。

比较开头与末尾各六轮（覆盖同一组模型），平均 RSS 511.4 → 512.6 MiB，变化 +1.2 MiB；发布运行程序的静态内存与孤立节点监测均返回 0，不能解释为零占用或零孤立节点；内部计数不作为结论依据。 RSS 由系统每秒采样，包含分配器缓存和本次测量保留的逐帧计时数据；该有限时段不能证明任意长时间或任意操作序列均无泄漏。

CSV 保存/恢复、错误保留、原料元素与氢氧守恒、加热能量账另见完整回归 `artifacts/verification.json`。无窗口发布应用检查见 `artifacts/packaged-smoke.json`，不计入帧率。

源文件指纹：`566d35a030e704e9c2b5a128d2f71ba594fd9ade55522da8b9841d94c40a798f`。构建文件哈希见 `artifacts/build-receipt.json`；原始实测为 `artifacts/performance-editor-run.json` 和 `artifacts/performance-packaged.json`。
