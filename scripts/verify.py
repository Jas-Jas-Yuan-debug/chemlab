#!/usr/bin/env python3
"""Run bounded scientific and real-renderer flows; Godot exit 0 alone is insufficient."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
from source_fingerprint import source_fingerprint
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--native-only', action='store_true')
args = parser.parse_args()
godot = str(ROOT / 'tools/Godot.app/Contents/MacOS/Godot')
checks = [('native', ['ctest','--test-dir','build','--output-on-failure'], '100% tests passed')]
if not args.native_only:
    checks += [('import', [godot,'--headless','--editor','--path','godot','--import'], 'Godot Engine')]
    for flow in ['native_smoke','session_native','visual_flow','fall_flow','batch_flow','barite_flow','physics_flow','session_flow','pouring_flow','heater_flow','beginner_flow','reaction_dynamics_flow','reaction_clock_flow']:
        command = [godot]
        if flow in ['native_smoke','session_native']: command += ['--headless']
        command += ['--path','godot','--script',f'tests/{flow}.gd','--quit-after','12000']
        checks.append((flow,command,'PASS:'))
receipt = {'source_sha256':source_fingerprint(),'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'checks':[],
    'database_sha256':hashlib.sha256((ROOT/'godot/data/phreeqc.dat').read_bytes()).hexdigest()}
try:
    for name, command, marker in checks:
        start = time.monotonic()
        try:
            process = subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
            output = process.stdout
            returncode = process.returncode
        except subprocess.TimeoutExpired as error:
            output = error.stdout or ''
            if isinstance(output,bytes):output=output.decode('utf-8',errors='replace')
            output += '\nFAIL: verification exceeded 90-second bound\n'
            returncode = 124
        (ROOT/'artifacts'/f'verify-{name}.log').write_text(output)
        passed = returncode == 0 and marker in output and not any(s in output for s in ['SCRIPT ERROR:', 'ERROR:', 'FAIL:', 'were leaked'])
        receipt['checks'].append({'name':name,'passed':passed,'duration_s':round(time.monotonic()-start,3),
            'evidence':[line for line in output.splitlines() if 'PASS:' in line or '100% tests passed' in line]})
        print(('PASS' if passed else 'FAIL')+': '+name,flush=True)
        if not passed:
            print(output)
            raise RuntimeError('Verification failed: '+name)
finally:
    (ROOT/'artifacts/verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
