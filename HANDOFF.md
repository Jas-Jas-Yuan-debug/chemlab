# ChemLab handoff

Updated 2026-09-09. Continue `docs/GOAL_OBJECTIVE.md`; goal remains active.

## Immediate user constraint

**User has now explicitly said "now you can run the tests". Window tests are authorized again.** The earlier ten-minute pause was honored; the user confirmed that they manually closed the interrupted benchmark windows while using the computer. Those SIGTERM interruptions are not evidence of application crashes. Preserve later user steering.

## Authorization and repository

User approved Godot instead of Unreal, keeping AGPL-3.0; explicitly requested Git and a public repository named `chemlab`. Repo https://github.com/Jas-Jas-Yuan-debug/chemlab is public, main, recognized AGPL-3.0. Do not ask again. Latest pushed milestone is `9d12dff` (session replay and CSV). Current working tree contains later visual, packaging and benchmark work; preserve it. No paid resources, Unreal installation or global Godot install.

## Implemented and actually verified

- Godot 4.7.2 official portable macOS engine, godot-cpp 4.5 API commit, IPhreeqc 3.8.6-17100, original phreeqc.dat: pinned hashes, native arm64 build and execution.
- Room, scaled glass containers, orbit/zoom/focus, select/drag with grab offset, table bounds and collision rejection, beaker/cylinder/dropper/bottle addition, Chinese search/category/controls/readouts. CUA real mouse selection/drag/overlap/focus/reset was checked earlier. Stirring rod is an observation prop, clearly labeled.
- 17/30 raw reagents operational, without double counting forms: water/prepared aqueous IDs 1–9,11,14,15,16,25; dedicated CO2 10, Calcite 18, Gypsum 19. Ordinary mixtures restricted to validated scopes. Dedicated BaCl2 + Na2SO4 Barite precipitation, undersaturation and excess checks. Independent solid/gas/aqueous inventories; filtered liquid may only transfer to empty vessels.
- Pure homogeneous aliquots scale extensive raw state and keep pH/valence. Different compositions still use IPhreeqc MIX and element/H/O/valence guards. No reaction rates, arbitrary redox, combustion or spatial concentration model.
- Free fall plus spring, small-angle pendulum, isolated two-water heat exchange, series/parallel DC, thin lens. C++ 1/120 s clocks, analytical checks, pause/repeat, same state for geometry/readings/curves. All six UI flows tested.
- Versioned JSON session, white-listed native replay, geometry/indicator/camera/curve restoration, CSV, paused load, invalid-file/failed-replay state preservation. `session_native` and rendered `session_flow` passed, including the CSV precision adjustment and byte-identical save/load export.
- New controlled pour pose: move source lip above receiver, gravity-level clipped liquid surface, canonical volume. `pouring_flow` passed held-button transfer, horizontal surface, actual triangle-volume approximation, empty/release stops, chloride conservation, indicator boundaries.
- Full `scripts/verify.py` at 2026-09-09 12:33:14 UTC passed 7 CTest cases, import, native/session and all eight rendered flows, including pouring, About/wide-window changes and CSV canonicalization. No ERROR/leak warnings. Only the opt-in benchmark/headless delivery harness changed afterward.
- Official macOS template member downloaded alone (~117 MiB via HTTP range; CRC + pinned extracted SHA-256). `scripts/build_macos.py` extracted arm64 from official universal binaries, exported an ~86 MiB standalone app, copied license notices, ad-hoc signed and verified. The app was rebuilt at 12:40:58 UTC with the latest visual/CSV/benchmark changes. Exported release headless smoke from `/tmp` verified PCK/native initialization, neutralization, chloride conservation, Barite, heat energy, save/load and paused restoration; `artifacts/packaged-smoke.json` has no failures. This is not a rendered performance result.

## Current work / remaining delivery gates

