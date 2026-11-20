#!/usr/bin/env python3
"""Relevé ADB local sans root. Python 3.10+, Platform-Tools dans PATH.
Aucune installation, désinstallation ou fermeture d'application. Résultats dans un nouveau dossier.
"""
from __future__ import annotations
import argparse
import csv
import datetime as dt
import json
import pathlib
import re
import shutil
import subprocess
import sys
import time
PACKAGE = "fr.sillons.empire.recette.r2"

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", help="Appareil exact si plusieurs appareils sont connectés")
    parser.add_argument("--seconds", type=int, default=600)
    parser.add_argument("--interval", type=int, default=10)
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("mesures-s25"))
    args = parser.parse_args()
    if not 10 <= args.seconds <= 7200 or not 5 <= args.interval <= 120: parser.error("seconds : 10..7200 ; interval : 5..120")
    executable = shutil.which(args.adb)
    if not executable: parser.error("ADB introuvable ; installer les Platform-Tools officiels")
    prefix = [executable]
    def invoke(command: list[str], timeout: int = 15) -> tuple[int, str]:
        try:
            result = subprocess.run(prefix + command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
            return result.returncode, result.stdout + ("\n" + result.stderr if result.stderr else "")
        except subprocess.TimeoutExpired: return 124, "TIMEOUT"
    code, inventory = invoke(["devices"])
    if code: print(inventory, file=sys.stderr); return 2
    devices = [line.split()[0] for line in inventory.splitlines() if re.fullmatch(r"\S+\s+device", line.strip())]
    if args.serial:
        if args.serial not in devices: parser.error("Appareil demandé absent ou non autorisé")
        serial = args.serial
    elif len(devices) == 1: serial = devices[0]
    else: parser.error("Connecter et autoriser un appareil ; préciser --serial s'il y en a plusieurs")
    prefix += ["-s", serial]
    code, installed = invoke(["shell", "pm", "path", PACKAGE])
    if code or "package:" not in installed: parser.error("Installer Sillons d'Empire Test R2 avant le relevé")
    code, pid = invoke(["shell", "pidof", PACKAGE])
    if code or not re.fullmatch(r"\d+(?:\s+\d+)*", pid.strip()): parser.error("L'application de recette n'est pas démarrée")
    first_pid = pid.split()[0]
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = args.output.expanduser().resolve() / stamp; output.mkdir(parents=True, exist_ok=False)
    metadata = {"schema": 1, "utc": stamp, "package": PACKAGE, "seconds_requested": args.seconds,
                "interval_s": args.interval, "battery_temperature_note": "Température batterie, distincte des températures CPU/GPU/de surface.",
                "fps_note": "FPS issus du rapport interne Godot ; gfxinfo non utilisé comme FPS du jeu."}
    for key, prop in [("model", "ro.product.model"), ("android_release", "ro.build.version.release"), ("sdk", "ro.build.version.sdk")]:
        status, value = invoke(["shell", "getprop", prop]); metadata[key] = value.strip() if status == 0 else None
    (output / "device.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    rows = []; started = time.monotonic(); sequence = 0; interrupted = False
    try:
        while True:
            elapsed = time.monotonic() - started
            row = {"elapsed_s": round(elapsed, 3), "utc": dt.datetime.now(dt.timezone.utc).isoformat()}
            status, current_pid = invoke(["shell", "pidof", PACKAGE])
            row["process_alive"] = status == 0 and bool(current_pid.strip())
            row["process_restarted"] = row["process_alive"] and first_pid not in current_pid.split()
            for name, command in [("meminfo", ["shell", "dumpsys", "meminfo", PACKAGE]),
                                  ("battery", ["shell", "dumpsys", "battery"]),
                                  ("thermal", ["shell", "dumpsys", "thermalservice"])]:
                status, text = invoke(command)
                (output / f"{sequence:04d}-{name}.txt").write_text(text, encoding="utf-8")
                row[name + "_ok"] = status == 0
                if name == "meminfo":
                    match = re.search(r"TOTAL PSS:\s*([\d,]+)", text)
                    if not match: match = re.search(r"^\s*TOTAL\s+([\d,]+)", text, re.M)
                    row["pss_mib"] = round(int(match[1].replace(",", "")) / 1024, 3) if match else None
                    rss = re.search(r"TOTAL RSS:\s*([\d,]+)", text)
                    row["rss_mib"] = round(int(rss[1].replace(",", "")) / 1024, 3) if rss else None
                elif name == "battery":
                    temperature = re.search(r"^\s*temperature:\s*(-?\d+)", text, re.M)
                    row["battery_c"] = int(temperature[1]) / 10.0 if temperature else None
                    level = re.search(r"^\s*level:\s*(\d+)", text, re.M)
                    row["battery_percent"] = int(level[1]) if level else None
                else:
                    thermal = re.search(r"Thermal Status:\s*(\d+)", text, re.I)
                    row["thermal_status"] = int(thermal[1]) if thermal else None
            rows.append(row); print(json.dumps(row, ensure_ascii=False), flush=True)
            (output / "samples.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
            if not row["process_alive"] or time.monotonic() - started >= args.seconds: break
            sequence += 1
            remaining = min(started + sequence * args.interval, started + args.seconds) - time.monotonic()
            if remaining > 0: time.sleep(remaining)
    except KeyboardInterrupt:
        interrupted = True; print("Relevé interrompu ; mesures disponibles conservées", file=sys.stderr)
    status, text = invoke(["exec-out", "run-as", PACKAGE, "cat", "files/mesures/last_report.json"])
    internal_report = None
    if status == 0:
        try:
            internal_report = json.loads(text)
            (output / "godot-last-report.json").write_text(json.dumps(internal_report, ensure_ascii=False, indent=2), encoding="utf-8")
        except json.JSONDecodeError: pass
    status, log = invoke(["logcat", "-d", "-t", "500", "--pid=" + first_pid])
    if status == 0: (output / "app-logcat.txt").write_text(log, encoding="utf-8")
    summary = {"samples": len(rows), "interrupted": interrupted, "app_died": any(not r["process_alive"] for r in rows),
               "process_restarted": any(r["process_restarted"] for r in rows), "godot_report_available": internal_report is not None,
               "report_utc": internal_report.get("metadata", {}).get("utc") if internal_report else None,
               "report_note": "Vérifier scénario et heure : le rapport Godot peut précéder le relevé ADB."}
    for field in ["pss_mib", "rss_mib", "battery_c", "thermal_status"]:
        known = [r[field] for r in rows if r.get(field) is not None]; summary[field + "_max"] = max(known) if known else None
    (output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    if rows:
        with (output / "samples.csv").open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    print("Mesures disponibles :", output)
    return 1 if summary["app_died"] or summary["process_restarted"] else 0
if __name__ == "__main__": raise SystemExit(main())
