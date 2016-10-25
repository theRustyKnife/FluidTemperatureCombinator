local name = "fluid-temperature-combinator"

local entity = util.table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
entity.name = name
entity.minable.result = name
entity.item_slot_count = 1

local item = util.table.deepcopy(data.raw["item"]["constant-combinator"])
item.name = name
item.order = "b[combinators]-cb[fluid-temperature-combinator]"
item.place_result = name

local recipe = util.table.deepcopy(data.raw["recipe"]["constant-combinator"])
recipe.name = name
recipe.result = name

table.insert(data.raw.technology["circuit-network"].effects,
	{
		type = "unlock-recipe",
		recipe = "fluid-temperature-combinator"
	}
)

data:extend({entity, item, recipe,
	{
		type = "virtual-signal",
		name = "fluid-temperature",
		icon = "__fluid-temperature-combinator__/graphics/temp.png",
		subgroup = "virtual-signal",
		order = "yyy"
	},
})