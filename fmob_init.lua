dofile(minetest.get_modpath(minetest.get_current_modname()).."/fmob_api.lua")

--Andrey created mob for his world needs

-- Then fast adopted it to run stonesnake


stonesnake:register_mob("stonesnake:stonesnake", {
	type = "monster",
    full_name = 'Stonesnake',
	hp_max = 900,
    health = 400,
    life_span = 180,
	collisionbox = {-0.7, -0.45, -0.7, 0.7, 2.9, 0.7},
	visual = "mesh",
	mesh = "stonesnake.b3d",
	textures = {"snaketail.png"},
	visual_size = {x=1, y=1},
	makes_footstep_sound = true,
	view_range = 20,
	walk_velocity = 2,
	run_velocity = 4,
    stepheight = 1.4,
    jump_height = 1.5,
	attack_damage = 4,
    reach = 5,
	drops = {
        {name = "stonesnake:snake", chance = 1, min = 1,	max = 1,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:mese_crystal", chance = 3, min = 1, max = 2,},
        {name = "default:gold_ingot", chance = 3, min = 1, max = 2,},
        {name = "default:gold_ingot", chance = 3, min = 1, max = 2,},
        {name = "default:gold_ingot", chance = 3, min = 1, max = 2,},
        {name = "default:gold_ingot", chance = 3, min = 1, max = 2,},
        {name = "default:gold_ingot", chance = 3, min = 1, max = 2,},
        {name = "default:gold_ingot", chance = 3, min = 1, max = 2,},
        {name = "default:diamond", chance = 3, min = 1, max = 1,},
        {name = "default:diamond", chance = 3, min = 1, max = 1,},
        {name = "default:diamond", chance = 3, min = 1, max = 1,},
        {name = "default:diamond", chance = 3, min = 1, max = 1,},
        {name = "default:diamond", chance = 3, min = 1, max = 1,},
	},
	armor = 100,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 3,
	light_damage = 0,
	attack_type = "dogfight",
	animation = {
		stand_start = 1,
		stand_end = 40,
		walk_start = 50,
		walk_end = 90,
		run_start = 50,
		run_end = 90,
		punch_start = 100,
		punch_end = 140,
		speed_normal = 15,
		speed_run = 30,
	},
})
-- stonesnake:register_spawn_near("stonesnake:stonesnake", "default:stone", -1, 4, 2)

stonesnake:register_spawn("stonesnake:stonesnake", "default:stone", -1, 14, 1800000, 1, 0, 500)

-- -- DEBUG
-- minetest.register_on_joinplayer(function(player)
--     minetest.after(2, function(player)
--         local pos = player:getpos()
--         minetest.add_entity({x=pos.x, y=pos.y+2, z=pos.z}, "stonesnake:stonesnake")
--     end, player)
-- end)
