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
  Real observation-only rod prop is present; stirring kinetics remain unsupported.
- Phase 2: first nine reagents are operational ONLY as water/prepared dilute aqueous forms.
  Concentrations 1e-5–0.01 mol/L, initial volumes 1–250 mL, 25 C. Solution volume is solved
  iteratively for solvent mass, not equated to kg. MIX uses full SOLUTION_RAW snapshots and
  checks Na/Cl/K/Ca/Mg/C/S/N/Ba/Fe/Cu and total H/O conservation. Empty/full/overdraw checks.
  IDs 2–6 may mix; 7–9 only self/water, otherwise reject pending validated gas/solid models.
  Three sourced indicator approximations added; trace addition ignored; phenolphthalein range guarded.
  PHREEQC worker requests serialize; reset generation discards stale results; errors keep valid state.
- Phase 3: C++ FreeFall fixed-step clock and analytic impact event, Godot sphere/ruler/control panels,
  parameter editing, release/pause/resume/repeat, height/speed curves and chemistry/physics mode tabs.
  `mechanics_test` and rendered `fall_flow.gd` pass; screenshot artifacts/free-fall.png.
  Post-impact velocity is zero with impact speed reported separately. See docs/PHYSICS_MODELS.md.

- Phase 4 partial: Fresnel glass, bounded damped liquid-surface slope, seeded 256px procedural
  wood/stone materials and reduced lighting. Liquid numerical amount never comes from visuals.
  Avoid ReflectionProbe on this Metal Mobile build: it caused 7 leaked Texture RID warnings on shutdown;
  removed it, reran all render flows without warnings. Pour stream/pose still needs refinement.
- Phase 5 partial: 17/30 total now verified. Added finite CO2, Calcite and Gypsum in dedicated batch UI,
  closed liquid/solid, ideal closed CO2 volume, fixed external CO2, real remaining solids, gas/element ledger,
  filtered liquid extraction and empty-vessel aliquots. 108 condition sets with repeat and transfer checks;
  USGS gypsum and independent Henry/Ka references; full rendered UI tested. See docs/BATCH_EQUILIBRIUM.md.
  Batch sample provenance prevents unverified remixing/dilution. Reset clears batch UI and state.

## Tests and commands

```sh
python3 scripts/bootstrap.py --with-godot
python3 scripts/build_catalog.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCHEMLAB_BUILD_GODOT=ON
cmake --build build --parallel 4
python3 scripts/verify.py
tools/Godot.app/Contents/MacOS/Godot --headless --editor --path godot --import
tools/Godot.app/Contents/MacOS/Godot --headless --path godot --script tests/native_smoke.gd
tools/Godot.app/Contents/MacOS/Godot --path godot --script tests/visual_flow.gd
tools/Godot.app/Contents/MacOS/Godot --path godot --script tests/fall_flow.gd --quit-after 1800
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
2. Phase 3 free fall is implemented and tested; maintain regression while adding other experiments.
3. Phase 4 improve realism (current materials are an early approximation, not photoreal validation).
4. Phases 5/6 expand supported validated scope beyond the 17 entries; basic CO2 now works. Selected DB lacks silver,
   acetate, Portlandite, Brucite, Chalcanthite etc. Keep unsupported or validate a coherent alternative;
   never splice databases or promise arbitrary mixing. Gas bubbles/solids must derive from solver amounts.
5. Phase 7 spring/pendulum/heat/DC/optics, independently validated models and full UI workflows.
6. Phase 8 transactional save/load including model/database versions, action log, CSV export.
7. Phase 9 1920x1080 editor AND packaged runtime performance, stress/memory, export app and documentation.

No performance claim yet. No 30-material or full phase-completion claim. The present original code
and source lock are on main; build/download caches and local environment identifiers are ignored.

Batch solver finding: upstream PR EOS clips V_m at 1e4 L/mol, giving a low-pressure floor.
Use the explicit CO2_ideal(g) copy of the exact pinned database equilibrium parameters (no EOS critical
parameters); test PV=nRT. No upstream source/database edits. Do not silently revert to PR gas path.
`artifacts/verification.json` is a reproducible test receipt, NOT a performance benchmark.

Aqueous expansion: 11/14/15/16/25 now operational as prepared stocks. 45 parameter sets,
repeated transfers and 14 UI reagent flows pass. Sulfuric acid and sodium sulfate may join
2–6 acid/base/salt mixtures; Mg/Ba stocks only self/water. Candidate N/Fe/Cu automatic-MIX
valence audit failed; raw audit file retained, these forms remain disabled pending dedicated models.
Pure aliquots now scale extensive upstream cxxSolution state instead of re-equilibrating redox;
composition_key allows recombining identical aliquots. H/O/water RAW scalars roundtrip 17 digits.
Valence amounts checked separately on actual mixtures. See docs/AQUEOUS_EXTENSION.md.
Fixed catalog buttons: enabled state derives from registry, no longer hard-coded id<=9.

Phase 6 partial: dedicated BaCl2/Na2SO4 → Barite equilibrium UI and C++ model.
27 native condition sets plus rendered barite_flow pass (including no precipitate below saturation,
limiting-ion excess, extraction/aliquot). Source of current solid volume is solver amount × database Vm.
Total remains 17/30 (no new raw entry counted). See docs/PRECIPITATION.md.
Next proceed Phase 7 physics models/UI; sources consulted OpenStax SHM, pendulum, calorimetry,
resistor series/parallel, thin lenses. Phase 8/9 still unimplemented.

Phase 7 implemented: src/science/physics_models.* (spring, small-angle pendulum, two-water
thermal exchange, series/parallel DC, thin lens real/virtual/infinite), LabCore bench methods,
godot/scripts/physics_experiment.gd with parameter/simulation/measurement/curve/3D flow.
physics_models_test passes independent relationships, conserved energy, frame-step independence.
physics_flow passed native-to-visual transforms and complete controls; float input comparison uses
tolerance (SpinBox value is not exactly decimal 0.2). Fixed native errors to String::utf8 so Chinese
invalid-parameter errors render correctly. Added dark optics board for contrast. Readings remain unchanged
on invalid configuration. Five screenshot artifacts physics-*.png. All 7 CTest cases and native/import/six rendered flows pass without error/leak warnings.
Fixed an orphan initial MeshInstance3D in physics view (allocated before parenting and overwritten).
This milestone is ready for push.
Next: Phase 8 durable save/load/replay & CSV, then full Phase 9 packaging/performance/stress.
Remaining early-phase concerns: continuous-pour real UI regression; indicator boundary tests;
pour pose/stream realism and vessel liquid clipping under tilt are still approximations.
