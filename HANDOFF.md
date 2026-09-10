# ChemLab handoff

Updated 2026-09-10 for version 0.2. Follow `docs/GOAL_OBJECTIVE.md` and the user's approved Godot / AGPL changes. User explicitly requested commit, push, and README updates. Public repository: https://github.com/Jas-Jas-Yuan-debug/chemlab, branch main.

## Current implementation

- Godot 4.7.2, C++17 and IPhreeqc 3.8.6; Apple Silicon native build. Pinned original PHREEQC database remains unchanged. The supported reagent count remains 17/30; concentration and kinetics scope has expanded; unsupported chemistry stays explicit.
- Beginner front-view workspace alongside the professional 3D room: search, categories, large cards, matching apparatus shapes, finite dry-material transfer, weighing, liquid preparation/pouring, indicators, connection graph, attachments, timer, heating, reports, save/load.
- 173 apparatus entries (81 original procedural geometry families and generated thumbnails), 143 solid packages (142 from the 15 chemical screenshots plus existing gypsum), and the original 30 reagent entries. All 35 reference screenshots are represented in the catalogs; repeated screenshots/packages are de-duplicated while physical forms remain distinct.
- Catalog availability is not full chemical/physical behavior. Gas-network flow, dedicated drying/scrubbing/condensation, NO2 equilibrium, conductivity, spectra and arbitrary solid reactions remain unsupported. See `docs/expansion/SCIENTIFIC_MODELS.md`; don't describe all 143 packages as reactive chemicals.
- Independent bulk combustion for liquid ethanol, methane, hydrogen/oxygen and acetylene/oxygen: Gibbs element-potential equilibrium, 16 NASA7 species from one Cantera 3.2.0 data source, liquid-ethanol vaporization offset, finite per-source fuel, oxygen/products and energy budgets. Water capture fraction is a declared fixed 35%, not a measured device efficiency.
- Optional 16 x 28 x 16 reactive flow at 1/120 s: premixed inlet, conservative scalar fluxes, approximate incompressible velocity, empirical mixing-limited one-step reaction and local temperature volume rendering. Not detailed kinetics, calibrated burner CFD, soot, explosion or real radiation spectra. One-way diagnostic field; switching it off retains bulk heating history.
- Model version `aqueous-0.3+kinetics-0.1+batch-0.1+barite-0.1+physics-0.3+combustion-0.1`; old model-version sessions reject explicitly. Save/load preserves beginner objects, connections, dry inventories and optional full field, loading paused. Professional model switching must not restore a stale beginner heater view (covered by beginner_flow regression).

## September 10 corrective work

- Distinct Griffin beaker/spout/graduations and shoulder/neck/stopper reagent bottle, shared profile geometry, volume-integrated liquid clipping, smooth glass normals. New beginner glassware and three corresponding thumbnail families. Approximate dimensions and optical limits are in `docs/REACTION_DYNAMICS.md`.
- IDs 2–6 support 1e-5–1 M initial solutions. Above 0.01 M use separate original `pitzer.dat` from the same pinned IPhreeqc archive; no database merging. Pitzer mixtures stay in Pitzer and only allow water/IDs 2–6. Other supported reagents still max 0.01 M. Both beginner and professional concentration fields are adjustable.
- Native two-zone H+/OH- mass-action kinetics with exact local integration, symmetric finite exchange and representative aliquots. Dilute 25 C k=1.4e11 L/(mol s); high-I rate extrapolation uncalibrated. This is NOT 3D reactive CFD or RPM-derived mixing. Q is user model input. No thermal coupling or arbitrary reaction kinetics.
- Three plots use current selected vessel: probe pH/time, rate/time, source-isolated final-equilibrium titration. Source/receiver reprepare and source switch split titration series. Dynamics use integrated vessel time, never UI wall time or solver wait. Busy/paused frames produce no reaction samples.
- Session saves kinetic inventory/time/thermodynamic closure and sampled history; chemistry journal replays, final dynamic state is cross-checked. Full Q history is not recorded: past kinetic samples are validated for bounds/order, not independently recomputed. Both database hashes checked; CSV roundtrip covered.
- Four targeted corrections checks plus one final headless empty-source boundary check passed; see `artifacts/reaction-dynamics-validation.json`. No full-suite or benchmark repeats. A GDScript formatting error and clock/readout corrections were handled with focused checks. Current future full verify registration is 10 native plus import and 13 flows; historical `verification.json` remains untouched and incomplete.

## Evidence and delivery

The user explicitly said "stop running the same test everytime". Do not repeat suites or performance runs without a concrete need and new authorization. Prior full expansion suite and focused beginner save regression passed. Latest suite stopped at physics_flow without PASS; editor benchmark ended -15; initial packaged performance failed in chemistry/vessel scenes. Final full-suite and all-scene 30 FPS are NOT claimed. See `artifacts/expansion-validation.json` and `docs/PERFORMANCE.md`. Continue commit/documentation work; do not disguise partial receipts as passes.

