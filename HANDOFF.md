# Current state / handoff

Updated 2026-09-09. Keep following `docs/GOAL_OBJECTIVE.md` through Phase 9.
User explicitly approved replacing Unreal with Godot to retain AGPL-3.0, and
explicitly requested a **public** GitHub repository. Do not ask again for those decisions.
Repository: https://github.com/Jas-Jas-Yuan-debug/chemlab (public, main, AGPL-3.0).
Use Git; push meaningful verified stages. No unapproved paid resources or large installs.

## Verified now

- Phase 0: original directory empty; environment and license decisions recorded.
  Godot 4.7.2 portable official macOS binary SHA checked, arm64 startup verified.
  godot-cpp 4.5 API pinned commit works in that runtime. IPhreeqc 3.8.6 pinned
  original source and `phreeqc.dat` independently built and executed in arm64.
  All 30 catalog entries have phase/hydration/formula weight/composition/mapping/source/status.
- Phase 1 foundation: rendered 3D room, physical-scale containers, glass shells,
  four selectable vessels, orbit/zoom/focus, table-plane dragging with collision rejection,
  add beaker/cylinder/dropper/bottle, Chinese material search/controls/readouts.
  CUA mouse testing found and fixed drag events swallowed by GUI: motion/release now in `_input`,
  initial world pick in `_unhandled_input`, with grab offset. Observed move and overlap rejection.
  Rod currently labeled observation-only; refine geometry and implement only justified behavior.
- Phase 2 partial: 9/30 reagent entries operational ONLY as water/prepared dilute aqueous forms.
  Concentrations 1e-5–0.01 mol/L, initial volumes 1–250 mL, 25 C. Solution volume is solved
  iteratively for solvent mass, not equated to kg. MIX uses full SOLUTION_RAW snapshots and
  checks Na/Cl/K/Ca/Mg/C/S/N/Ba/Fe/Cu and total H/O conservation. Empty/full/overdraw checks.
  IDs 2–6 may mix; 7–9 only self/water, otherwise reject pending validated gas/solid models.
  Three sourced indicator approximations added; trace addition ignored; phenolphthalein range guarded.
  PHREEQC worker requests serialize; reset generation discards stale results; errors keep valid state.

## Tests and commands

```sh
python3 scripts/bootstrap.py --with-godot
python3 scripts/build_catalog.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCHEMLAB_BUILD_GODOT=ON
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
tools/Godot.app/Contents/MacOS/Godot --headless --editor --path godot --import
tools/Godot.app/Contents/MacOS/Godot --headless --path godot --script tests/native_smoke.gd
tools/Godot.app/Contents/MacOS/Godot --path godot --script tests/visual_flow.gd
```

`Start ChemLab.command` builds cached sources and launches the scene. No global installation.
Native smoke validates pH, transfer and stale reset. Rendered UI flow exercises nine reagent
preparations/transfers and saves screenshots in artifacts. Inspect logs for SCRIPT ERROR as
Godot may return exit 0 even when a script fails. Native test has 81 stock/aliquot/dilution
iterations (75 distinct initial conditions), independent dilute pH limits, failure guards.

## Integration findings

- `phreeqc.dat` is Latin-1; hash bytes, decode Latin-1 for the coverage scanner.
- PHREEQC can report an unknown species as warning instead of nonzero RunString result;
  wrapper rejects warnings as well as errors. Never silently ignore unsupported components.
- IPhreeqc transport.cpp and godot-cpp expose a C symbol `token`. A scoped compilation
  definition renames only the PHREEQC translation unit's token; upstream source unchanged,
  adaptation disclosed in THIRD_PARTY_NOTICES. Do not remove this (previously caused crash).
- godot-cpp slim profile needs OS, FileAccess, Image, WorkerThreadPool, XMLParser as well as
  RefCounted. Enable exceptions on this extension build; catch chemistry exceptions before API return.
- Tiny floating point remainder after emptying must be included in actual transfer, not
  solved as a fictitious 1e-20 L solution or discarded. Covered by repeat-transfer test.

## Remaining work (goal NOT complete)

1. Finish Phase 1/2 usability and indicators tests, continuous-pour UI regression and visual motion.
2. Phase 3 free fall: C++ fixed step clock, configurable height/gravity, measurements/curve, pause/reset.
3. Phase 4 improve realism (current materials are an early approximation, not photoreal validation).
4. Phases 5/6 gas/finite-solid models; CO2 is still missing from base ten. Selected DB lacks silver,
   acetate, Portlandite, Brucite, Chalcanthite etc. Keep unsupported or validate a coherent alternative;
   never splice databases or promise arbitrary mixing. Gas bubbles/solids must derive from solver amounts.
5. Phase 7 spring/pendulum/heat/DC/optics, independently validated models and full UI workflows.
6. Phase 8 transactional save/load including model/database versions, action log, CSV export.
7. Phase 9 1920x1080 editor AND packaged runtime performance, stress/memory, export app and documentation.

No performance claim yet. No complete Phase 2 or 30-material claim. The present original code
and source lock are on main; build/download caches and local environment identifiers are ignored.
