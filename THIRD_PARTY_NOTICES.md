# Third-party notices

The original ChemLab code is licensed under **AGPL-3.0-only** (see `LICENSE`).
This does not replace the licenses of dependencies, databases, fonts, or other assets.

## PHREEQC / IPhreeqc 3.8.6-17100

Authors: David L. Parkhurst, C. A. J. Appelo, Scott R. Charlton, and contributors;
U.S. Geological Survey. PHREEQC is used for aqueous geochemical equilibrium calculations.
No endorsement by USGS is implied.

- Original source distribution: https://water.usgs.gov/water-resources/software/PHREEQC/iphreeqc-3.8.6-17100.tar.gz
- Rights notice: [USGS-PHREEQC-NOTICE.txt](third_party/licenses/USGS-PHREEQC-NOTICE.txt)
- Embedded SUNDIALS notice: [SUNDIALS-NOTICE.txt](third_party/licenses/SUNDIALS-NOTICE.txt)
- The downloaded source and database are unmodified. Version and hashes are in `dependencies.lock.json`.
- Build adaptation by ChemLab, 2026-09-09: only `transport.cpp` is compiled with `token=chemlab_phreeqc_transport_token` to prevent collision with godot-cpp's C symbol `token`. No chemistry parameters or numerical code are changed; the original source distribution remains available above.
- Databases `phreeqc.dat` and `pitzer.dat` retain their original headers, reaction parameters, literature references, and notices. They come from the same pinned distribution and are loaded in separate engine instances; their data are not merged. `pitzer.dat` SHA-256: `06ab2debc0cdb333598118df953165499c2f762a79de5f2df55dec6b78b02589`.
- Parkhurst and Appelo (2013), USGS Techniques and Methods 6-A43: https://doi.org/10.3133/tm6A43
- Charlton and Parkhurst (2011), Computers & Geosciences 37:1653–1663: https://doi.org/10.1016/j.cageo.2011.02.005

## Godot / godot-cpp

Godot is MIT licensed. Its MIT notice and all relevant bundled third-party notices
must accompany any redistributed runtime. https://godotengine.org/license/
Pinned version and source are recorded in `dependencies.lock.json`.
The downloaded engine is 4.7.2-stable; bindings target the older compatible 4.5 API.
Godot runtime license and component notices are copied from its own Engine API:
[engine license](third_party/licenses/GODOT-ENGINE-LICENSE.txt),
[component notices](third_party/licenses/GODOT-THIRD-PARTY.json),
[C++ bindings license](third_party/licenses/GODOT-CPP-LICENSE.txt).

No external models, textures, or fonts have been added at this stage.

## Combustion thermochemical data

The 16 NASA7 species coefficient sets in `data/combustion-thermo.json` and the
corresponding generated C++ include are derived from Cantera v3.2.0
`data/nasa_gas.yaml` (NASA TM-4513, McBride, Gordon and Reno, 1993). The Cantera
BSD-3-Clause notice is retained in `third_party/licenses/Cantera-LICENSE.txt`.
The runtime Gibbs solver, field solver, geometry and rendered apparatus thumbnails
are original ChemLab code/assets under AGPL-3.0-only. Cantera is used only as an
independent validation dependency, not bundled as a runtime library.

The liquid-ethanol enthalpy offset uses the Majer and Svoboda (1985) vaporization
enthalpy correlation reported by NIST Chemistry WebBook SRD 69. The specific
correlation and source link are documented in `docs/expansion/SCIENTIFIC_MODELS.md`.
No NIST website code or artwork is redistributed. No artwork from the user-supplied
NOBOOK screenshots is embedded in the application.
