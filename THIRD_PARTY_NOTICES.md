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
- Database `phreeqc.dat` retains its original header, reaction parameters, literature references, and notice. Other bundled databases are not merged into it.
- Parkhurst and Appelo (2013), USGS Techniques and Methods 6-A43: https://doi.org/10.3133/tm6A43
- Charlton and Parkhurst (2011), Computers & Geosciences 37:1653–1663: https://doi.org/10.1016/j.cageo.2011.02.005

## Godot / godot-cpp

Godot is MIT licensed. Its MIT notice and all relevant bundled third-party notices
must accompany any redistributed runtime. https://godotengine.org/license/
Pinned version, source, and copied notices are added during bootstrap.

No external models, textures, or fonts have been added at this stage.
