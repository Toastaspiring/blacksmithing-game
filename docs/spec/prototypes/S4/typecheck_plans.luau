return {
	Sword = {
		equipmentType = "Sword",
		steps = {
			{ step = "Smelting",   weight = 0.25, worksOn = "All",         feeds = { "Purity" } },
			{ step = "Hammering",  weight = 0.40, worksOn = "All",         feeds = { "Damage", "Durability" } },
			{ step = "Sharpening", weight = 0.35, worksOn = { "Blade" },   feeds = { "Sharpness", "Damage" } },
		},
	},
}

