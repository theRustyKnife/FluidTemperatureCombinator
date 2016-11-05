local refresh_rate = 60
local gui_refresh_rate = 10

local types = {
	["storage-tank"] = true,
	["boiler"] = true,
	["pipe"] = true,
	["pipe-to-ground"] = true
}

local look_offset = 0.5
local look_distance = 1
local tank_surroundings_check_distance = 2
local function get_tank(entity)
	local position = entity.position
	local direction = entity.direction
	
	local area
	
	if direction == defines.direction.north then
		area = {{position.x - look_offset, position.y - look_distance}, {position.x + look_offset, position.y - look_distance}}
	elseif direction == defines.direction.west then
		area = {{position.x - look_distance - 0.1, position.y - look_offset}, {position.x - look_distance + 0.1, position.y + look_offset}}
	elseif direction == defines.direction.south then
		area = {{position.x - look_offset, position.y + look_distance}, {position.x + look_offset, position.y + look_distance}}
	elseif direction == defines.direction.east then
		area = {{position.x + look_distance - 0.1, position.y - look_offset}, {position.x + look_distance + 0.1, position.y + look_offset}}
	end
	
	for i, v in pairs(entity.surface.find_entities(area)) do
		if types[v.type] then return v end
	end
end

local function find_in_global(combinator)
	for i = 0, refresh_rate - 1 do
		for ei, c in pairs(global.combinators[i]) do
			if c.entity == combinator then return c, i, ei end
		end
	end
end

local function on_built(event)
	local entity = event.created_entity
	
	if entity.name == "fluid-temperature-combinator" then
		local ei
		local n
		for i = 0, refresh_rate - 1 do
			if not n or n >= #global.combinators[i] then
				ei = i
				n = #global.combinators[i]
			end
		end
		entity.rotatable = true
		table.insert(global.combinators[ei], {entity = entity, tank = get_tank(entity)})
	end
	if types[entity.type] then
		local area = {
			{entity.position.x - tank_surroundings_check_distance, entity.position.y - tank_surroundings_check_distance},
			{entity.position.x + tank_surroundings_check_distance, entity.position.y + tank_surroundings_check_distance}
		}
		local combinators = entity.surface.find_entities_filtered{area = area, name = "fluid-temperature-combinator"}
		for _, combinator in pairs(combinators) do
			find_in_global(combinator).tank = get_tank(combinator)
		end
	end
end

local function on_tick(event)
	for _, combinator in pairs(global.combinators[event.tick % refresh_rate]) do
		local count = 0
		if combinator.tank and combinator.tank.valid and combinator.tank.fluidbox[1] then
			local precision = 1
			if combinator.precise then precision = 100 end
			count = combinator.tank.fluidbox[1].temperature * precision
		end
		combinator.entity.get_or_create_control_behavior().parameters = {
			enabled = true,
			parameters = {
				{
					signal = {type = "virtual", name = "fluid-temperature"},
					count = math.floor(count),
					index = 1
				}
			}
		}
	end
	
	for i = event.tick % gui_refresh_rate + 1, #game.players, gui_refresh_rate do
		local player = game.players[i]
		if player.opened and player.opened.name == "fluid-temperature-combinator" then
			local combinator = find_in_global(player.opened)
			if not player.gui.left["fluid-temperature-combinator-precise-toggle"] then
				local state = true
				if not combinator.precise then state = false end
				player.gui.left.add{type = "checkbox", name = "fluid-temperature-combinator-precise-toggle", caption = {"precise-toggle"}, state = state}
			end
			combinator.precise = player.gui.left["fluid-temperature-combinator-precise-toggle"].state
		elseif player.gui.left["fluid-temperature-combinator-precise-toggle"] then
			player.gui.left["fluid-temperature-combinator-precise-toggle"].destroy()
		end
	end
end

local function on_rotated(event)
	local entity = event.entity
	if entity.name == "fluid-temperature-combinator" then
		find_in_global(entity).tank = get_tank(entity)
	end
end

local function on_settings_pasted(event)
	if event.source.name == "fluid-temperature-combinator" and event.destination.name == "fluid-temperature-combinator" then
		find_in_global(event.destination).precise = find_in_global(event.source).precise
	end
end

local function on_destroyed(event)
	local entity = event.entity
	
	if entity.name == "fluid-temperature-combinator" then
		for i = 0, refresh_rate - 1 do
			for ei, combinator in pairs(global.combinators[i]) do
				if combinator.entity == entity then
					table.remove(global.combinators[i], ei)
					return
				end
			end
		end
	end
	if types[entity.type] then
		local area = {
			{entity.position.x - tank_surroundings_check_distance, entity.position.y - tank_surroundings_check_distance},
			{entity.position.x + tank_surroundings_check_distance, entity.position.y + tank_surroundings_check_distance}
		}
		local combinators = entity.surface.find_entities_filtered{area = area, name = "fluid-temperature-combinator"}
		for _, combinator in pairs(combinators) do
			find_in_global(combinator).tank = get_tank(combinator)
		end
	end
end

script.on_init(function()
	global.combinators = global.combinators or {}
	for i = 0, refresh_rate - 1 do
		global.combinators[i] = global.combinators[i] or {}
	end
end)

script.on_configuration_changed(function(data)
	global.combinators = global.combinators or {}
	for i = 0, refresh_rate - 1 do
		global.combinators[i] = global.combinators[i] or {}
	end
	
	if data.mod_changes["fluid-temperature-combinator"] then
		for _, force in pairs(game.forces) do
			if force.technologies["circuit-network"].researched then
				force.recipes["fluid-temperature-combinator"].enabled = true
			end
		end
		
		if data.mod_changes["fluid-temperature-combinator"].old_version == "0.1.2" then
			for _, tab in pairs(global.combinators) do
				for i, v in pairs(tab) do
					v.precise = true
				end
			end
		end
	end
end)

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)

script.on_event(defines.events.on_preplayer_mined_item, on_destroyed)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed)
script.on_event(defines.events.on_entity_died, on_destroyed)

script.on_event(defines.events.on_tick, on_tick)

script.on_event(defines.events.on_player_rotated_entity, on_rotated)

script.on_event(defines.events.on_entity_settings_pasted, on_settings_pasted)
