class_name MovementFeed
extends RefCounted
## Projection en lecture seule des missions réelles ; aucun stock ni ordre n'est créé.
static func _row(c:StarCampaign,kind:String,team:int,source:String,target:String,eta:int,duration:int,id:int)->Dictionary:
	var from_system:String=String(c.info(source).get("system_id",source))
	var to_system:String=String(c.info(target).get("system_id",target))
	return {"kind":kind,"team":team,"from":source,"to":target,"from_system":from_system,"to_system":to_system,"eta":eta,"duration":maxi(1,duration),"id":id}
static func records(c:StarCampaign,player:int)->Array:
	var rows:Array=[]
	for flight in c.flights:rows.append(_row(c,"Expédition",int(flight["team"]),String(flight["from"]),String(flight["to"]),int(flight["eta"]),c._flight_duration(flight),int(flight["id"])))
	for flight in c.orbital_flights:rows.append(_row(c,"Flotte",int(flight["team"]),String(flight["from"]),String(flight["to"]),int(flight["eta"]),int(flight["duration"]),int(flight["id"])))
	for freight in c.freight_orders:
		var route:Array=freight["route"];var index:int=int(freight["hop"])
		if index+1>=route.size():continue
		var source:String=String(route[index]);var target:String=String(route[index+1])
		rows.append(_row(c,"Fret",int(freight["team"]),source,target,int(freight["eta"]),c._freight_eta(source,target),int(freight["id"])))
	for probe in c.survey_probes:rows.append(_row(c,"Sonde",int(probe["team"]),String(probe["from"]),String(probe["target"]),int(probe["eta"]),int(probe["duration"]),int(probe["id"])))
	for transport in c.planets.transports:
		var source:String=String(transport["origin"]);var target:String=String(transport["destination"])
		if String(transport["state"])=="returning":var previous:String=source;source=target;target=previous
		rows.append(_row(c,"Transport",int(transport["owner"]),source,target,int(transport["eta"]),StarCampaign.expected_flight_duration(c.star_catalog,source,target),int(transport["id"])))
	for treaty in c.treaties:
		if String(treaty["kind"])=="aid" and String(treaty["state"])=="pending":rows.append(_row(c,"Aide",int(treaty["team"]),String(treaty["source"]),String(treaty["body"]),int(treaty["duration"])-int(treaty["progress"]),int(treaty["duration"]),0))
	return rows.filter(func(row:Dictionary)->bool:
		if int(row["team"])==player:return true
		if not c.system_known(player,String(row["from_system"])) or not c.system_known(player,String(row["to_system"])):return false
		return c.system_held(player,String(row["from_system"])) or c.system_held(player,String(row["to_system"])))
static func caption(c:StarCampaign,point:String)->String:
	if c.star_catalog.has_body(point):return String(c.info(point)["label"])
	return String((c.star_catalog.galaxy.systems.get(point,{"label":"Signal"}) as Dictionary)["label"])
static func tint(row:Dictionary,player:int)->Color:
	if int(row["team"])!=player:return AgeTheme.c("danger")
	return AgeTheme.c("warning") if String(row["kind"]) in ["Fret","Aide","Transport"] else AgeTheme.c("info")