- `artifacts/verification.json`: latest incomplete verification attempt, 9 CTest cases, Godot import and 11 runtime flows (2 headless, 9 rendered). Native combustion compares all 20 independently generated Cantera reference cases. Field tests check fuel/energy conservation, source changes, cooling, frame partition consistency and snapshot replay.
- `artifacts/combustion-validation.json`: 20 cases, maximum numerical temperature difference about 6.22e-7 K and species difference 3.48e-10 mol/mol fuel. This compares implementations using the same thermochemical data, not experimental flame accuracy.
- `artifacts/build-receipt.json`: source fingerprint, exported files, native arm64 architecture and strict ad-hoc signature verification. Local `dist/ChemLab.app` is ignored, not notarized and not a GitHub Release asset.
- `artifacts/performance-editor-run.json`, `artifacts/performance-packaged.json`, `docs/PERFORMANCE.md`: current actual 1920x1080 frame callbacks, external RSS and lifecycle results. Do not reuse the old fae1e5b 193-cycle/600-second result as evidence for 0.2. A short extension run does not establish a ten-minute endurance result.
- Initial extension performance attempt exposed a stale heater-view load error; fixed and regression-tested. Benchmark now explicitly fails if any scene misses the documented P99/minimum-complete-second 30 FPS criterion, in addition to checking sample count and lifecycle conservation. Source and packaged receipts must match.

## Build and run

```sh
python3 scripts/bootstrap.py --with-godot
python3 scripts/build_catalog.py
python3 scripts/build_apparatus_catalog.py
python3 scripts/build_material_catalog.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCHEMLAB_BUILD_GODOT=ON
cmake --build build --parallel 4
python3 scripts/verify.py
python3 scripts/build_macos.py
open dist/ChemLab.app
```

Cantera is only an optional development reference generator, not a runtime dependency. `tools/combustion-venv` holds the local pinned validation environment. Generated data, reference values and original thumbnails are committed. Use `scripts/generate_combustion_data.py` only when intentionally regenerating the pinned data, and rerun independent checks after any change.

Actual exported executable name is in Info.plist. Its opt-in bundled benchmark supports `--chemlab-benchmark=ABSOLUTE_JSON`, `--chemlab-phase-seconds=6`, `--chemlab-stress-seconds=30`, or `--chemlab-smoke-only`; normal launch performs no benchmark file activity. Do not run builds/tests concurrently with performance measurement.

## Preserve these technical decisions

- phreeqc.dat is Latin-1; hash original bytes. Product loads FileAccess resource bytes and LoadDatabaseString, so PCK works. Reject mismatches and IPhreeqc warnings, including exit-zero warnings.
- Source-scoped `token=chemlab_phreeqc_transport_token` only for IPhreeqc transport.cpp resolves a C symbol collision with godot-cpp. Exceptions enabled; slim build profile includes FileAccess/OS/Image/WorkerThreadPool/XMLParser/RefCounted. Chinese native errors use String::utf8.
- Homogeneous aliquots scale upstream cxxSolution state; rewrite extensive RAW fields at 17 digits because upstream DUMP uses 14. Keep intensives/valence, fold microscopic remainder into actual transfer. Different compositions use IPhreeqc MIX plus H/O/element/valence guards.
- Closed CO2 uses explicit ideal-gas phase with exact same database equilibrium coefficients, avoiding upstream Peng–Robinson low-pressure volume clipping. Original DB untouched.
- ReflectionProbe caused seven leaked Texture RID warnings on this engine/Metal configuration and was removed; orphan initial physics mesh fixed too.
- UI screenshots may use force_draw/force_sync to handle occlusion. FPS benchmark never forces draws in measured segments, checks actual image size (not the texture getter, which reports stretched dimensions), records real frame_post_draw intervals and external RSS. Wrapper ensures source identity is unchanged and packaged source receipt matches.
- Heater controls are timestamped on 1/120 s ticks. Restore canonicalizes timestamps to those ticks to eliminate sub-ULP ghost turn/CSV residual differences. At most 512 control records; each sample retains its control-prefix length so same-tick controls replay correctly. CSV uses at most ten significant digits; that is an export convention, not an accuracy claim.
- Stress replay compares the solved pre-save volume and each element, not nominal added volume: two 25 mL dilute acid/base aliquots solve to 50.0005538988 mL. Zero-ID fixed vessels (batch/heater) cannot intercept chemistry picks; unknown inventory IDs are rejected.
- Session tests must wait for simulation time for sampled curves, not a fixed number of process frames (occluded apps can process many frames before 0.05 s elapses).
- Official macOS template downloaded by HTTP Range for only ~117 MiB member, CRC and locked SHA checked. lipo creates arm64 local template; export binary_format/architecture, Xcode codesign=3 and identity '-'. No global template install; binaries/downloads/logs are ignored.

Data/model limits and verification are in SUPPORT_MATRIX, VALIDATION_SCOPE, AQUEOUS_EXTENSION, HEATING_AND_STIRRING, VISUAL_MODEL and DELIVERY_STATUS. N/Fe/Cu candidates showed unapproved valence changes; selected DB lacks silver/acetate and certain solids. Do not merge databases or enable these raw entries without independently validated models/data.