1. User added adjustable-temperature heating equipment and stirring, and reminded us to commit. Implement a controllable magnetic stirring hotplate with a validated water energy model, independent heater/motor switches and saved control history; then run updated checks and performance. User explicitly authorized tests again.
2. Benchmark actual 1920x1080 image, editor game run with editor UI open and independent exported release runtime. **Editor-run benchmark now passed all nine scenes at about 60 FPS, p99 17.3–18.2 ms, minimum complete second 59–60 FPS.** See `artifacts/performance-editor-run.json`; this predates the newly requested heater/stirrer. Packaged performance is still pending. Early runs were manually closed by the user (SIGTERM -15), without receipt. Do not interpret partial segment logs as passing evidence.
3. `get_viewport().get_texture().get_size()` misleadingly reports (2075,1167) for a 1920x1080 physical window with stretch. Actual `get_texture().get_image().get_size()` was verified (1920,1080). Benchmark now checks the real image once before measurement, and counts actual `frame_post_draw` timestamps without forced renders in measured segments. Project uses canvas_items + expand, side panels now anchored for wide windows.
4. App is rebuilt and headless-smoke verified; use `scripts/benchmark.py --packaged --stress-seconds 180` (or longer) for lifecycle/memory testing. Default editor run is `python3 scripts/benchmark.py --stress-seconds 0`. Script owns and cleans its editor process. Each mode runs nine measured scene segments and records external RSS once per second; packaged mode also repeats reset/neutralize/save/load/model changes. Report failure if interrupted or incomplete.
5. Finalize performance/stability and build receipts, application startup instructions, known visual/model limitations; push verified changes. Source/repo and local .app should be delivered. Do not mark goal complete before these gates.

## Technical findings to preserve

- `phreeqc.dat` is Latin-1; compare/hash original bytes. Product uses Godot FileAccess bytes and `LoadDatabaseString` so PCK loading works. Hash mismatch is an error.
- IPhreeqc may return warning with exit zero; wrapper rejects warnings. Unknown species must not silently disappear.
- Upstream `transport.cpp` and godot-cpp both export C `token`: a source-scoped compile definition renames only the IPhreeqc translation unit. Keep this adaptation.
- godot-cpp needs exceptions enabled and slim profile OS/FileAccess/Image/WorkerThreadPool/XMLParser/RefCounted. Native Chinese errors use `String::utf8`.
- IPhreeqc raw DUMP uses 14 digits. Homogeneous aliquot H/O/water/volume fields are rewritten at 17 digits after upstream cxxSolution scaling. Microscopic remainder is folded into actual transfer, not re-solved as 1e-20 L or silently discarded.
- Low-pressure upstream Peng–Robinson volume clips at 1e4 L/mol. Closed gas uses explicit `CO2_ideal(g)` with exact same database equilibrium coefficients and no EOS critical parameters; PV=nRT checked. Original database untouched.
- ReflectionProbe caused seven leaked Texture RID warnings on this engine/Metal configuration, so it was removed. Fixed an unparented initial physics MeshInstance3D allocation too. Last full render check had no leaks/errors.
- Screenshots in automated UI flows use explicit force_draw(false)/force_sync before reading pixels: waiting for frame_post_draw can hang if an app is occluded. **These are screenshot checks, not FPS measurements.** Benchmark avoids force draw in measured segments and checks enough actual frames.
- `JSON.stringify(... full_precision=true)` / parse can shift final floating-point bits; a batch parameter 0.00042 and elapsed times exposed byte differences in CSV. New CSV formatting canonicalizes at most ten significant digits and scalar parameter JSON; passed the complete post-pause regression. Numerical state comparison remains tolerance-based.
- Godot arrays/dictionary keys distinguish int and float in some membership operations. JSON IDs are validated then converted to int; do not use float directly to look up vessel keys.
- Official template archive only has `.universal` names, while arm64 export requests `.arm64`. Build script uses lipo on those official binaries to make a project-local arm64 template. Export uses `binary_format/architecture`, codesign=3 (Xcode, identity `-`), not 2 (rcodesign). ETC2/ASTC import enabled. No Developer ID/notarization is configured.

## Build / verify commands

```sh
python3 scripts/bootstrap.py --with-godot
python3 scripts/build_catalog.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCHEMLAB_BUILD_GODOT=ON
cmake --build build --parallel 4
python3 scripts/verify.py
python3 scripts/build_macos.py
```

`artifacts/verification.json` records scientific/UI regressions, not performance. Test scripts require PASS markers and no SCRIPT ERROR/ERROR/leak warnings, because Godot may exit zero on script failures. Build/download caches, binaries, logs and local environment records are ignored.

## Unsupported scope

13 raw entries remain disabled. Selected DB lacks silver/acetate and certain requested solid phases; N/Fe/Cu automatic MIX candidate audit showed unapproved valence changes. Pure aliquot fix does not establish valid dilution, redox or solid-phase behavior for those candidates. Preserve audit evidence and explain these limitations; do not combine databases or count unverified items. See SUPPORT_MATRIX, AQUEOUS_EXTENSION and VISUAL_MODEL. Visual verification supports geometry/readout/interaction consistency; it is not photoreal optical calibration.
