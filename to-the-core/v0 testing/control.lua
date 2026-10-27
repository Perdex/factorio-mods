_G.aisodoimod = aisodoimod or {}
require "scripts/events"
require "scripts/movement"

print("Woah initializing!")
log("Hello log")

function on_init()
    
end
aisodoimod.on_event(aisodoimod.events.on_init(), on_init)
aisodoimod.finalize_events()

--[[events.on_config(function(ev) if(warptorio.Loaded)then return end
	lib.planets.lua()
	cache.validate("combinators")
	cache.validate("heat")
	cache.validate("power")
	cache.validate("loaderinput")
	cache.validate("loaderoutput")
	cache.validate("ldinputf")
	cache.validate("ldoutputf")

	global.warpzone=global.warpzone or 0
	global.time_spent_start_tick=global.time_spent_start_tick or game.tick
	global.time_passed=global.time_passed or 0

	global.warp_charge_time=global.warp_charge_time or 10
	global.warp_charge_start_tick=global.warp_charge_start_tick or 0
	global.warp_charging=global.warp_charging or 0
	global.warp_timeleft=global.warp_timeleft or 60*10
	global.warp_auto_time = global.warp_auto_time or 60*settings.global["warptorio_autowarp_time"].value
	global.warp_auto_end = global.warp_auto_end or 60*60*settings.global["warptorio_autowarp_time"].value
	global.warp_last=global.warp_last or game.tick
	global.abilities=global.abilities or {}
	global.ability_drain=global.ability_drain or settings.global["warptorio_ability_drain"].value

	global.pollution_amount = global.pollution_amount or 1.1
	global.pollution_expansion = global.pollution_expansion or 1.1
	global.ability_uses=global.ability_uses or 0
	global.ability_next=global.ability_next or 0
	global.radar_uses=global.radar_uses or 0

	warptorio.ApplyMapSettings()

	global.votewarp=global.votewarp or {} if(type(global.votewarp)~="table")then global.votewarp={} end
	warptorio.CheckVotewarps()

	-- todo: global.warp_blacklist={}
	warptorio.ValidateWarpBlacklist()

	--[[ more todo:
		for k,v in pairs(gwarptorio.Harvesters)do v.position=warptorio.platform.harvester[k] end
		for k,v in pairs(gwarptorio.Teleporters)do v.position=warptorio.Teleporters[k].position end
	]

	global.Teleporters=global.Teleporters or {}
	global.Research=global.Research or {} -- todo remove this
	global.Turrets=global.Turrets or {}
	global.Rails=global.Rails or {}
	global.Harvesters=global.Harvesters or {}


	if(not global.floor)then warptorio.InitPlatform() end


	for k,v in pairs(global.Rails)do
		v:MakeRails()
	end
	for k,v in pairs(global.Teleporters)do
		v:CheckTeleporterPairs(true)
	end
	for k,v in pairs(global.Harvesters)do
		local gdata=warptorio.platform.harvesters[v.key]
		v.rank=warptorio.GetPlatformTechLevel(gdata.tech)
		v:CheckTeleporterPairs(true)
		v:Upgrade()
	end

	for k,v in pairs(warptorio.settings)do v() end

	-- todo: warptorio.ApplyMapSettings()
	for k,t in pairs(global.Harvesters)do
		table.merge(t,table.deepcopy(warptorio.platform.harvesters[t.key]))
		table.merge(t,table.deepcopy(warptorio.platform.HarvesterPointData))
	end

	warptorio.Loaded=true
end)]]