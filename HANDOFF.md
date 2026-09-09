# ChemLab handoff

Updated 2026-09-09. Follow `docs/GOAL_OBJECTIVE.md` plus the user's approved changes. Goal is active while final packaged stability validation is running.

## Authorization

- User explicitly chose Godot instead of Unreal, retaining AGPL-3.0. Public GitHub repo `Jas-Jas-Yuan-debug/chemlab`, Git main, commit and push are authorized. Live metadata verified PUBLIC / AGPL-3.0.
- Earlier ten-minute testing pause was honored. The user confirmed manually closing previous windows. They subsequently said **"now you can run the tests"**; window testing is authorized again. Preserve any newer steering.
- User added adjustable target temperature, stirring, alcohol lamp, Bunsen burner, oxyhydrogen flame, oxyacetylene flame and alcohol blowtorch. These are now implemented in the dedicated water heating/stirring experiment. No paid/global/Unreal installations.

## Current verified state

- Portable Godot 4.7.2 official, godot-cpp API 4.5 commit, IPhreeqc 3.8.6-17100, original phreeqc.dat. Fixed downloads and hashes. Apple M4 16 GiB, macOS 26.6.2, Apple Clang 21, CMake/Ninja, native arm64.
- Chinese 3D room, glass containers, orbit/zoom/focus, select/drag/collision boundaries, equipment addition, search/category, source/receiver selection, controlled pouring with true conserved aliquots. Hollow glass and gravity-level clipped liquid surfaces independently checked against canonical volume; visual approximation documented.
- **17/30 raw reagents**: water/prepared aqueous IDs 1–9,11,14,15,16,25; dedicated CO2 10, Calcite 18, Gypsum 19. Three additional indicator maps do not count. Dedicated Barite precipitation supported. Ordinary chemistry only verified whitelists; final 25°C equilibrium, no arbitrary redox/combustion/kinetics.
- Seven physics categories: free fall, spring, small-angle pendulum, two-water heat exchange, series/parallel DC, thin lens, water heating/stirring. Fixed 1/120 s model clocks, native equations, geometry/readings/curves from same state.
- Heater: target water 25–95°C, prescribed effective power 50–1000 W, independent 0–600 rpm overhead stirrer, six source appearances. Live controls preserve water temperature/energy/turns; ideal feedback holds temperature, lowering target passively cools. No combustion/fuel/actual flame-temperature or fluid-field solver. Chemistry remains 25°C.
- JSON white-listed replay, geometry/indicator/camera/history restoration, paused load, CSV, invalid-file/error state preservation. Heater control history included in physics-0.2; old physics-0.1 files reject as incompatible.
- Latest full `scripts/verify.py` passed **7 CTest cases + Godot import + 2 headless flows + 8 rendered flows**, including heater controls, all six apparatus appearances, native thermostat/cooling/energy/turn checks and byte-identical CSV restoration. No errors/leak warnings.
- `dist/ChemLab.app` rebuilt at **2026-09-09 13:20:06 UTC**, source fingerprint `566d35a030e704e9c2b5a128d2f71ba594fd9ade55522da8b9841d94c40a798f`. Official arm64 release executable, PCK, native dylib, database, notices; ad-hoc signed and strict codesign verification passed. Not notarized. Headless launch from `/tmp` passed chemistry/Barite/heat/heater/control history/save-load checks. Do not count headless timings as FPS.
- Latest editor benchmark completed **16 scenes**, all passed P99 ≤33.334 ms and minimum complete second ≥30 frames. Editor UI stayed alive and minimized throughout, with RSS ≥562 MiB. Game callback rate about 120/s; this is engine render timing, not an external display refresh measurement. Old pre-heater receipt was replaced; its editor UI had exited early.

## Work currently in progress

