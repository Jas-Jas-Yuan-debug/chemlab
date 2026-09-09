#!/usr/bin/env python3
"""Collect actual renderer frame timing and external macOS RSS samples."""
import argparse
import json
from pathlib import Path
import plistlib
import subprocess
import time
from source_fingerprint import source_fingerprint
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--packaged',action='store_true')
p.add_argument('--stress-seconds',type=int,default=180)
args=p.parse_args()
label='packaged' if args.packaged else 'editor-run'
report=ROOT/f'artifacts/performance-{label}.json'
log=ROOT/f'artifacts/performance-{label}.log'
if report.exists():
    # Keep previous evidence while replacing it with the new complete run.
    report.rename(report.with_suffix('.previous-local.json'))
measured_source=source_fingerprint()
editor=None
if args.packaged:
    app=ROOT/'dist/ChemLab.app'
    if json.loads((ROOT/'artifacts/build-receipt.json').read_text())['source_sha256']!=measured_source:
        raise RuntimeError('Packaged app source receipt differs; rebuild before benchmarking')
    with (app/'Contents/Info.plist').open('rb') as f:info=plistlib.load(f)
    command=[str(app/'Contents/MacOS'/info['CFBundleExecutable'])]
else:
    godot=str(ROOT/'tools/Godot.app/Contents/MacOS/Godot')
    editor_log=(ROOT/'artifacts/benchmark-editor-ui.log').open('w')
    editor=subprocess.Popen([godot,'--editor','--minimized','--path',str(ROOT/'godot')],stdout=editor_log,stderr=subprocess.STDOUT)
    time.sleep(5)
    command=[godot,'--path',str(ROOT/'godot')]
command+=['--resolution','1920x1080','--position','10,60','--',f'--chemlab-benchmark={report}',f'--chemlab-stress-seconds={args.stress_seconds}']
rss=[]
started=time.monotonic()
process=None
try:
    with log.open('w') as stream:
        process=subprocess.Popen(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        while process.poll() is None:
            elapsed=time.monotonic()-started
            if editor and editor.poll() is not None:
                raise RuntimeError('Editor UI exited during editor benchmark')
            if elapsed>args.stress_seconds+240:
                process.terminate()
                process.wait(timeout=10)
                raise RuntimeError('Benchmark exceeded bounded duration; inspect log')
            sample={'wall_s':round(elapsed,3)}
            for name,pid in [('runtime',process.pid)]+([('editor_ui',editor.pid)] if editor else []):
                value=subprocess.run(['ps','-o','rss=','-p',str(pid)],text=True,stdout=subprocess.PIPE).stdout.strip()
                if value:sample[name+'_rss_mib']=round(int(value)/1024,3)
            rss.append(sample)
            time.sleep(1)
    text=log.read_text()
    if process.returncode or not report.exists() or 'PASS: packaged/project runtime' not in text or any(x in text for x in ['ERROR:','SCRIPT ERROR:','were leaked','FAIL:']):
        raise RuntimeError(f'Runtime verification failed (exit {process.returncode}); inspect '+str(log))
    data=json.loads(report.read_text())
    data['host']={'chip':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'unified_memory_gib':int(subprocess.check_output(['sysctl','-n','hw.memsize'],text=True))/1024**3,'os':subprocess.check_output(['sw_vers','-productVersion'],text=True).strip()}
    data['rss_samples']=rss
    if source_fingerprint()!=measured_source:raise RuntimeError('Runtime source changed during measurement')
    data['source_sha256']=measured_source
    data['mode']='exported release template' if args.packaged else 'editor game run with editor UI open and minimized'
    data['fps_note']='Intervals between actual frame_post_draw callbacks (engine render timing, not an external display capture); no forced render calls in measured segments. Warm-up and lifecycle transitions excluded.'
    report.write_text(json.dumps(data,indent=2)+'\n')
    print('Verified benchmark:',report)
    for name,row in data['frames'].items():print(name,round(row.get('mean_fps',0),2),'FPS, p99',round(row.get('p99_ms',0),2),'ms')
finally:
    if process is not None and process.poll() is None:
        process.terminate()
        try:process.wait(timeout=10)
        except subprocess.TimeoutExpired:process.kill()
    if editor:
        editor.terminate()
        try:editor.wait(timeout=10)
        except subprocess.TimeoutExpired:editor.kill()
        editor_log.close()
