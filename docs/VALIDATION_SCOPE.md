# 独立科学验证的边界

当前属于 Phase 0 的平台与求解器验证，尚无三维程序，可操作原料数量为 **0/30**。通过命令行算例不能计为产品原料完成。

首批测试在 25°C、1 atm、稀水溶液、密闭且不交换 CO₂ 的条件下进行。充分混合后求平衡；不计算速率、混合时间、热释放或空间浓度场。pH 是氢离子活度的负常用对数。

输入采用 mol/kg 水，而不是假定 kg 水等于 L 溶液。后续界面采用 mL 和 mol/L 前，需要独立实现并验证密度、溶液体积及溶剂质量换算。当前脚本不会把 molality 验证冒充 molarity 验证。

纯水与强酸碱参考采用电中性、元素守恒和理想稀溶液极限。活度模型会使 0.001 mol/kg 的强酸 pH 略偏离 3，故理想值只作有明示容差的外部检查，不把它当精确 PHREEQC 标准答案。水自解离检查应使用固定数据库的温度参数。固定版本的数值快照只用于回归，不能代替独立科学依据。

数据库覆盖检查只证明名称与反应参数存在。它不证明该化学品已经具备正确物态处理、可信溶解度、价态约束或任意混合能力。PHREEQC 的 REACTION 加料指令本身也不等于已建立固体溶解平衡。候选固相须逐个根据具体实验选取，不启用所有可能固相。

扩展组、进阶组需要逐项参考验证；单一数据库缺失项保持未支持，不能从其他数据库直接拼接。氨水映射 NH₃(aq)/NH₄⁺；乙酸体系需独立乙酸根主组分与可信酸解离参数；硝酸只考虑经过验证的稀水溶液酸碱行为；O₂ 条目不表示支持燃烧。

来源：

- [USGS PHREEQC 3 模型范围](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-1.htm)
- [SOLUTION：输入单位、pH charge、-water](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-48.htm)
- [USER_PUNCH：读取计算结果](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-60.htm)
- [Basic：TOTMOLE 与 TOT 的量纲](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-61.htm)
