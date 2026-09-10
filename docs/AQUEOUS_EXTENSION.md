# 扩展稀溶液与分样 · aqueous-0.2

本页保留原稀溶液扩展依据。2026-09-10 的五种强电解质 1 M 范围和中和动力学另见 [当前模型](REACTION_DYNAMICS.md)，其余本页限定不变。

新增并验证预配的 H₂SO₄、Na₂SO₄、MgCl₂、MgSO₄、BaCl₂ 水溶液，共 5 项；总计 14 项水/预配水溶液，加上 CO₂、方解石、石膏独立实验，产品可操作原料为 17/30。没有把固体与溶液重复计数。

温度 25°C，配液 1–250 mL、0.00001–0.01 mol/L；硫固定以 S(6) 输入，数量按原料化学计量换算并迭代到指定溶液体积。无水固体、水合固体的直接溶解、放热和饱和度尚未由这些预配液入口实现。

H₂SO₄ 与 Na₂SO₄ 可参与已有稀酸/碱/Na/K 盐混合。MgCl₂、MgSO₄、BaCl₂ 暂只支持自身混合、分装与水稀释；还未启用任意沉淀组合。此范围可因价态守恒校验失败而拒绝某次操作，失败不改变有效状态。

## 分样保持强度量

均一溶液分装不改变 pH、浓度、温度和价态。`scaled` 使用固定版 PHREEQC 的 `cxxSolution::read_raw / multiply / dump_raw`，按比例缩放广延量；同时缩放应用的体积、水质量、元素/价态数量、H/O 和原料来源。保留 H/O、水和体积的双精度往返格式，避免原始 DUMP 的 14 位输出逐步降低精度。由同一状态分出的相同溶液重新合并也沿此路径。所有实际不同组成的混合仍由 IPhreeqc 重新求平衡。

这是对均一体系分样的守恒处理，不是用固定 pH 替代混合后的求解。常规酸碱混合、独立配液稀释对照及气液固样品流程均重新运行通过。

## 验证和未通过项目

`tests/aqueous_expansion_test.cpp`：5 原料 × 3 浓度 × 3 体积，共 45 组配液、计量、分装、稀释、自身混合及十次连续转移；另检验稀硫酸二级解离近似与两当量 NaOH 中和。硫酸第二步的理想稀溶液参考使用 Ka₂≈0.0102，pH 容差 0.06；正式读数来自固定数据库的 HSO₄⁻/SO₄²⁻平衡，不使用此近似公式替代求解。

原始候选审查记录在 `artifacts/aqueous-candidate-audit.txt`。该审查使用自动 MIX 重新平衡分样，发现 N、Fe、Cu 的价态变化，未把这些条目计数。修复纯分样后，仍未验证它们与不同溶液的混合/稀释和特定固相，因此 12、13、20、21、26、27、28 项继续禁用。并非声称数据库中不存在这些元素。

求解结果额外记录 N(5)/N(-3)/N(0)、S(6)/S(-2)、Fe(2)/Fe(3)、Cu(1)/Cu(2)、C(4)/C(-4)；在没有授权氧化还原反应的普通混合中核查这些价态的数量。硝酸的酸碱功能、氨/铵、铁和铜的专用模型需要单独验证后才开放；不以热力学库覆盖代替产品验证。

依据：固定 `phreeqc.dat` 中硫酸氢根解离与离子络合数据，以及 [USGS SOLUTION 输入说明](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-48.htm)、[MIX](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-27.htm)、[收敛控制](https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-25.htm)。
