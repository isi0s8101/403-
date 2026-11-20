#!/usr/bin/env python3
"""0.17 — Contrôle statique de l'interface « grand RTS » et des thèmes par âge."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
failures = 0


def check(ok, label):
    global failures
    failures += int(not ok)
    print(('PASS ' if ok else 'FAIL ') + label)


def src(name):
    return (ROOT / name).read_text(encoding='utf-8')


NEW = ['interface/age_theme.gd', 'interface/touch_tile.gd', 'interface/ui_feedback.gd', 'interface/age_ceremony.gd',
       'interface/selection_bar.gd', 'interface/control_groups.gd', 'interface/command_card.gd', 'interface/alert_feed.gd',
       'interface/command_bars.gd', 'interface/order_path_view.gd', 'interface/placement_tool.gd', 'interface/production_panel.gd',
       'sim/order_queue.gd', 'sim/unit_commands.gd', 'tools/generate-ui-skins.py', 'tools/check-scripts.gd', 'tools/capture-ui-017.gd']
check(all((ROOT / n).is_file() for n in NEW), 'fichiers 0.17 présents (%d)' % len(NEW))
check(any(v in src('project.godot') for v in ['"0.17.0-interface-candidate"', '"0.18.0-ville-candidate"', '"0.18.1-ville-candidate"', '"0.19.0-zonage-candidate"', '"0.20.0-zonage-candidate"']) and any(v in src('export_presets.cfg') for v in ['version/code=170', 'version/code=180', 'version/code=181', 'version/code=190', 'version/code=200']), 'version 0.17.0 ou 0.18.0 / code 170 ou 180')
skins = [ROOT / 'interface/ui_skins' / ('age_%02d' % a) / f for a in range(1, 11) for f in ('panel.png', 'button.png', 'tap.wav', 'open.wav', 'alert.wav', 'age.wav')]
check(all(p.is_file() for p in skins), 'habillages et sons des 10 âges présents')
size = sum(p.stat().st_size for p in (ROOT / 'interface/ui_skins').rglob('*') if p.suffix in ('.png', '.wav'))
fonts = sum(p.stat().st_size for p in (ROOT / 'interface/fonts').glob('*.ttf'))
check(size + fonts < 4 * 1024 * 1024, 'budget des ressources d\'interface < 4 Mio (%.2f Mio)' % ((size + fonts) / 1048576))
families = {p.name.split('-')[0] for p in (ROOT / 'interface/fonts').glob('*.ttf')}
check(len(families) <= 3 and all((ROOT / 'interface/fonts' / ('OFL-%s.txt' % f)).is_file() for f in families), 'au plus 3 familles de polices, licence OFL jointe à chacune (%s)' % ', '.join(sorted(families)))
licences = (ROOT / 'game-studio/assets-licences.md').read_text(encoding='utf-8')
check(all(f in licences for f in ('Fira Sans', 'Cardo', 'Anonymous Pro')) and 'SIL Open Font License' in licences, 'polices listées dans game-studio/assets-licences.md')
tokens = src('interface/age_theme.gd')
check(tokens.count('{"name": ') == 11, 'jetons de style : thème neutre + 10 âges')
check('UnitCommands.handles(' in src('sim/sim_world.gd') and 'UnitCommands.step(self)' in src('sim/sim_world.gd') and 'OrderQueue.replace(w, cmd)' in src('evolution/army_plans.gd'), 'commandes simulées branchées par crochets d\'une ligne')
check('MobileUI.theme()' in src('game/hud.gd') and 'return AgeTheme.shared()' in src('game/mobile_ui.gd'), 'thème unique partagé (MobileUI.theme → AgeTheme)')
verify = src('tools/verify-refonte.sh')
for scenario in ('unit_commands', 'ui_selection', 'ui_orders', 'ui_production', 'ui_alerts', 'ui_theme'):
    check(scenario in verify and (ROOT / 'lab' / (scenario + '_test.gd')).is_file(), 'recette %s enregistrée' % scenario)
literal = re.compile(r'Color\(\s*"|Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)')
bad = []
for name in ['game/hud.gd', 'game/mobile_ui.gd', 'game/strategic_hud.gd'] + [str(p.relative_to(ROOT)) for p in (ROOT / 'interface').glob('*.gd') if p.name not in ('age_theme.gd', 'menu_backdrop.gd')]:
    for i, line in enumerate(src(name).splitlines(), 1):
        for m in literal.finditer(line):
            if m.group(0).endswith('"') or len({m.group(1), m.group(2), m.group(3)}) > 1:
                bad.append('%s:%d' % (name, i))
check(not bad, 'aucune couleur codée en dur dans l\'interface (%s)' % ', '.join(bad[:6]))
print('INTERFACE_STATIC=%s' % ('PASS' if failures == 0 else 'FAIL'))
sys.exit(1 if failures else 0)
