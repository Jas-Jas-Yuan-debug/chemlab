# 有限固体与 CO₂ 实验 · batch-0.1

已运行 C++ 科学验证和 Godot 实际渲染界面流程。支持在独立反应器中加入有限方解石（CaCO₃）、二水石膏（CaSO₄·2H₂O）或 CO₂，显示最终平衡，分离全部清液到新烧杯，再向空容器分装。它们不是任意混合模型。

## 边界与状态

固定 25°C、底液 10–250 mL；底液可选蒸馏水或 0.00001–0.01 mol/L 的 HCl、NaHCO₃、Na₂CO₃。每次配料重新定义独立实验，不累计上一试验的残余物。一次只选择一个固相：Calcite 或 Gypsum，加入 0–5 mmol；其余固相不自动参与。

- 隔绝气体交换：只求液固平衡，无气相分配。
- 封闭 CO₂：有限加入 0–1 mmol，定容顶空 50–1000 mL，仅含 CO₂。采用理想气体，结果压力必须 ≤1 atm；忽略空气、水蒸气、液体占据顶空引起的变化及溶液压力修正。顶空由独立气室定义。
- 开放 CO₂：外界分压 0.0001–0.01 atm，以 PHREEQC `EQUILIBRIUM_PHASES CO2(g)` 保持。数值储库初始 1 mol；验证不会耗尽（至少剩 0.99 mol）。记录储库增加量，正数是系统向外释放、负数为吸收。储库是外部环境，不计入有限试剂库存。

原始溶液体积由 PHREEQC 计算；石膏的结晶水进入 H/O 与溶剂收支。固体剩余量来自 EQUI，不预设全部溶解。所有非零候选固体均与水相达到平衡，不模拟成核延迟、颗粒表面积或动力学。

分离清液把液相完整移至新烧杯，保留固体与气相并结束本次反应器试验；不声称分离后残余体系仍保持平衡。清液仅允许向空容器分装，暂不支持再混合、稀释和暴露空气后的变化。

## 低压 CO₂ 的明确近似

所固定 IPhreeqc 版本的 `src/phreeqcpp/model.cpp:2601` 将 Peng–Robinson 路径中的气体摩尔体积上限设为 10000 L/mol。验证发现，在低于约 0.00245 atm 的 CO₂–方解石试验中，直接读取的压力不满足实际头空间和气体数量关系；启用 numerical_fixed_volume 会在该例产生收敛警告，应用拒绝警告结果。

因此封闭低压模型显式定义 `CO2_ideal(g)`：完整复制同一固定数据库 CO2(g) 的 log K、焓与温度表达式，只省略临界 EOS 参数。没有混入其他数据库，也不修改原始数据库文件。25°C 亨利平衡保持原参数，气相使用理想气体近似。压力上限之外拒绝，不外推到高压。开放模式沿用原 CO2(g)。

参考：[USGS GAS_PHASE](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-17.htm)、[USGS EQUILIBRIUM_PHASES](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-13.htm)、[气体溶解度与 Peng–Robinson](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-84.htm)。

## 已运行验证

`tests/batch_test.cpp` 覆盖 4 种底液 × 3 个体积 × 3 种固相选择 × 3 种气体边界，共 108 组条件，每组重复并分取四分之一清液。另有固体耗尽、酸促进溶解、无效输入与禁止混合案例。

- Ca、C、S 以及 H/O 收支；清液分样检查全部跟踪元素。
- 有残余固体时 SI≈0；未饱和的小剂量石膏全部溶解。
- 封闭气体验证 PV=nRT，包括上述低压边界。
- 石膏参考：USGS 示例 2 给出 25°C 约 15.1 mmol/kgw；测试允许 0.3 mmol/kgw 差异以覆盖数据库修订和有限水合水。[官方示例](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-64.htm)
- 开放 CO₂ 纯水以亨利定律与一级解离近似独立核对 pH，容差 0.03。
- `godot/tests/batch_flow.gd` 验证方解石开放/封闭、有限石膏、封闭 CO₂、清液分离/分装、读数曲线和重置。

100 mL 蒸馏水、25°C 的当前回归结果（不是独立实测数据）：加入 2 mmol 方解石且不交换气体，约剩 1.988 mmol，pH 9.91；石膏约剩 0.499 mmol，pH 7.06。开放到 CO₂ 0.00042 atm 时方解石约剩 1.946 mmol、pH 8.20。

## 视觉

白色固体体积由剩余物质的量与原数据库 `-Vm` 换算（方解石 36.9、石膏 73.9 cm³/mol）；形状是简化平层，不是晶粒模拟。溶液颜色不使用固体颜色。气泡只有在计算的净气体释放量为正时显示，数量有上限、仅为示意，动画时间和粒子个数都不是科学读数。
