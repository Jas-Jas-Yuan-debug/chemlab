# 按物质确定的配液上限

2026-09-12。用户要求将统一 1 mol/L 上限改为可行的最大浓度。本次处理 HCl、NaOH、NaCl、KOH、KCl 五项；其他原料的 0.01 mol/L 仍是旧模型范围，界面明确说明它不是实际溶解度。

## 25°C 的参考上限

| 原料 | 程序输入上限 / mol·L⁻¹ | 依据与边界 |
|---|---:|---|
| HCl | 13.09 | 约 40% 质量分数，密度约 1.194 kg/L；近常压浓盐酸参考边界 |
| NaOH | 20.46 | 约 53% 质量分数，密度约 1.545 kg/L；液相线图向下取整 |
| NaCl | 5.40450 | 原始 Pitzer 数据库 Halite 固液平衡、SI = 0，换算后向下取整 |
| KOH | 14.96 | 约 54% 质量分数，密度约 1.555 kg/L；液相线图向下取整 |
| KCl | 4.15235 | 原始 Pitzer 数据库 Sylvite 固液平衡、SI = 0，换算后向下取整 |

这些是**固定条件下、带数据近似的近饱和/近常压配制边界**，不是任意温度、压力下的绝对最大值。盐酸上限随 HCl 分压和温度变化；40% 是从厂商图表保守选取的参考值，不把常见的 37% 商品规格当成溶解度。当前储液不与空气交换，尚不计算开瓶后的 HCl 挥发、稀释放热或沸腾。

摩尔浓度以**最终溶液体积**为分母：`c = 1000 ρ w / M`，其中 ρ 为 kg/L、w 为质量分数、M 为 g/mol。不能将“每 100 g 水溶解多少克”直接当成每 100 mL 溶液。物性图插值的密度按约 1% 量级精度理解；输入字段中的小数位用于数值边界一致性，不表示实验数据有相同精度。

## 数据来源与可追溯性

- [OxyChem Hydrochloric Acid Handbook](https://www.oxychem.com/siteassets/documents/chlor-alkali/hydrochloric-acid-handbook.pdf)，印刷/PDF 第 36–38、41 页：总蒸气压、HCl 分压、沸点与密度。密度在 77°F 读图插值。
- [OxyChem Caustic Soda Handbook](https://www.oxychem.com/siteassets/documents/chlor-alkali/caustic-soda-handbook.pdf)，第 33–34 页：25°C 液相线约 53–54%，取 53%；密度在 50% 和 55% 曲线之间插值，55% 曲线包含亚稳密度延伸近似。
- [OxyChem Caustic Potash Handbook](https://www.oxychem.com/siteassets/documents/chlor-alkali/caustic-potash-handbook.pdf)，第 28、33、35 页：77°F 液相线约 54–55%，取 54%。15.6°C 密度表按温度图修正到 25°C；52–54% 最后两个百分点按表末斜率外推，故该密度是工程近似。
- [USGS IPhreeqc 3.8.6-17100 原始发行包](https://water.usgs.gov/water-resources/software/PHREEQC/iphreeqc-3.8.6-17100.tar.gz) 中 `pitzer.dat`：25°C、1 atm、1 kg 水分别与过量 Halite/Sylvite 平衡。得到 NaCl 6.129227565 mol/kg 水、溶液体积 1.134095903 L；KCl 4.791296848 mol/kg 水、1.153875366 L。这两个上限是数据库模型估计，不是独立实测精度声明。

唯一人工维护数据是 [data/solution_limits.json](../data/solution_limits.json)。`scripts/build_catalog.py` 同时生成原生 `solution_limits_data.hpp` 和两个界面共享的试剂目录。密度表只取数值事实和自行读图近似，未将厂商图表、PDF 或图片打包分发。PHREEQC 两份原始数据库保持字节不变。

## 配液与反应能力分开

- HCl/NaOH/KOH **≤1 mol/L** 保留此前的定量模型：≤0.01 mol/L 使用离子缔合数据库；其上使用独立 Pitzer 引擎。高离子强度下的反应速率仍属稀溶液常数外推，未标定。
- 三者 **>1 mol/L** 使用物性浓储液模式：按质量分数与密度反求水质量，固定溶质摩尔数和最终体积。支持分装、同一种溶质不同浓度的混合、加水稀释。内部原始溶液状态用于保存元素/H/O 库存；极浓条件的活度、离子浓度和密度外推不作为产品科学读数。
- 浓储液不显示 pH、H⁺/OH⁻ 浓度、活度系数或反应速率，不绘制这些曲线，不保留旧指示剂颜色。异种反应明确要求先分别稀释到已支持范围；不能以虚假的定量结果替代尚缺的浓溶液反应、热量和相变化模型。
- 加水稀释时保持各元素与 H/O 收支。只有物性与求解器两种体积换算均落入 ≤1 mol/L 才恢复定量活度和中和模型；两种密度模型衔接存在小的体积近似差异。恢复后从新动力学时钟采样，不跨越无读数区间连线。
- NaCl/KCl 在各自上限内继续采用 Pitzer，检查 Halite/Sylvite 饱和度。尚未实现常规实验台盐结晶库存，若混合结果过饱和则整次操作拒绝，不损耗原容器物质。专用气液固实验的现有范围不变。

## 保存与验证

科学模型升至 `aqueous-0.4+kinetics-0.1+batch-0.1+barite-0.1+physics-0.3+combustion-0.1`。操作日志重演恢复浓储液标志和物性体积；浓储液事件包含 `empirical_stock=1`，省略 pH，CSV 的 pH 单元格为空。旧模型版本会明确拒绝加载。

本次定向检查只覆盖新增浓度边界及其受影响流程：

- `tests/concentration_limits_test.cpp`：五种上限各自的 1/50/250 mL 配制、超上限/NaN 拒绝、质量分数与厂商密度点核对、分装/自身混合/稀释收支、恢复定量模型、盐饱和度、反应拒绝的事务完整性。
- `godot/tests/concentration_limits_flow.gd`：两种界面的独立上限和最大值按钮、浓储液无虚假读数、稀释恢复、保存/加载、CSV 完全一致以及新手配液。

- `godot/tests/concentration_boundary_native.gd`：往浓储液中加水跨入定量范围、浓储液完全倒空，两者均能恢复/保留可重载的动力学状态。

保存流程还修正了 JSON 重载后 CSV 附加列顺序变化的问题：附加列和动力学器材序列均采用固定排序。

新检查的最终状态与运行源码哈希见 [定向记录](../artifacts/concentration-limits-validation.json)。未重复运行旧的整套测试或性能测试，不扩大此前全套/帧率证据的结论。
