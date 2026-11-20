#!/usr/bin/env python3
"""Export APK de recette R2, signature debug et contrôles. Python 3.10+, Linux, Godot 4.7.2.
Exécution : utilisateur standard. Aucun téléchargement automatique, aucune installation sur téléphone.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
from android_manifest_fix import normalize_apk
PACKAGE = "fr.sillons.empire.recette.r2"

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--sdk", default=os.environ.get("ANDROID_SDK_ROOT", os.environ.get("ANDROID_HOME", "")))
    parser.add_argument("--java", default=os.environ.get("JAVA_HOME", ""))
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args(); project = pathlib.Path(__file__).resolve().parent.parent
    godot = shutil.which(args.godot)
    if not godot or not args.sdk or not args.java: parser.error("Préciser --godot, --sdk et --java")
    sdk = pathlib.Path(args.sdk).expanduser().resolve(); java = pathlib.Path(args.java).expanduser().resolve()
    keytool = java / "bin/keytool"
    if not keytool.is_file() or not (sdk / "platform-tools/adb").is_file(): parser.error("SDK incomplet : keytool / adb")
    builds = [p for p in (sdk / "build-tools").glob("*") if re.fullmatch(r"\d+\.\d+\.\d+", p.name)]
    if not builds: parser.error("Android Build-Tools absent")
    tools = max(builds, key=lambda p: tuple(map(int, p.name.split("."))))
    signer = tools / "apksigner"; aligner = tools / "zipalign"; aapt = tools / "aapt"
    if not all(p.is_file() for p in [signer, aligner, aapt]): parser.error("Build-Tools incomplet")
    output = (args.output or project / "build/sillons-empire-test-0.15.1-r2-arm64.apk").resolve()
    if output.exists(): parser.error("La sortie existe : choisir un nouveau chemin")
    output.parent.mkdir(parents=True, exist_ok=True)
    private = project / "build/android-private"; private.mkdir(parents=True, exist_ok=True); private.chmod(0o700)
    key = private / "recette-debug.keystore"
    log_dir = project / "build/export-0151-logs"; log_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy(); env.update(JAVA_HOME=str(java), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk), GODOT_SILENCE_ROOT_WARNING="1")
    def run(name: str, command: list[str], timeout: int = 600) -> str:
        result = subprocess.run(command, cwd=project, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        (log_dir / (name + ".log")).write_text(result.stdout, encoding="utf-8")
        if result.returncode or re.search(r"^(?:SCRIPT ERROR|ERROR:)", result.stdout, re.M): raise RuntimeError(name + " échoué : " + str(log_dir / (name + ".log")))
        print(name + "=PASS", flush=True); return result.stdout
    version = run("godot-version", [godot, "--version"]).strip()
    if not version.startswith("4.7.2."): parser.error("Godot 4.7.2 requis pour reproduire cette livraison")
    if not key.exists():
        run("debug-key", [str(keytool), "-genkeypair", "-keystore", str(key), "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=Sillons Empire Test R2, O=Local Test, C=FR"])
        key.chmod(0o600)
    config_root = private / "config"; settings_dir = config_root / "godot"; settings_dir.mkdir(parents=True, exist_ok=True)
    values = {"export/android/android_sdk_path": str(sdk), "export/android/java_sdk_path": str(java), "export/android/debug_keystore": str(key), "export/android/debug_keystore_user": "androiddebugkey", "export/android/debug_keystore_pass": "android"}
    settings = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' + ''.join(k + '=' + json.dumps(v) + '\n' for k, v in values.items())
    for name in ['editor_settings-4.7.tres','editor_settings-4.tres']: (settings_dir / name).write_text(settings)
    env["XDG_CONFIG_HOME"] = str(config_root)
    run("import", [godot, "--headless", "--path", str(project), "--editor", "--quit"])
    raw = private / "raw-0151.apk"; unsigned = private / "normalized-0151.apk"; aligned = private / "aligned-0151.apk"
    if unsigned.exists(): unsigned.unlink()  # intermédiaire privé du script
    run("export", [godot, "--headless", "--path", str(project), "--export-debug", "Android", str(raw)])
    corrections = normalize_apk(raw, unsigned, PACKAGE)
    (log_dir / 'manifest-normalization.json').write_text(json.dumps(corrections, indent=2))
    run("zipalign", [str(aligner), "-P", "16", "-f", "4", str(unsigned), str(aligned)])
    run("sign", [str(signer), "sign", "--ks", str(key), "--ks-pass", "pass:android", "--key-pass", "pass:android", "--ks-key-alias", "androiddebugkey", "--v4-signing-enabled", "false", "--out", str(output), str(aligned)])
    if not output.is_file() or output.stat().st_size == 0: raise RuntimeError("APK absent")
    run("signature", [str(signer), "verify", "--verbose", "--print-certs", str(output)])
    run("alignment-16k", [str(aligner), "-c", "-P", "16", "-v", "4", str(output)])
    badging = run("manifest", [str(aapt), "dump", "badging", str(output)])
    xml = run("manifest-tree", [str(aapt), "dump", "xmltree", str(output), "AndroidManifest.xml"])
    aliases = re.findall(r"(?ms)^ {6}E: activity-alias.*?(?=^ {6}E: |\Z)", xml)
    launcher_alias = any('android.intent.action.MAIN' in a and 'android.intent.category.LAUNCHER' in a and re.search(r'android:exported[^\n]*0xffffffff', a) for a in aliases)
    if "package: name='" + PACKAGE + "' versionCode='151'" not in badging or not ("launchable-activity:" in badging or launcher_alias): raise RuntimeError("Paquet ou activité inattendus")
    metadata = {"apk": output.name, "sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "bytes": output.stat().st_size, "godot": version, "build_tools": tools.name, "package": PACKAGE, "signature_verified": True, "zipalign_16k": True, "manifest_validated": True, "launcher_alias": bool(launcher_alias), "manifest_corrections": corrections, "device_validation": "NOT_RUN"}
    output.with_suffix('.build.json').write_text(json.dumps(metadata, indent=2))
    print(json.dumps(metadata, ensure_ascii=False, indent=2)); return 0
if __name__ == "__main__":
    try: raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("EXPORT_ANDROID=FAIL :", error, file=sys.stderr); raise SystemExit(1)
