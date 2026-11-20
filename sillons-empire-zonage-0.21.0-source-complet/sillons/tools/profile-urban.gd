extends SceneTree
## 0.20 — Mesure du coût du calcul de la ville, partie par partie (outil de mesure, hors simulation).
## godot --headless --path . --script res://tools/profile-urban.gd

func _city(seed_value: int, rows: int) -> SimWorld:
	var w := SimWorld.new()
	w.setup(seed_value, {"campaign": true, "urban": true})
	for y in 96:
		for x in 96:
			w.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_GRASS)
	for b in w.buildings.values().duplicate():
		w._destroy_building(b, -1)
	w.nodes.clear()
	w._node_cells.clear()
	for t in [0, 1]:
		w.teams[t].res = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
		w.teams[t].age = 6
	w.spawn_building(0, "centre", Vector2i(10, 10), true)
	w.spawn_building(1, "centre", Vector2i(80, 80), true)
	w.teams[0].technologies[UrbanRules.TECH] = true
	var cc: SimWorld.Building = w.team_buildings(0, "centre")[0]
	var road: Array = []
	for y in range(4, 92):
		road.append([cc.cell.x - 1, y])
		road.append([cc.cell.x + 9, y])
	w.issue({"t": "road_paint", "team": 0, "cells": road})
	w.issue({"t": "zone_paint", "team": 0, "kind": 2, "from": [cc.cell.x, 20], "to": [cc.cell.x + 7, 90]})
	w.issue({"t": "zone_paint", "team": 0, "kind": 4, "from": [cc.cell.x + 10, 20], "to": [cc.cell.x + 13, 90]})
	for y in range(20, 20 + rows * 2, 2):
		for x in [cc.cell.x, cc.cell.x + 2, cc.cell.x + 4, cc.cell.x + 6]:
			var b: SimWorld.Building = w.spawn_building(0, "zone_r", Vector2i(x, y), true)
			b.city = {"grown": true, "level": 2, "density": 1.5, "style_age": 6, "variant": x + y, "rot": 0}
	for i in UrbanRules.PERIOD * 2:
		w.step()
	return w

func _us(f: Callable, n: int) -> float:
	var t0: int = Time.get_ticks_usec()
	for i in n:
		f.call()
	return float(Time.get_ticks_usec() - t0) / float(n) / 1000.0

func _initialize() -> void:
	for rows in [17, 34]:
		var w: SimWorld = _city(20001, rows)
		var t: SimWorld.Team = w.teams[0]
		var done: Array = []
		for candidate in w.team_buildings(0):
			var b: SimWorld.Building = candidate as SimWorld.Building
			if UrbanRules.is_urban(b.type) and b.complete:
				done.append(b)
		var ctx: Dictionary = {"habitants": int(t.city.get("habitants", 0)), "actifs": 100, "jobs": 100, "shop_jobs": 20, "wellbeing": 60.0,
			"crime_avg": 20.0, "unemployment": 0.1, "counts": {}, "electric": true, "power": [100, 50], "produced": {}, "wealth_avg": 50.0, "level_avg": 2.0}
		var n: int = 5
		var full: float = _us(func(): UrbanCity._update(w, 0), n)
		var dem: Dictionary = UrbanGrowth.demand(w, 0, ctx)
		var g_demand: float = _us(func(): UrbanGrowth.demand(w, 0, ctx), n)
		var g_states: float = _us(func(): UrbanGrowth._update_states(w, 0, done, ctx), n)
		var g_levels: float = _us(func(): UrbanGrowth._level_ups(w, 0, done, dem, ctx), n)
		var g_sites: float = _us(func(): UrbanGrowth._new_sites(w, 0, dem, 99, ctx), n)
		var g_parcels: float = _us(func(): t.zoning["parcels_rev"] = -1; UrbanZoning.parcels(w, 0), n)
		var g_linked: float = _us(func(): t.zoning["linked_sig"] = ""; UrbanZoning.linked(w, 0), n)
		var roads: float = _us(func(): w.urban_roads = PackedByteArray(); UrbanZoning.road_layer(w), n)
		print("URBAN_PROFILE buildings=%d update_ms=%.2f demand=%.2f states=%.2f levels=%.2f new_sites(99 max)=%.2f parcels(cold)=%.2f linked(cold)=%.2f road_layer(cold)=%.2f" % [
			done.size(), full, g_demand, g_states, g_levels, g_sites, g_parcels, g_linked, roads])
	quit()
