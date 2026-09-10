#!/usr/bin/env python3
"""Compare the shipping C++ solver against committed independent Cantera HP runs."""
import csv,json,subprocess,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
executable=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'build/combustion_test'
run=subprocess.run([str(executable)],check=True,text=True,capture_output=True)
rows=[[float(x) for x in row] for row in csv.reader(run.stdout.splitlines())]
references=json.loads((ROOT/'data/combustion-reference.json').read_text())
assert len(rows)==len(references)==20
max_t=max_n=0
for row,ref in zip(rows,references):
    assert row[:2]==[ref['source'],ref['excess']]
    assert all(math.isfinite(x) for x in row)
    max_t=max(max_t,abs(row[2]-ref['temperature_k']))
    max_n=max(max_n,max(abs(a-b) for a,b in zip(row[5:],ref['products'].values())))
    assert abs(row[3])<0.01 and abs(row[4])<1e-8
assert max_t<0.0002 and max_n<1e-7,(max_t,max_n)
print(f'PASS: 20 independent Cantera 3.2.0 HP references; maximum temperature difference {max_t:.6g} K, species difference {max_n:.6g} mol per mol fuel')
if '--receipt' in sys.argv:
    (ROOT/'artifacts/combustion-validation.json').write_text(json.dumps(dict(reference='Cantera 3.2.0; same NASA7 species subset; liquid-ethanol enthalpy offset',cases=20,max_temperature_error_k=max_t,max_species_error_mol=max_n),indent=2)+'\n')
