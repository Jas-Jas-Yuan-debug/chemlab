#!/usr/bin/env python3
"""Bounded, low-priority real-scene use rounds in an isolated checkout.

Never opens a window, changes HOME, or writes the ordinary experiment user directory.
Reports contain every attempt; a failed round cannot count as complete.
"""
import argparse
import hashlib
import json
import os
import re
import signal
import shutil
import subprocess
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def run_bounded(command,timeout):
    proc=subprocess.Popen(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    try:
        stdout,stderr=proc.communicate(timeout=timeout)
        return subprocess.CompletedProcess(command,proc.returncode,stdout,stderr)
    except subprocess.TimeoutExpired:
        # Only the process group created above belongs to this attempt.
        try:os.killpg(proc.pid,signal.SIGTERM)
        except ProcessLookupError:pass
        try:stdout,stderr=proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            try:os.killpg(proc.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            stdout,stderr=proc.communicate()
        raise subprocess.TimeoutExpired(command,timeout,output=stdout,stderr=stderr)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("rounds",nargs="+",type=int)
    parser.add_argument("--timeout",type=int,default=90)
    args=parser.parse_args()
    if any(i<1 or i>50 for i in args.rounds):parser.error("Round must be 1..50")
    evidence=ROOT/"artifacts/fifty-local"
    evidence.mkdir(parents=True,exist_ok=True)
    config=(ROOT/"godot/project.godot").read_text()
    project=ROOT/"godot"
    if 'config/custom_user_dir_name="ChemLabValidation50-' not in config:
        # Normal checkouts are safe too: synchronize a separate runtime copy.
        project=evidence/"project"
        old_config=project/"project.godot"
        previous=old_config.read_text() if old_config.exists() else ""
        match=re.search(r'config/custom_user_dir_name="(ChemLabValidation50-[^"]+)"',previous)
        user_dir=match.group(1) if match else "ChemLabValidation50-"+uuid.uuid4().hex
        shutil.copytree(ROOT/"godot",project,dirs_exist_ok=True,ignore=shutil.ignore_patterns(".godot","*.import","macos-template.zip"))
        config=re.sub(r'config/name="[^"]+"','config/name="ChemLab Validation"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+user_dir+'"',config,count=1)
        (project/"project.godot").write_text(config)
        imported=run_bounded(["/usr/bin/nice","-n","15",str(ROOT/"tools/Godot.app/Contents/MacOS/Godot"),"--headless","--path",str(project),"--editor","--import","--quit","--max-fps","30","--log-file",str(evidence/"import.engine.log")],90)
        (evidence/"import.log").write_text(imported.stdout+imported.stderr)
        if imported.returncode or "ERROR:" in imported.stdout+imported.stderr:
            raise SystemExit("Isolated project import failed; see artifacts/fifty-local/import.log")
    ledger=ROOT/"artifacts/fifty-rounds.json"
    report=json.loads(ledger.read_text()) if ledger.exists() else {
        "schema":1,"objective":"50 distinct test/use/review/revise rounds without foreground interaction",
        "base_commit":"4360ef5a30a959baad23e9dc9583a419bb0e04ef","created_utc":datetime.now(timezone.utc).isoformat(),
        "method":"Fresh actual Godot scene and real controls/native models, headless dummy renderer, one process at a time, nice 15, maximum 30 frames/s",
        "limitations":["No rendered-image fidelity or FPS claim","No changes to user's ordinary experiment directory","No forced code edits for already-correct behavior"],"attempts":[]}
    for i in args.rounds:
        seq=1+sum(x["id"]==i for x in report["attempts"])
        prefix=evidence/f"round-{i:02d}-attempt-{seq}"
        command=["/usr/bin/nice","-n","15","/usr/bin/time","-l",str(ROOT/"tools/Godot.app/Contents/MacOS/Godot"),"--headless","--path",str(project),"--max-fps","30","--script","res://tests/fifty_runner.gd","--log-file",str(prefix)+".engine.log","--",str(i)]
        start=time.monotonic()
        try:
            proc=run_bounded(command,args.timeout)
            stdout,stderr,code=proc.stdout,proc.stderr,proc.returncode
        except subprocess.TimeoutExpired as exc:
            stdout=exc.stdout or b"";stderr=exc.stderr or b""
            if isinstance(stdout,bytes):stdout=stdout.decode(errors="replace")
            if isinstance(stderr,bytes):stderr=stderr.decode(errors="replace")
            code=-999;stderr+="\nROUND TIMEOUT"
        output=stdout+stderr
        log=Path(str(prefix)+".log");log.write_text(output)
        rows=[line.removeprefix("ROUND_RESULT ") for line in stdout.splitlines() if line.startswith("ROUND_RESULT ")]
        result=json.loads(rows[0]) if len(rows)==1 else {"id":i,"name":"No successful round result"}
        cleanup=[line.removeprefix("ROUND_CLEANUP ") for line in stdout.splitlines() if line.startswith("ROUND_CLEANUP ")]
        bad=bool(re.search(r"SCRIPT ERROR:|ERROR:|ROUND TIMEOUT|FAIL:",output))
        result.setdefault("name","Round aborted before a complete result")
        result.update({"id":i,"attempt":seq,"exit_code":code,"duration_s":round(time.monotonic()-start,3),"status":"passed" if code==0 and len(rows)==1 and result.get("id")==i and not bad else "failed","log":str(log.relative_to(ROOT)),"log_sha256":hashlib.sha256(log.read_bytes()).hexdigest(),"utc":datetime.now(timezone.utc).isoformat()})
        if cleanup:result["cleanup"]=json.loads(cleanup[-1])
        rss=re.search(r"(\d+)\s+maximum resident set size",stderr)
        if rss:result["maximum_rss_bytes"]=int(rss[1])
        # Runtime source fingerprint includes all changes under evaluation.
        from source_fingerprint import source_fingerprint
        result["source_fingerprint"]=source_fingerprint()
        result["harness_sha256"]={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/"godot/tests").glob("fifty_*.gd"))}
        report["attempts"].append(result)
        latest={x["id"]:x for x in report["attempts"]}
        report["completed_rounds"]=sorted(k for k,v in latest.items() if v["status"]=="passed")
        report["completed_count"]=len(report["completed_rounds"])
        ledger.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
        print(f"Round {i:02d}: {result['status']} — {result['name']} ({result['duration_s']}s)",flush=True)
        if result["status"]!="passed":
            print(output[-8000:],flush=True)
            raise SystemExit(1)
    print(f"Completed distinct rounds: {report['completed_count']}/50",flush=True)

if __name__=="__main__":main()
