#!/usr/bin/env python3
"""Charge le paquet 3D depuis un paquet de jeu autonome, hors projet et sans cache."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BOOT = '''extends Node
const Assets = preload("res://game/asset_library.gd")
func _ready() -> void:
\tvar ok: bool = Assets.ids().size() == 800
\tvar id: String = Assets.find("vehicle_ground", "jeep", 7)
\tvar node: Node3D = Assets.instantiate(id)
\tok = ok and node != null and Assets.path(id).ends_with(".scn")
\tif node != null:
\t\tnode.free()
\tvar material: StandardMaterial3D = Assets.shared_material("brick")
\tok = ok and material != null and material.albedo_texture != null and material.normal_texture != null and material.orm_texture != null
\tok = ok and not DirAccess.dir_exists_absolute("res://assets_3d")
\tok = ok and ResourceLoader.get_dependencies(Assets.path(id)).is_empty()
\tif FileAccess.file_exists("res://data/realism_models.pck"):
		ok = ok and ProjectSettings.load_resource_pack("res://data/realism_models.pck", false)
		var art: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://realism_native/manifest.json"))
		ok = ok and art is Dictionary and ((art as Dictionary).get("models", []) as Array).size() == 57
		var human: PackedScene = load("res://realism_native/human_ouvrier.scn") as PackedScene
		ok = ok and human != null
		if human != null:
			var figure: Node = human.instantiate()
			figure.free()
	print("NATIVE_PACKAGED_RUNTIME=%s models=%d jeep=%s" % ["PASS" if ok else "FAIL", Assets.ids().size(), id])
\tget_tree().quit(0 if ok else 1)
'''
PACKER = '''extends SceneTree
func _initialize() -> void:
\tvar args: PackedStringArray = OS.get_cmdline_user_args()
\tvar packer := PCKPacker.new()
\tif args.size() != 1 or packer.pck_start(args[0]) != OK:
\t\tquit(2)
\t\treturn
\tfor path in ["project.godot", "main.tscn", "boot.gd", "game/asset_library.gd", "data/assets_3d.pck"]:
\t\tif packer.add_file("res://" + path, ProjectSettings.globalize_path("res://" + path)) != OK:
\t\t\tquit(2)
\t\t\treturn
\tif FileAccess.file_exists("res://data/realism_models.pck"):
		if packer.add_file("res://data/realism_models.pck", ProjectSettings.globalize_path("res://data/realism_models.pck")) != OK:
			quit(2)
			return
	quit(0 if packer.flush() == OK else 2)
'''

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    args = parser.parse_args()
    binary = shutil.which(args.godot)
    if not binary:
        parser.error('Godot 4.7.2 introuvable.')
    with tempfile.TemporaryDirectory(prefix='sillons-pack-smoke-') as temporary:
        stage = Path(temporary)
        project = stage / 'project'
        empty = stage / 'empty'
        empty.mkdir()
        (project / 'data').mkdir(parents=True)
        (project / 'game').mkdir()
        (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Sillons Pack Smoke"\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        (project / 'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://boot.gd" id="1"]\n[node name="PackSmoke" type="Node"]\nscript = ExtResource("1")\n')
        (project / 'boot.gd').write_text(BOOT)
        (project / 'make.gd').write_text(PACKER)
        shutil.copyfile(ROOT / 'game/asset_library.gd', project / 'game/asset_library.gd')
        shutil.copyfile(ROOT / 'data/assets_3d.pck', project / 'data/assets_3d.pck')
        if (ROOT / 'data/realism_models.pck').is_file():
            shutil.copyfile(ROOT / 'data/realism_models.pck', project / 'data/realism_models.pck')
        packed = stage / 'standalone.pck'
        commands = [
            ([binary, '--headless', '--path', str(project), '--script', 'res://make.gd', '--', str(packed)], project),
            ([binary, '--headless', '--main-pack', str(packed)], empty),
        ]
        for command, cwd in commands:
            result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=90)
            output = result.stdout + result.stderr
            print(output, end='', flush=True)
            if result.returncode or any(marker in output for marker in ['SCRIPT ERROR', 'Parse Error', 'Compile Error', '\nERROR:']):
                raise SystemExit(result.returncode or 1)
        if 'NATIVE_PACKAGED_RUNTIME=PASS' not in output:
            raise SystemExit('Marqueur de réussite absent.')

if __name__ == '__main__':
    main()
