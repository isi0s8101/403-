#!/usr/bin/env python3
"""Audit hors Godot : structure, intégrité des fichiers hérités et contraintes J6-J8.

Ne prétend pas compiler GDScript ni vérifier un APK.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot", "export_presets.cfg", "README-J678.md",
    "sim/star_campaign.gd", "sim/campaign_save.gd", "sim/rules.gd",
    "sim/sim_world.gd", "sim/save_game.gd", "game/game.gd",
    "game/main_menu.gd", "game/hud.gd", "game/strategic_hud.gd",
    "lab/strategic_test.gd", "lab/strategic_ui_test.gd",
    "game-studio/J678-validation.md", "tools/verify-j678.sh",
]
SCRIPTS = ["sim", "game", "lab", "tools"]
pass_count = 0
fail_count = 0


def check(ok: bool, label: str) -> None:
    global pass_count, fail_count
    if ok:
        pass_count += 1
    else:
        fail_count += 1
    print(("PASS" if ok else "FAIL") + " " + label)


def strip_comment(line: str) -> str:
    # Comments not preceded by a closing string; sufficient for unambiguous audit lines.
    return line.split("#", 1)[0].rstrip()


def audit_scripts() -> None:
    count = 0
    for dirname in SCRIPTS:
        for path in (HERE / dirname).rglob("*.gd"):
            count += 1
            data = path.read_text(encoding="utf-8")
            rel = path.relative_to(HERE)
            check("\x00" not in data and "\r" not in data,
                  f"encodage/fin de ligne {rel}")
            lines = data.splitlines()
            has_tabs = any(line.startswith("\t") for line in lines)
            check(has_tabs or not any(line.startswith("func ") for line in lines), f"indentation principale {rel}")
            if rel.name in ("star_campaign.gd", "campaign_save.gd", "strategic_hud.gd"):
                check(bool(re.search(r"^class_name\s+\w+", data, re.M)), f"classe nommée {rel}")
            # Détecte les signatures de fonction dupliquées à portée racine.
            func_names = re.findall(r"^func\s+(\w+)\s*\(", data, re.M)
            check(len(func_names) == len(set(func_names)), f"fonctions non dupliquées {rel}")
            # Détecte les nouveaux symboles non protégés en fin d'indendation.
            check(not any(line.startswith(" ") and line.strip().startswith("func ") for line in lines),
                  f"signatures alignées {rel}")
    check(count >= 36, f"ensemble GDScript préservé ({count} scripts)")


def audit_functionality() -> None:
    def read(name: str) -> str:
        return (HERE / name).read_text(encoding="utf-8")

    rules = read("sim/rules.gd")
    camp = read("sim/star_campaign.gd")
    save = read("sim/campaign_save.gd")
    game = read("game/game.gd")
    ui = read("game/strategic_hud.gd")
    verify = read("lab/strategic_test.gd")
    checks = [
        (len(re.findall(r'"id":\s*\d+,\s*"name":', rules)) == 10, "dix âges historiques et futurs"),
        (all(k in rules for k in ["spatioport", "chantier_orbital", "navette", "fregate", "propulsion_orbitale", "navigation_stellaire"]), "catalogue orbital et interstellaire"),
        (all(k in camp for k in ['"val"', '"aurore"', '"nemesis"']), "trois secteurs différents"),
        (all(k in camp for k in ["func dispatch(", "func _tick_flights(", "func launch_satellite(", "func scan(", "func _check_defeat("]), "mécanique J6-J8 et victoire globale"),
        (("for key in SECTORS:" in camp or "for key in worlds.keys():" in camp) and "w.step()" in camp, "toutes les planètes continuent de simuler"),
        ("var candidates: Array = flights.duplicate()" in camp, "interception sur copie d'index stable"),
        ("_sync_all()" in camp and "t.res = system_resources(team, _system_of(String(key)))" in camp, "ressources et technologies communes"),
        ("HashingContext.HASH_SHA256" in save and "load_campaign" in save and "from_snapshot" in save, "sauvegarde multi-cartes vérifiée par empreinte"),
        ("bytes_to_var(payload)" in save and "allow_objects" not in save, "désérialisation sans instanciation d'objets"),
        ("campaign.step()" in game and "switch_sector(" in game, "moteur et bascule de vue raccordés"),
        ("scan_orbite" in game and "strategic_hud.is_over_ui" in game, "balayage et gestes UI raccordés"),
        (all(k in ui for k in ["_satellite", "_dispatch", "_scan", "sector_buttons"]), "commandes tactiles orbitales"),
        ("interceptions multiples" in verify and "reprise déterministe" in verify and "restauration sur disque" in verify, "tests de non-régression J6-J8"),
        ((HERE / "lab/modern_test.gd").exists() and (HERE / "lab/fronts_test.gd").exists(), "laboratoires J1–J5 conservés"),
        ("run/main_scene=" in read("project.godot") and "config/version=" in read("project.godot"), "configuration Godot disponible"),
    ]
    for ok, label in checks:
        check(ok, label)


def audit_original(path: Path) -> None:
    with zipfile.ZipFile(path) as z:
        bad = z.testzip()
        check(bad is None, "archive J345 d'origine CRC correct")
        root = "sillons-empire-j345-0.5.0-source-complet/sillons/"
        changed = {
            "project.godot", "export_presets.cfg", "sim/rules.gd", "sim/sim_world.gd",
            "sim/save_game.gd", "sim/modern_systems.gd", "sim/ai_controller.gd",
            "game/assets.gd", "game/modern_visual.gd", "game/game_config.gd",
            "game/game.gd", "game/main_menu.gd", "game/hud.gd",
        }
        count = 0
        for name in z.namelist():
            if not name.startswith(root) or name.endswith("/"):
                continue
            rel = name[len(root):]
            if rel.startswith(".godot/") or rel in changed:
                continue
            output = HERE / rel
            check(output.is_file() and hashlib.sha256(output.read_bytes()).digest() == hashlib.sha256(z.read(name)).digest(), f"source J345 non modifiée {rel}")
            count += 1
        check(count > 90, f"fichiers historiques préservés ({count})")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, help="Archive J345 d'origine à comparer")
    args = parser.parse_args()
    for rel in REQUIRED:
        check((HERE / rel).is_file(), f"fichier requis {rel}")
    audit_scripts()
    audit_functionality()
    if args.baseline:
        audit_original(args.baseline)
    print(f"J678_STATIC_RESULT={'PASS' if fail_count == 0 else 'FAIL'} PASS={pass_count} FAIL={fail_count}")
    print("GODOT_COMPILE=NOT_EXECUTED  ANDROID_EXPORT=NOT_EXECUTED  DEVICE_TEST=NOT_EXECUTED")
    return 1 if fail_count else 0


if __name__ == "__main__":
    sys.exit(main())
