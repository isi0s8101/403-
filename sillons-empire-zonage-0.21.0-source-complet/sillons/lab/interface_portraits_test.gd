extends SceneTree
func _initialize()->void:
	var missing:Array=[]
	var checks:int=0
	for age in range(1,11):
		for kind in Rules.BUILDINGS:
			if kind=="comptoir":continue
			checks+=1
			if Portraits.building(kind,age)==null:missing.append("building:%s:%d"%[kind,age])
		for kind in Rules.UNITS:
			checks+=1
			if Portraits.unit(kind,age)==null:missing.append("unit:%s:%d"%[kind,age])
	for kind in OrbitalIndustry.UNITS:
		checks+=1
		if Portraits.orbital(kind)==null:missing.append("orbit:"+kind)
	for kind in ["shipyard","command"]+OrbitalIndustry.MODULES.keys():
		checks+=1
		if Portraits.orbital(kind,true)==null:missing.append("module:"+kind)
	print("PORTRAITS_RESULT checks=",checks," missing=",missing)
	quit(0 if missing.is_empty() else 1)
