# 独立科学验证的边界

当前 **17/30** 项原料在限定范围内可操作：14 项水或预配水溶液，以及独立试验中的 CO₂、方解石和二水石膏。原生科学检查和 Godot 渲染界面流程均已通过。其余 13 项保持未支持；数据库名称存在或命令行配液成功，不足以计为产品支持。

首批测试在 25°C、1 atm、稀水溶液、密闭且不交换 CO₂ 的条件下进行。充分混合后求平衡；不计算速率、混合时间、热释放或空间浓度场。pH 是氢离子活度的负常用对数。

独立 iphreeqc_probe 采用 mol/kg 水。产品核心 Chemistry::prepare 接受 mL 与 mol/L，固定溶质的量，迭代调整水质量使 SOLN_VOL 匹配目标体积；81 组执行检查了体积与元素数量。均一分样按比例缩放广延量且保持强度量；实际不同组成混合由完整 SOLUTION_RAW + MIX 求平衡，保留反应生成水对体积和氢/氧的影响，详见 [分样说明](AQUEOUS_EXTENSION.md)。

已验证范围为 25°C、初始 1–250 mL、1e-5–0.01 mol/L；水浓度为 0。IDs 2–6、11、14 支持限定稀酸碱/Na/K 盐混合；IDs 7–9、15、16、25 常规实验台只支持自身或水的组合。BaCl₂ / Na₂SO₄ 在专用沉淀页求 Barite 平衡；Calcite/Gypsum/CO₂ 在专用气液固页分别记账。专用相平衡样品可转移至空容器，不开放后续任意混合。浓度角点与中点作为代表性测试，未承诺区间外或全部组合。

纯水与强酸碱参考采用电中性、元素守恒和理想稀溶液极限。活度模型会使 0.001 mol/kg 的强酸 pH 略偏离 3，故理想值只作有明示容差的外部检查，不把它当精确 PHREEQC 标准答案。水自解离检查应使用固定数据库的温度参数。固定版本的数值快照只用于回归，不能代替独立科学依据。

额外稀溶液核对：NaCl/KCl 近中性，CaCl₂ 允许轻微水解偏移；NaHCO₃ 用两性离子理想近似 pH≈(6.35+10.33)/2，Na₂CO₃ 用 Kb=Kw/Ka₂ 的二次方程求 OH⁻。这些都是有显式容差的近似参考（0.04–0.20 pH），不是所有浓度下的精确值。酸碱近似原理参见 [OpenStax 酸碱滴定](https://openstax.org/books/chemistry/pages/14-7-acid-base-titrations)，固定碳酸体系常数和活度参数保留在原始数据库中。

数据库覆盖检查只证明名称与反应参数存在。它不证明该化学品已经具备正确物态处理、可信溶解度、价态约束或任意混合能力。PHREEQC 的 REACTION 加料指令本身也不等于已建立固体溶解平衡。候选固相须逐个根据具体实验选取，不启用所有可能固相。

扩展组、进阶组的未支持项仍需逐项参考验证；单一数据库缺失项保持未支持，不能从其他数据库直接拼接。氨水映射 NH₃(aq)/NH₄⁺；乙酸体系需独立乙酸根主组分与可信酸解离参数；硝酸只考虑经过验证的稀水溶液酸碱行为；O₂ 条目不表示支持燃烧。

来源：

- [USGS PHREEQC 3 模型范围](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-1.htm)
- [SOLUTION：输入单位、pH charge、-water](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-48.htm)
- [USER_PUNCH：读取计算结果](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-60.htm)
- [Basic：TOTMOLE 与 TOT 的量纲](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-61.htm)

新增范围与数值回归见 [气液固](BATCH_EQUILIBRIUM.md)、[扩展溶液](AQUEOUS_EXTENSION.md)、[沉淀](PRECIPITATION.md)。七类物理实验采用独立模型，详见 [物理模型](PHYSICS_MODELS.md)。保存与导出验证见 [实验记录](SESSION_FORMAT.md)。
