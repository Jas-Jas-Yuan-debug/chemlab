# ChemLab handoff

Updated 2026-10-04. Base commit `4360ef5`; this handoff belongs to the delivery containing the 50-round validation. Inspect `git log -1` for its final commit. Follow `docs/GOAL_OBJECTIVE.md` and the approved Godot / AGPL decision. Repository: https://github.com/Jas-Jas-Yuan-debug/chemlab, main.

## Latest delivered work

The user requested 50 cycles of actual testing, use, review and needed revision without disturbing their computer. Completed 50 distinct scenarios, rather than 50 identical full-suite executions. Every round instantiated the real laboratory and used its controls/APIs and native models under the headless dummy renderer. Separate managed checkout, separate user data, one app process at a time, nice 15, maximum 30 processing frames/s; no GUI or clipboard operation. The ordinary experiment directory and original `dist/ChemLab.app` were not replaced.

- Evidence: `artifacts/fifty-rounds.json` has all 63 development attempts: 53 successful and 10 failed, with every distinct round 1–50 ending in a pass. Failed attempts include formatting, fixture, float32 plot comparison, non-additive volume and JSON-double comparison errors in the new harness; they are retained and do not count as completed rounds. Source review found the application defects; affected workflows were rerun after fixes. See `docs/FIFTY_ROUND_VALIDATION.md` and the raw log ZIP.
- Three existing native checks ran once: physics models, reaction dynamics and concentration limits. Native code/library unchanged in this delivery. Byte identity of the reused arm64 native library checked; original PHREEQC/Pitzer data not modified.
- The last round performed 6 complete multi-mode use/reset/save/load cycles. Scene node count was 996 in every cycle; every final round cleanup left only the SceneTree root and zero orphan nodes. Latest successful app-process peak RSS ranged approximately 360–376 MiB. This is short headless ownership/memory evidence, not a long-duration leak proof or a rendering performance result.
- Timeout runner explicitly terminates only its owned process group. A focused 0.2 s timeout check confirmed no leftover task process.

## Application corrections

- pH tool reads the same current lower-zone probe as vessel details; stock/empty readings remain withheld.
- Scoop cannot add an unsolved solid to occupied aqueous material; rejected operations retain both inventories.
- Removing a tool or a deleted scientific vessel scrubs support references. Reattachment has one parent; cycles reject, including invalid saved graphs.
- Beginner and professional additions share the 60-object boundary. Pending vessel creation cannot race a second catalog addition; hidden native bindings refresh before the cap check after professional reset.
- Beginner placement scans available nominal footprints instead of repeating every 12 objects. Professional large vessels also scan available positions; two actual 1000 mL beakers now survive save/load. These are footprint constraints, not calibrated mesh collision or photoreal evidence.
- Live/replayed zero-transfer pours leave titration history unchanged. Empirical stock pours cannot add numeric pH curves. Optional `view.titration_baselines` preserves actual x=0 presence and absence, including untouched reset-defined solutions and depleted/refilled receivers. It is a bounded saved observation, not a new independently recomputed scientific state. Older files without the optional field retain legacy reconstruction and may lack their unrecorded first point.
- Unsupported direct preparation now explicitly explains that boundary before its chemical scope description.

## Build and delivery identity

- New local App: `/Users/jason/.codex/worktrees/fifty-round-validation/chemlab/dist/ChemLab.app`. Kept in the managed worktree; do not archive it while the deliverable is needed.
- Built `2026-10-04T00:25:21Z`; runtime source SHA-256 `e55eccf486a3f41cb88ff5d0b6f92ddcdf0b871ee4be45055e5c06de53390a68`.
- arm64 official Godot 4.7.2 template; ad-hoc signature verified with strict/deep checks. Not notarized, not a published release. `artifacts/build-receipt.json` lists every packaged file hash. Packaging is verified; the new App was not opened, respecting the current background-only request.
- Source changes are GDScript, validation harnesses and documentation. Ordinary native build remains `cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCHEMLAB_BUILD_GODOT=ON`, then a bounded parallel build. `python3 scripts/build_macos.py` packages locally.
- Targeted reuse: `python3 scripts/fifty_rounds.py 41 44 46` creates a separate runtime copy and user directory. `scripts/verify.py` remains the historical broad verifier: it opens windows for 12/15 flows, so do not invoke it for a request that forbids desktop disturbance.

## Scientific and visual scope

Godot 4.7.2, C++17, IPhreeqc 3.8.6. Original code AGPL-3.0-only. Catalogs remain 173 apparatus entries / 81 procedural families, 143 finite dry packages and 30 original reagent entries; only 17/30 reagents have limited scientific workflows. Unknown reactions remain unsupported. Gas-network flow, dedicated drying/scrubbing/condensation, NO2 equilibrium, conductivity, spectra and arbitrary solids are not implemented merely because their apparatus exists.

At approximately 25°C, HCl 13.09 M, NaOH 20.46 M, NaCl 5.40450 M, KOH 14.96 M, KCl 4.15235 M are reviewed reference maxima. Other solutes still have a 0.01 M MODEL cap, not physical saturation. Above 1 M strong acid/base stocks support preparation/aliquots/same-solute mix/water dilution without quantitative pH/species/rates; only both volume-model concentrations <=1 M recover quantitative chemistry. No heat of dilution, volatility or general salt crystal inventory. Salt Pitzer saturation guard rejects transactions outside its liquid model. See `data/solution_limits.json` and `docs/CONCENTRATION_LIMITS.md`.

Two-zone H+/OH- kinetics uses a dilute 25°C rate constant and user exchange Q, not 3D reactive CFD, RPM-derived mixing or thermal coupling. High-I rates are uncalibrated. CO2/Calcite/Gypsum and Barite remain separate limited equilibrium experiments. Seven analytic/numerical physics models and finite-fuel bulk combustion are independent modules; the optional coarse flame field is uncalibrated teaching approximation.

Model identity stays `aqueous-0.4+kinetics-0.1+batch-0.1+barite-0.1+physics-0.3+combustion-0.1`. Sessions load paused and check both databases. Kinetic historical samples are bound/order checked, not replayed from a full Q history. JSON roundtrip preserves kinetic values within double precision; plot coordinates use float32; CSV remains byte identical in covered cases.

Original database hashes: phreeqc.dat `59373961d648dfbf68a40744060c1d64f57ecbec98f4f5fb89f3a1b4213ccd10`; pitzer.dat `06ab2debc0cdb333598118df953165499c2f762a79de5f2df55dec6b78b02589`. Preserve original bytes and never merge databases without consistency work.

## Remaining evidence and next work

The 50 rounds establish covered controls/state/geometry invariants, not photoreal appearance, mesh contact fidelity, long-duration stability or 1920x1080 30 FPS. Historical `artifacts/verification.json` is incomplete; performance first test failed and later retry was interrupted. Do not reuse old 193-cycle or old FPS results as current validation. Do not repeat unchanged checks or benchmarks after documentation-only edits.

Future work, when requested: measure actual rendering in editor and packaged App; visually calibrate geometry/materials; independently expand unsupported chemistry and non-primary concentration limits; record full mixing-control history if independent kinetic-history replay is needed. Maintain honest availability/model boundaries and evidence receipts. No memory files changed.