First packaged long run was stopped after detecting an incorrect test assumption: equal 25 mL acid/base aliquots solve to 50.0005538988 mL, not exactly 50 mL. Save/load itself preserved the correct result. Benchmark now compares solved before/after volume and every element, and stops on first failure. Corrected editor benchmark with repeated cycles passed. A subsequent static review found the fixed heating beaker could retain a hidden collider when returning to chemistry; its pick layer is now disabled and heater_flow has a ray-selection regression. The shared Vessel class now disables picking for all zero-ID fixed apparatus, including the batch reactor; the main picker also rejects unknown inventory IDs. Full 12-group verification passed. Current-source editor measurement with repeated cycles is running, then packaged --stress-seconds 600 remains. Do not start competing tests or edit runtime source during measurement. It runs the same scene matrix, then approximately ten minutes of reset/neutralization/save/load/model cycles. Inspect final `artifacts/performance-packaged.json`, require full PASS and no errors. Run `python3 scripts/report_performance.py` afterward to produce PERFORMANCE.md and summary. Inspect memory trend and all FPS flags; failures require fixes, not a fabricated pass.

Finish documentation, commit/push final receipts, verify remote HEAD and deliver the app/source links. Do not mark the goal complete before final performance/stability gates. The 13 unsupported raw entries are permitted by the objective's missing-data rule and must remain visibly unsupported, not counted as completed.

## Build and run

```sh
python3 scripts/bootstrap.py --with-godot
python3 scripts/build_catalog.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCHEMLAB_BUILD_GODOT=ON
cmake --build build --parallel 4
python3 scripts/verify.py
python3 scripts/build_macos.py
open dist/ChemLab.app
```

Actual app executable comes from Info.plist: `ChemLab · 观物实验室`. Exported runtime disables path overrides; use opt-in bundled `--chemlab-benchmark=ABSOLUTE_JSON` plus `--chemlab-smoke-only` for its headless checks, not `--main-pack` or an external `--script`.

## Preserve these technical decisions

- phreeqc.dat is Latin-1; hash original bytes. Product loads FileAccess resource bytes and LoadDatabaseString, so PCK works. Reject mismatches and IPhreeqc warnings, including exit-zero warnings.
- Source-scoped `token=chemlab_phreeqc_transport_token` only for IPhreeqc transport.cpp resolves a C symbol collision with godot-cpp. Exceptions enabled; slim build profile includes FileAccess/OS/Image/WorkerThreadPool/XMLParser/RefCounted. Chinese native errors use String::utf8.
- Homogeneous aliquots scale upstream cxxSolution state; rewrite extensive RAW fields at 17 digits because upstream DUMP uses 14. Keep intensives/valence, fold microscopic remainder into actual transfer. Different compositions use IPhreeqc MIX plus H/O/element/valence guards.
- Closed CO2 uses explicit ideal-gas phase with exact same database equilibrium coefficients, avoiding upstream Peng–Robinson low-pressure volume clipping. Original DB untouched.
- ReflectionProbe caused seven leaked Texture RID warnings on this engine/Metal configuration and was removed; orphan initial physics mesh fixed too.
- UI screenshots may use force_draw/force_sync to handle occlusion. FPS benchmark never forces draws in measured segments, checks actual image size (not the texture getter, which reports stretched dimensions), records real frame_post_draw intervals and external RSS. Wrapper ensures source identity is unchanged and packaged source receipt matches.
- Heater controls are timestamped on 1/120 s ticks. Restore canonicalizes timestamps to those ticks to eliminate sub-ULP ghost turn/CSV residual differences. At most 512 control records; each sample retains its control-prefix length so same-tick controls replay correctly. CSV uses at most ten significant digits; that is an export convention, not an accuracy claim.
- Session tests must wait for simulation time for sampled curves, not a fixed number of process frames (occluded apps can process many frames before 0.05 s elapses).
- Official macOS template downloaded by HTTP Range for only ~117 MiB member, CRC and locked SHA checked. lipo creates arm64 local template; export binary_format/architecture, Xcode codesign=3 and identity '-'. No global template install; binaries/downloads/logs are ignored.

Data/model limits and verification are in SUPPORT_MATRIX, VALIDATION_SCOPE, AQUEOUS_EXTENSION, HEATING_AND_STIRRING, VISUAL_MODEL and DELIVERY_STATUS. N/Fe/Cu candidates showed unapproved valence changes; selected DB lacks silver/acetate and certain solids. Do not merge databases or enable these raw entries without independently validated models/data.
