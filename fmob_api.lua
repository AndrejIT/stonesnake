-- Andrey experimenting with mobs mod concept
-- Fast adaptation for stonesnake

-- stonesnake = {}

-- Load settings
local damage_enabled = minetest.settings:get_bool("enable_damage")
local peaceful_only = minetest.settings:get_bool("only_peaceful_mobs")
local disable_blood = minetest.settings:get_bool("mobs_disable_blood")
local creative = minetest.settings:get_bool("creative_mode")
local spawn_protected = minetest.settings:get_bool("mobs_spawn_protected") ~= false
-- local remove_far = minetest.settings:get_bool("remove_far_mobs")
local difficulty = tonumber(minetest.settings:get("mob_difficulty")) or 1.0
local show_health = minetest.settings:get_bool("mob_show_health") ~= false
local max_per_block = tonumber(minetest.settings:get("max_objects_per_block") or 99)

local display_mob_spawn = minetest.settings:get_bool("display_mob_spawn")
local only_peaceful_mobs = minetest.settings:get_bool("only_peaceful_mobs")
local enable_damage = minetest.settings:get_bool("enable_damage")

stonesnake.default_parameters = {
    _cmi_is_mob = true,

    type = "monster",
    full_name = "Stone monster",
    physical = true,
    hp_max = 20,
    energy_max = 100,
    life_span = 180,

    view_range = 10,

	visual = "mesh",
    mesh = "mobs_stone_monster.b3d",
    visual_size = {x=1, y=1},
    rotate = 0,
	texture_list = {"mobs_stone_monster.png"},
    child_texture = "mobs_stone_monster.png",
	makes_footstep_sound = true,

    sounds = {
        distance = 8,
        -- random = "horse_neigh.ogg",
        -- damage = "horse_whinney.ogg",
    },

    collisionbox = {-0.4, -0.01, -0.4, 0.4, 1.9, 0.4},

	walk_velocity = 1,
	run_velocity = 3,
    stepheight = 1.4,
    jump = true,
    jump_height = 1.5,
    floats = false,
    fly = false,
    fly_in = "air",

    attack_type = "dogfight",
    attack_damage = 1,
    reach = 2,

    armor = 100,
    light_damage = 0,
    water_damage = 1,
    lava_damage = 2,
    suffocation = 0,
    fall_damage = 1,

    drops = {},
}

stonesnake.default_variables ={

    child = false,
    health = 20,
    energy = 20,

    nametag = "",

    target_entity = nil,    --entity or player
    target_pos = nil,
    command = "stand",  -- "stand", "walk", "pathwalk", "travel", "run", "flee"
    command_timer = 0,
    state =   "stand",  -- "stand", "walk", "jump", "climb", "die"
    state_timer = 0,

    old_y = nil,
    standing_in = "air",
    movement_dir = nil,
    movement_dir_rounded = nil, -- just x or z, 1 or 0, or -1!
    start_jump_y = nil,

    step_timer = 0,
    jump_timer = 0,
    attack_timer = 0,
    punch_timer = 0,
    env_damage_timer = 0,
    health_timer = 0,
    life_timer = 0,
    old_health = nil,

}

stonesnake.default_functions = {

    get_staticdata = function(self)
        local tmp = {
            life_timer = self.life_timer,
            energy = self.energy,
            health = self.health,
        }
        return minetest.serialize(tmp)
    end,

    on_activate = function(self, staticdata, dtime_s)
        if self.type == "monster" and only_peaceful_mobs then
            self.object:remove()
            return
        end
        self.object:set_armor_groups({fleshy=self.armor})
        self.object:set_acceleration({x=0, y=-10, z=0})
        self.state = "stand"
        self.object:set_velocity({x=0, y=self.object:get_velocity().y, z=0})
        -- Face and move random direction
        self:do_change_direction()

        -- expand default on_punch function
        self.on_default_punch = self.on_punch
        self.on_punch = self.on_expanded_punch

        local olddata = {}
        if staticdata then
            olddata = minetest.deserialize(staticdata)
            if olddata then
                if olddata.life_timer then
                    self.life_timer = olddata.life_timer
                end
                if olddata.energy then
                    self.energy = olddata.energy
                end
                if olddata.health then
                    self.health = olddata.health
                end
            end
            -- minetest.log("action", "Recreating mob")
        end

        self.object:set_hp(self.health)
        self.old_health = self.health

        -- change command maybe?
        if olddata and olddata.life_timer then
            self:change_command_maybe("activate")
        else
            self:change_command_maybe("activate_new")
        end
    end,

    -- set_velocity = function(self, v)
    --     local yaw = self.object:get_yaw()
    --     if self.drawtype == "side" then
    --         yaw = yaw+(math.pi/2)
    --     end
    --     local x = math.sin(yaw) * -v
    --     local z = math.cos(yaw) * v
    --     if yaw~=yaw then
    --         minetest.log("error", "mob at wrong position!!!"..yaw)
    --     end
    --     self.object:set_velocity({x=x, y=self.object:get_velocity().y, z=z})
    -- end,
    --set mob speed preserving direction
    set_speed = function(self, s)
        local yaw = self.object:get_yaw()
        if self.drawtype == "side" then
            yaw = yaw+(math.pi/2)
        end
        local dir = yaw_vector(yaw)
        local v = vector.multiply(dir, s)
        self.object:set_velocity(v)
    end,
    --set mob speed and yump preserving direction
    set_jump = function(self, s)
        local yaw = self.object:get_yaw()
        if self.drawtype == "side" then
            yaw = yaw+(math.pi/2)
        end
        local dir = yaw_vector(yaw)
        local v = vector.multiply(dir, s)
        v = vector.add(v, {x=0,y=s*2,z=0})  -- speed up is twice as speed forward
        self.object:set_velocity(v)
    end,

    get_velocity = function(self)
        local v = self.object:get_velocity()
        return (v.x^2 + v.z^2)^(0.5)
    end,

    set_animation = function(self, type)
        if not self.animation then
            return
        end
        if not self.animation.current then
            self.animation.current = ""
        end
        if type == "stand" and self.animation.current ~= "stand" then
            if
                self.animation.stand_start
                and self.animation.stand_end
                and self.animation.speed_normal
            then
                self.object:set_animation(
                    {x=self.animation.stand_start,y=self.animation.stand_end},
                    self.animation.speed_normal, 0
                )
                self.animation.current = "stand"
            end
        elseif type == "walk" and self.animation.current ~= "walk"  then
            if
                self.animation.walk_start
                and self.animation.walk_end
                and self.animation.speed_normal
            then
                self.object:set_animation(
                    {x=self.animation.walk_start,y=self.animation.walk_end},
                    self.animation.speed_normal, 0
                )
                self.animation.current = "walk"
            end
        elseif type == "run" and self.animation.current ~= "run"  then
            if
                self.animation.run_start
                and self.animation.run_end
                and self.animation.speed_run
            then
                self.object:set_animation(
                    {x=self.animation.run_start,y=self.animation.run_end},
                    self.animation.speed_run, 0
                )
                self.animation.current = "run"
            end
        elseif type == "punch" and self.animation.current ~= "punch"  then
            if
                self.animation.punch_start
                and self.animation.punch_end
                and self.animation.speed_normal
            then
                self.object:set_animation(
                    {x=self.animation.punch_start,y=self.animation.punch_end},
                    self.animation.speed_normal, 0
                )
                self.animation.current = "punch"
            end
        end
    end,
    mob_sound = function(self, sound)
    	if sound then
    		minetest.sound_play(sound, {
    			object = self.object,
    			gain = 1.0,
    			max_hear_distance = self.sounds.distance
    		})
    	end
    end,
    -- update nametag colour
    update_tag = function(self)

    	local col = "#00FF00"
    	local qua = self.hp_max / 4

    	if self.health <= math.floor(qua * 3) then
    		col = "#FFFF00"
    	end

    	if self.health <= math.floor(qua * 2) then
    		col = "#FF6600"
    	end

    	if self.health <= math.floor(qua) then
    		col = "#FF0000"
    	end

    	self.object:set_properties({
    		nametag = self.nametag,
    		nametag_color = col
    	})
    end,
    -- drop items
    item_drop = function(self, cmi_cause)
    	-- no drops for child mobs
    	if self.child then return end
        -- no drop if mob died from environment
        if cmi_cause.type == "environment" then
            return
        end

    	local obj, item, num
    	local pos = self.object:get_pos()

    	self.drops = self.drops or {} -- nil check

        -- -- dropped cooked item if mob died in lava
        local cooked = false
        -- if cmi_cause.type == "environment" and cmi_cause.node then
        --     local nodef = minetest.registered_nodes[cmi_cause.node]
        --     if nodef.groups.lava then
        --         cooked = true
        --     end
        -- end

    	for n = 1, #self.drops do
    		if math.random(1, self.drops[n].chance) == 1 then
    			num = math.random(self.drops[n].min, self.drops[n].max)
    			item = self.drops[n].name

    			-- cook items when true
    			if cooked then
    				local output = minetest.get_craft_result({
    					method = "cooking", width = 1, items = {item}
                    })
    				if output and output.item and not output.item:is_empty() then
    					item = output.item:get_name()
    				end
    			end

    			-- add item if it exists
    			obj = minetest.add_item(pos, ItemStack(item .. " " .. num))

    			if obj and obj:get_luaentity() then

    				obj:set_velocity({
    					x = math.random(-10, 10) / 9,
    					y = 6,
    					z = math.random(-10, 10) / 9,
    				})
    			elseif obj then
    				obj:remove() -- item does not exist
    			end
    		end
    	end

    	self.drops = {}
    end,

    -- check if mob is dead or only hurt
    animate_death = function(self, cmi_cause)
        local frames = self.animation.die_end - self.animation.die_start
        local speed = self.animation.die_speed or 15
        local length = max(frames / speed, 0)

        self.state = "die"
        set_velocity(self, 0)
        set_animation(self, "die")

        minetest.after(
            length,
            function(self, cmi_cause)
                self:item_drop(cmi_cause)
                local pos = self.object:get_pos()
                minetest.log("action", "Stonesnake died at "..pos.x..", "..(pos.y+1)..", "..pos.z)
                effect(pos, 20, "tnt_smoke.png")
                self.object:remove()
            end,
            self, cmi_cause
        )
    end,
    check_for_death = function(self, cmi_cause)

    	-- has health actually changed?
    	if self.health == self.old_health and self.health > 0 then
    		return
    	end

    	-- still got some health? play hurt sound
    	if self.health > 0 then
    		-- make sure health isn't higher than max
    		if self.health > self.hp_max then
    			self.health = self.hp_max
    		end

    		-- -- backup nametag so we can show health stats
    		-- if not self.nametag2 then
    		-- 	self.nametag2 = self.nametag or ""
    		-- end

    		if show_health then
    			self.health_timer = 3
    			self.nametag = "♥ " .. self.health .. " / " .. self.hp_max
    			self:update_tag()
    		end

            -- self:mob_sound(self.sounds.damage)

    		return false
    	else
        	-- execute custom death function
            local proceed_die = true
        	if self.on_die and self.on_die(self, cmi_cause) == false then
                proceed_die = false
            end

            -- Not used at the moment
        	-- if proceed_die and use_cmi and cmi.notify_die(self.object, cmi_cause) == false then
            --     proceed_die = false
        	-- end

            if proceed_die then
                self.state = "die"
                -- mob_sound(self, self.sounds.death)
                if self.animation
            	   and self.animation.die_start
            	   and self.animation.die_end
                then
                    self:animate_death(cmi_cause)
                else
                    self:item_drop(cmi_cause)
                    local pos = self.object:get_pos()
                    minetest.log("action", "Stonesnake died at "..pos.x..", "..(pos.y+1)..", "..pos.z)
                    effect(pos, 20, "tnt_smoke.png")
            		self.object:remove()
                end
                return true
        	else
            	return false
            end
        end
    end,

    -- is mob facing a cliff
    is_at_cliff = function(self)
        local fear_height = 5

    	if fear_height == 0 then -- 0 for no falling protection!
    		return false
    	end

    	local yaw = self.object:get_yaw()
    	local dir_x = -math.sin(yaw) * (self.collisionbox[4] + 0.5)
    	local dir_z = math.cos(yaw) * (self.collisionbox[4] + 0.5)
    	local pos = self.object:get_pos()
    	local ypos = pos.y + self.collisionbox[2] -- just above floor

    	if minetest.line_of_sight(
    		{x = pos.x + dir_x, y = ypos, z = pos.z + dir_z},
    		{x = pos.x + dir_x, y = ypos - fear_height, z = pos.z + dir_z}
    	, 1) then

    		return true
    	end

    	return false
    end,
    -- if light in front is stronger and may be dangerous
    is_at_light = function(self)
        local pos = self:head_pos()
        local current_light = minetest.get_node_light(pos) or 0
        local expected_light = minetest.get_node_light(get_pos_relative(pos, {x=2,y=0,z=0}, self.movement_dir_rounded)) or 0
        if expected_light > 11 and expected_light > current_light then
            return true
        else
            return false
        end
    end,
    -- what node is mob standing in?
    foot_pos = function(self)
        local pos = self.object:get_pos()
        local y_level = self.collisionbox[2]
    	if self.child then
    		y_level = y_level * 0.5
        end
        pos.y = pos.y + y_level + 0.25 -- foot level
        return pos
    end,
    head_pos = function(self)
        local pos = self.object:get_pos()
        local y_level = self.collisionbox[5]
    	if self.child then
    		y_level = y_level * 0.5
        end
        pos.y = pos.y + y_level - 0.25 -- head level
        return pos
    end,
    -- wery lazy, i know ...
    can_walk_forward = function(self)
        local pos = self.object:get_pos()
    	pos.y = pos.y + self.collisionbox[2] -- just above floor
        if not is_walkable(get_pos_relative(pos, {x=1,y=0,z=0}, self.movement_dir_rounded)) and not is_walkable(get_pos_relative(pos, {x=1,y=1,z=0}, self.movement_dir_rounded)) then
            return true
        else
            return false
        end
    end,
    can_jump_forward = function(self)
        local pos = self.object:get_pos()
    	pos.y = pos.y + self.collisionbox[2] -- just above floor
        if not is_walkable(get_pos_relative(pos, {x=1,y=0,z=0}, self.movement_dir_rounded)) and not is_walkable(get_pos_relative(pos, {x=1,y=1,z=0}, self.movement_dir_rounded)) then
            return true
        elseif self.jump_height > 1 and not is_walkable(get_pos_relative(pos, {x=1,y=1,z=0}, self.movement_dir_rounded)) and not is_walkable(get_pos_relative(pos, {x=1,y=2,z=0}, self.movement_dir_rounded)) then
            return true
        elseif self.jump_height > 2 and not is_walkable(get_pos_relative(pos, {x=1,y=2,z=0}, self.movement_dir_rounded)) and not is_walkable(get_pos_relative(pos, {x=1,y=3,z=0}, self.movement_dir_rounded)) then
            return true
        else
            return false
        end
    end,
    -- Find location of player up to 120 nodes away - usually just as approximate direction to walk to
    -- Returns location, not player!
    look_for_player_far = function(self)
        local pos = self.object:get_pos()
        if pos then
            for _,player in pairs(minetest.get_connected_players()) do
                if math.random(1, 100) > 20 and player and player:is_player() then
                    local p = player:get_pos()
                    local dist = vector.distance(pos, p)
                    if dist and dist < 120 then
                        return p -- location of any first player seen
                    end
                end
            end
        end
        return nil
    end,
    -- Look for player in view_range. which is not current target
    -- Return player object
    look_for_player_around = function(self)
        local pos = self.object:get_pos()
        -- look forward and little around self
        local p = get_pos_relative(pos, {x=math.floor(self.view_range * 0.7),y=0,z=0}, self.movement_dir_rounded)
        for _,object in pairs(minetest.get_objects_inside_radius(p, self.view_range)) do
            if object ~= self.target_entity and object:is_player() then
                return object
            end
            -- chance to not notice player, especially if too many objects around
            if math.random(1, 100) > 95 then
                return nil
            end
        end
        return nil
    end,
    -- Look for player in close proximity
    -- Return player object
    look_for_player_close = function(self)
        local pos = self.object:get_pos()
        for _,object in pairs(minetest.get_objects_inside_radius(pos, self.reach * 2)) do
            if object:is_player() then
                return object
            end
        end
        return nil
    end,
    -- look_for dropped item in view_range. which is not current target
    look_for_items_around  = function(self)
        local pos = self.object:get_pos()
        -- look forward and little around self
        local p = get_pos_relative(pos, {x=math.floor(self.view_range * 0.7),y=0,z=0}, self.movement_dir_rounded)
        for _,object in pairs(minetest.get_objects_inside_radius(p, self.view_range)) do
            -- minetest.get_item_group(object.name, "immortal") > 0  is wrong
            if object ~= self.target_entity and object ~= self.object and not object:is_player() then
                local groups = object:get_armor_groups()
                if groups and groups.immortal then
                    -- dropped items or immortal cart
                    local item_name = object:get_luaentity().name
                    if item_name == '__builtin:item' or item_name == 'carts:cart' then
                        return object
                    end
                end
            end
            -- chance to not notice item, especially if too many objects around
            if math.random(1, 100) > 90 then
                return nil
            end
        end
        return nil
    end,
    -- Look for dropped item in close proximity
    look_for_items_close = function(self)
        local pos = self.object:get_pos()
        for _,object in pairs(minetest.get_objects_inside_radius(pos, self.reach * 2)) do
            if object ~= self.object and not object:is_player() then
                local groups = object:get_armor_groups()
                if groups and groups.immortal then
                    -- dropped items or immortal cart
                    local item_name = object:get_luaentity().name
                    if item_name == '__builtin:item' or item_name == 'carts:cart' then
                        return object
                    end
                end
            end
        end
        return nil
    end,
    -- look for interesting nodes nearby
    look_for_nodes = function(self)
        local pos = self.object:get_pos()
        -- look forward and little around self
        local p = get_pos_relative(pos, {x=math.floor(self.view_range * 0.7),y=0,z=0}, self.movement_dir_rounded)

        -- just dummy function for now
        -- Need to search for accesible nodes ... like exposed under the air

        return nil
    end,
    -- look for where to hide from light damage
    look_for_shelter = function(self)
        local pos = self:head_pos()
        local current_light = minetest.get_node_light(pos) or 0
        local better_pos = nil
        -- look around self
        local places = minetest.find_nodes_in_area({x=pos.x-self.view_range, y=pos.y-3, z=pos.z-self.view_range}, {x=pos.x+self.view_range, y=pos.y+4, z=pos.z+self.view_range}, {"air"})
        if #places > 1 then
            for i=1,10,1 do
                local new_pos = places[math.random(1, #places-1)]
                local new_light = minetest.get_node_light(new_pos)
                if current_light > new_light then
                    current_light = new_light
                    better_pos = new_pos
                end
            end
        end

        return better_pos
    end,

    do_jump = function(self)
        local pos = self.object:get_pos()
        self.start_jump_y = pos.y
        self:set_jump(self.run_velocity)
        self.state = "jump"
        self.jump_timer = 3
        self:set_animation("run")
    end,
    -- select random direction
    do_change_direction = function(self)
        local yaw = math.random(1, 360)/180*math.pi
        self.object:set_yaw(yaw)
        self.movement_dir = yaw_vector(yaw)
        -- Actually maybe it is bad idea to use get_pos_relative() in these cases, but i dont want spend my energy for this.
        self.movement_dir_rounded = {x=0,y=0,z=0}
        if math.abs(self.movement_dir.x) > math.abs(self.movement_dir.x) then
            if self.movement_dir.x > 0 then
                self.movement_dir_rounded.x = 1
            else
                self.movement_dir_rounded.x = -1
            end
        else
            if self.movement_dir.z > 0 then
                self.movement_dir_rounded.z = 1
            else
                self.movement_dir_rounded.z = -1
            end
        end
    end,
    -- check if attack can be done and do it
    do_attack = function(self)
        if not self.target_entity then
            return false
        end

        -- if attached to sometting, then attack that thing first if possible
        local object,_,_,_ = self.target_entity:get_attach()
        if object == nil then
            object = self.target_entity
        end
        if not object:is_player() then
            local groups = object:get_armor_groups()
            if groups and groups.immortal then
                -- local target_entity = object:get_luaentity()
                -- minetest.chat_send_all(target_entity.name..'is immortal!')
                return false
            end
        end

        if object:get_hp() <= 0 then
            return false
        end

        local pos = self.object:get_pos()
        local target_pos = object:get_pos()
        if target_pos and vector.distance(pos, target_pos) < self.reach then
            local tmp_dir = self.movement_dir or {x=0, y=1, z=0}
            object:punch(self.target_entity, 1.0,  {
                    full_punch_interval=1.0,
                    damage_groups = {fleshy=self.attack_damage}
                }, tmp_dir)
            -- monsters gain energy for attacking players or their vehicles
            if self.type == "monster" and self.energy < self.energy_max then
                self.energy = self.energy + 5
            end
            return true
        else
            return false
        end
    end,
    -- check if item can be collected and collect (for now, just consume collected items)
    do_collect = function(self)
        if not self.target_entity then
            return false
        end

        local object = self.target_entity

        if not object:is_player() then
            local groups = object:get_armor_groups()
            if groups and groups.immortal then
                local item_name = object:get_luaentity().name
                if item_name == '__builtin:item' or item_name == 'carts:cart' then
                    object:remove()
                    if self.type == "monster" and self.energy < self.energy_max then
                        self.energy = self.energy + 2
                    end
                    return true
                end
            end
        end
        return false
    end,
    do_selfheal = function(self)
        if self.health < self.hp_max then
            local missing_hp = self.hp_max - self.health
            if missing_hp < self.energy then
                self.energy = self.energy - missing_hp
                self.health = self.hp_max
                self.object:set_hp(self.health)
                if show_health then
                    self.health_timer = 3
                    self.nametag = "♥ " .. self.health .. " / " .. self.hp_max
                    self:update_tag()
                end
                return true
            end
        end
        return false
    end,

    on_step = function(self, dtime)
        if self.state == "die" then
            return
        end

        self.env_damage_timer = self.env_damage_timer + dtime
        self.life_timer = self.life_timer + dtime
        if self.health_timer > 0 then
            self.health_timer = self.health_timer - dtime
            if self.health_timer <= 0 then
                self.health_timer = 0
                self.nametag = ""
                self:update_tag()
            end
        end
        self.step_timer = self.step_timer + dtime
        if self.jump_timer > 0 then
            self.jump_timer = self.jump_timer - dtime
            if self.jump_timer <= 0 then
                self.jump_timer = 0
                if self.state == "jump" then
                    self.state = "stand"
                end
            end
        end
        self.attack_timer = self.attack_timer + dtime

        -- Use energy to reset life timer. Remove mob when life timer and energy runs out.
        -- By default mob has 3 x 20 = 60 minutes
        if self.life_timer >= self.life_span then
            if self.energy >= 1 then
                self.energy = self.energy - 1
                self.life_timer = 0
            else
                self.object:remove()
                return
            end
        end

        local pos = self.object:get_pos()
        local fpos = self:foot_pos()
        local hpos = self:head_pos()
        local tpos = nil    -- target pos if any

        if self.step_timer > 1 or self.attack_timer > 1 then
            if self.target_entity then
                tpos = self.target_entity:get_pos()
            end
        end

        -- Enviroment damage every 3 seconds
        if self.env_damage_timer > 3 then
            self.env_damage_timer = 0
            self.standing_in = node_ok(fpos).name
            local head_in = node_ok(hpos).name

            -- I hawe no idea what is better - minetest.get_item_group() or minetest.registered_nodes[]
            local fnodef = minetest.registered_nodes[self.standing_in]
            local hnodef = minetest.registered_nodes[head_in]

            if self.light_damage ~= 0
                and pos.y > 0
                and minetest.get_timeofday() > 0.2
                and minetest.get_timeofday() < 0.8
                and (minetest.get_node_light(hpos) or 0) > 11
            then
                self.health = self.health - self.light_damage
                effect(hpos, 5, "tnt_smoke.png")
                if self:check_for_death({
                    type = "environment",
                    pos = pos,
                    node = head_in})
                then
                    return
                end
                self.object:set_hp(self.health)
                -- change command maybe?
                if self:change_command_maybe("damage_light") then
                    return
                end
            end

            if
                self.water_damage ~= 0
                and hnodef.groups.water
            then
                self.health = self.health - self.water_damage
                effect(hpos, 5, "bubble.png", nil, nil, 1, nil)
                if self:check_for_death({
                    type = "environment",
                    pos = pos,
                    node = head_in})
                then
                    return
                end
                self.object:set_hp(self.health)
                -- change command maybe?
                if self:change_command_maybe("damage_water") then
                    return
                end
            elseif
                self.lava_damage ~= 0
                and fnodef.groups.lava
            then
                self.health = self.health - self.lava_damage
                effect(pos, 5, "fire_basic_flame.png", nil, nil, 1, nil)
                if self:check_for_death({
                    type = "environment",
                    pos = pos,
                    node = self.standing_in})
                then
                    return
                end
                self.object:set_hp(self.health)
                -- change command maybe?
                if self:change_command_maybe("damage_lava") then
                    return
                end
            end

            self.old_health = self.health
        end

        -- Movement recalculation every 1 second
        if self.step_timer > 1 then
            self.step_timer = 0
            -- Gravity ...
            if self.state == "climb" then
                self.object:set_acceleration({x=0, y=0, z=0})
            elseif self.fly and self.standing_in == self.fly_in and self.state == "stand" then
                self.object:set_acceleration({x=0, y=0, z=0})
            elseif self.fly and self.standing_in == self.fly_in then
                self.object:set_acceleration({x=0, y=-1, z=0})
            elseif self.floats and minetest.registered_nodes[self.standing_in].groups.water then
                self.object:set_acceleration({x=0, y=5, z=0})
            else
                self.object:set_acceleration({x=0, y=-10, z=0})
            end
            -- Fall damage
            if self.fall_damage and self.object:get_velocity().y == 0 then
                if not self.old_y then
                    self.old_y = pos.y
                else
                    local d = self.old_y - pos.y
                    if d > 5 then
                        local damage = (d - 5) * self.fall_damage
                        self.health = self.health - math.floor(damage)
                        effect(fpos, 5, "tnt_smoke.png")
                        if self:check_for_death({type = "fall"}) then
                            return
                        end
                        self.object:set_hp(self.health)
                        -- change command maybe?
                        if self:change_command_maybe("damage_fall") then
                            return
                        end
                    end
                    self.old_y = pos.y
                end
            end

            -- "stand", "walk", "pathwalk", "travel", "run", "flee"
            -- "stand", "walk", "jump", "climb", "die"
            if self.command == "stand" then
                -- change command maybe?
                if self:change_command_maybe("standing") then
                    return
                end
            elseif self.state == "jump" then
                if pos.y >= (self.start_jump_y + self.jump_height)
                    or pos.y <= self.start_jump_y
                then
                    if self.command == "walk" or self.command == "pathwalk" or self.command == "travel" then
                        self:set_speed(self.walk_velocity)
                        self.state = "walk"
                        self:set_animation("walk")
                    else
                        self:set_speed(self.run_velocity)
                        self.state = "walk"
                        self:set_animation("run")
                    end
                end
                -- i am tired and writing code like zombie
            else
                -- Refresh target pos
                if
                    self.target_entity and
                    self.command == "flee" and
                    tpos
                then
                    local tmp_dir = vector.direction(tpos, pos)
                    tmp_dir.y = 0
                    self.target_pos = vector.add(pos, vector.multiply(tmp_dir, 4))
                elseif
                    self.target_entity
                then
                    self.target_pos = tpos
                end
                -- Find next step and go there...
                -- Well, for simplicity lets use built-in path-finding function...
                -- Using it every second will be too resource ineffective, lets improve later.

                local next_step_pos = nil -- get_pos_relative(pos, self.movement_dir, {x=1,y=0,z=0})
                if not self.target_pos then
                    -- change command maybe?
                    if self:change_command_maybe("target_none") then
                        return
                    end
                elseif vector.distance(pos, self.target_pos) < self.reach then
                    -- change command maybe?
                    if self:change_command_maybe("target_reached") then
                        return
                    end
                elseif vector.distance(pos, self.target_pos) > 32 then
                    -- change command maybe?
                    if self:change_command_maybe("target_away") then
                        return
                    end
                elseif vector.distance(pos, self.target_pos) > 16 then
                    next_step_pos = self.target_pos
                elseif self.command == "pathwalk" then
                    local path_way = minetest.find_path(pos, self.target_pos, 16, self.stepheight, 5, "Dijkstra")
                    if path_way and path_way[1] then
                        next_step_pos = path_way[1]
                        if vector.distance(vector.round(pos), vector.round(next_step_pos)) < 1 and path_way and path_way[2] then
                            next_step_pos = path_way[2]
                        end
                    end
                else
                    next_step_pos = self.target_pos
                end
                -- Decide actual direction, movement/jump, speed. No climb yet...
                if next_step_pos then
                    self.movement_dir = vector.direction(pos, next_step_pos)
                    -- Actually maybe it is bad idea to use get_pos_relative() in these cases, but i dont want spend my energy for this.
                    self.movement_dir_rounded = {x=0,y=0,z=0}
                    if math.abs(self.movement_dir.x) > math.abs(self.movement_dir.x) then
                        if self.movement_dir.x > 0 then
                            self.movement_dir_rounded.x = 1
                        else
                            self.movement_dir_rounded.x = -1
                        end
                    else
                        if self.movement_dir.z > 0 then
                            self.movement_dir_rounded.z = 1
                        else
                            self.movement_dir_rounded.z = -1
                        end
                    end
                else
                    -- Last chance to
                    -- change command maybe?
                    if self:change_command_maybe("path_none") then
                        return
                    end
                end

                if
                    self.command == "walk" or
                    self.command == "travel" or self.command == "run" or
                    self.command == "flee"
                then
                    if not self:can_walk_forward() then
                        -- change command maybe?
                        if self:change_command_maybe("path_bump") then
                            return
                        end
                    elseif self:is_at_cliff() then
                        -- change command maybe?
                        if self:change_command_maybe("path_fall") then
                            return
                        end
                    elseif self:is_at_light() then
                        -- change command maybe?
                        if self:change_command_maybe("path_light") then
                            return
                        end
                    end
                end

                self.object:set_yaw(vector_yaw(self.movement_dir))
                if self:get_velocity() < 0.1 then
                    -- change command maybe?
                    if self:change_command_maybe("path_bump") then
                        return
                    end
                elseif self.command == "walk" or self.command == "pathwalk" or self.command == "travel" then
                    self:set_speed(self.walk_velocity)
                    self.state = "walk"
                    self:set_animation("walk")
                else
                    self:set_speed(self.run_velocity)
                    self.state = "walk"
                    self:set_animation("run")
                end

                if next_step_pos and pos.y < next_step_pos.y then
                    self:do_jump()
                end
            end
        end

        -- chance to do attack every 1 second
        if self.attack_timer > 1 then
            self.attack_timer = 0
            if self.target_pos and self.target_entity and vector.distance(pos, self.target_pos) < self.reach then
                -- change command maybe?
                if self:change_command_maybe("interaction_possible") then
                    return
                end
            end
        end
    end,

    on_expanded_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
        if self.state == "die" then
            return false
        end

        -- debug
        -- minetest.chat_send_all('State: ' .. self.state .. ' Command: ' .. self.command)

        self.punch_timer = self.punch_timer + time_from_last_punch

        local result = self:on_default_punch(puncher, time_from_last_punch, tool_capabilities, direction, damage)

        self.health = self.health - damage

        -- Additional damage maybe

        if self:check_for_death({type = "punch"}) then
            result = false
        end

        if self.punch_timer >= 1 then
            self.punch_timer = 0
            -- change command maybe?
            if self:change_command_maybe("punched", puncher) then
                return
            end
        end

        -- tool wear (additional)
        if self.health < self.old_health then
            if puncher and puncher:is_player() and puncher:get_wielded_item() then
                local itemstack = puncher:get_wielded_item()
                local pos = puncher:get_pos()
                itemstack = add_tool_wear(itemstack, pos)
                puncher:set_wielded_item(itemstack)
            end
        end

        self.old_health = self.health
        return result
    end,
    -- Here is original punch function stored when owerriden
    on_default_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
        return true
    end,

    -- "activate_new", "activate", "standing", "path_bump",
    -- "target_none", "target_away", "target_reached",
    -- "path_none", "path_lava", "path_water", "path_light", "path_fall",
    -- "punched", "damage_lava", "damage_water", "damage_light", "damage_fall"
    -- "interaction_possible", "attack_done", "attack_none"
    change_command_maybe = function(self, reason, target_new)
        if (reason == "activate_new" or reason == "activate") then
            -- find nearest player and walk approximate direction
            local good_position = self:look_for_player_far()
            if good_position then
                self.target_pos = good_position
                self.command = "travel"  -- "stand", "walk", "travel", "run", "flee"
            end
        elseif reason == "standing" and math.random(1, 100) > 95 then
            if self:do_selfheal() then
                return true
            end
        elseif reason == "standing" and math.random(1, 100) > 95 then
            local item = self:look_for_items_around()
            if item then
                self.target_entity = item
                self.command = "walk"
            end
        elseif reason == "standing" and math.random(1, 100) > 80 then
            local player = self:look_for_player_around()
            if player then
                self.target_entity = player
                self.command = "walk"
            end
        elseif (reason == "target_none" or reason == "target_away" or reason == "attack_none" or reason == "target_reached") then
            -- minetest.chat_send_all('oh no'..self.state.."  "..self.step_timer)
            local player = self:look_for_player_close()
            if player then
                self.target_entity = player
                self.command = "walk"
                return false -- continue to attack
            end
            local item = self:look_for_items_close()
            if item then
                self.target_entity = item
                self.command = "walk"
                return true
            end
            self.target_entity = nil
            self.command = "stand"
            return true
        elseif reason == "attack_done" and math.random(1, 100) > 90  then
            self:do_selfheal()
        elseif reason == "path_none" and self.command == "attack" and math.random(1, 100) > 10 then
            self:do_selfheal()
        elseif reason == "path_bump" and math.random(1, 100) > 10 then
            self:do_jump()
        elseif (reason == "path_bump" or reason == "path_none" or reason == "path_lava" or reason == "path_water" or reason == "path_light" or reason == "path_fall") and math.random(1, 100) > 50 then
            self.command = "pathwalk"
        elseif (reason == "path_bump" or reason == "path_none" or reason == "path_lava" or reason == "path_water" or reason == "path_light" or reason == "path_fall") and math.random(1, 100) > 50 then
            self:do_change_direction()
        elseif (reason == "path_bump" or reason == "path_none" or reason == "path_lava" or reason == "path_water" or reason == "path_light" or reason == "path_fall") then
            self:set_speed(0)
            self.target_entity = nil
            self.command = "stand"
        elseif reason == "punched" and target_new and math.random(1, 100) > 80 then
            self.target_entity = target_new
            self.command = "flee"
        elseif reason == "punched" and target_new then
            self.target_entity = target_new
            self.command = "attack"
        elseif reason == "interaction_possible" then
            local attack = self:do_attack()
            if not attack then
                self:do_collect()
                self.target_entity = nil
                self.command = "stand"
            end
            if attack then
                -- change command maybe?
                if self:change_command_maybe("attack_done") then
                    return
                end
            else
                -- change command maybe?
                if self:change_command_maybe("attack_none") then
                    return
                end
            end
        elseif reason == "damage_light" and math.random(1, 100) > 50 then
            local shelter = self:look_for_shelter()
            if shelter then
                self.target_pos = shelter
                self.command = "run"
            end
        end
    end,
}


-- mobs.movebeat = 0.25
-- mobs.damagebeat = 1.0
-- mobs.thinkbeat = 3.0

function stonesnake:register_mob(name, def)
    local definition = {}
    for key,val in pairs(stonesnake.default_parameters) do
        definition[key] = val
    end
    for key,val in pairs(stonesnake.default_variables) do
        definition[key] = val
    end
    for key,val in pairs(stonesnake.default_functions) do
        definition[key] = val
    end
    for key,val in pairs(def) do
        definition[key] = val
    end
    minetest.register_entity(name, definition)
end

stonesnake.spawning_mobs = {}
function stonesnake:register_spawn(name, nodes, min_light, max_light, chance, active_object_count, min_height, max_height, spawn_func)
    -- temporary accept both cases for light order
    if min_light > max_light then
        local tmp_light = min_light
        min_light = max_light
        max_light = tmp_light
    end
	stonesnake.spawning_mobs[name] = true
	minetest.register_abm({
		nodenames = nodes,
		neighbors = {"air"},
		interval = 10,
		chance = chance,
        catch_up = true,
		action = function(pos, node, _, active_object_count_wider)
			if active_object_count_wider > active_object_count then
				return
			end
			if not stonesnake.spawning_mobs[name] then
				return
			end
			local pos2={x=pos.x, y=pos.y+2, z=pos.z}
			if minetest.get_node(pos2).name ~= "air" then
				return
			elseif minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air" then
				return
			elseif not minetest.get_node_light(pos2) then
				return
			elseif minetest.get_node_light(pos2) > max_light then
				return
			elseif minetest.get_node_light(pos2) < min_light then
				return
			elseif max_height and pos.y > max_height then
				return
			elseif min_height and pos.y < min_height then
				return
			end

			if spawn_func and not spawn_func(pos, node) then
				return
			end

			if display_mob_spawn then
				minetest.chat_send_all("[mobs] Add "..name.." at "..minetest.pos_to_string(pos))
			end
			minetest.log("action", "Adding mob "..name.." on block "..nodes.." at "..pos.x..", "..(pos.y+1)..", "..pos.z)
			minetest.add_entity({x=pos.x, y=pos.y+1, z=pos.z}, name)
		end
	})
end

--for Andrey world usage
stonesnake.spawning_mobs_near = {}
function stonesnake:register_spawn_near(name, nodes, min_light, max_light, tries)
	stonesnake.spawning_mobs_near[name] = true

	local timer = 0
	minetest.register_globalstep(function(dtime)
		timer = timer + dtime;
		if timer >= 30 then
			for _,player in pairs(minetest.get_connected_players()) do
				if math.random(1, 100) > 10 and player and player:is_player() then
					local pos_player = player:get_pos()
					local add_mob=true
					if pos_player.x>-1500 and pos_player.x<1500 and pos_player.z>-1500 and pos_player.z<1500 and pos_player.y>-80 then
					--if pos_player.x>-500 and pos_player.x<500 and pos_player.z>-500 and pos_player.z<500 and pos_player.y>-80 then
						add_mob=false
					end

					if add_mob then
						local positions = minetest.find_nodes_in_area(
						{x=pos_player.x-10, y=pos_player.y-7, z=pos_player.z-10},
						{x=pos_player.x+10, y=pos_player.y+4, z=pos_player.z+10},
						"air")
						for i=1, tries do
							if #positions>1 and add_mob then
								local pos = positions[math.random(1, #positions-1)]
								for i=1, 7 do
									if minetest.get_node({x=pos.x, y=pos.y, z=pos.z}).name == "air" then
										pos={x=pos.x, y=pos.y-1, z=pos.z}
									end
								end
								local pos2={x=pos.x, y=pos.y+2, z=pos.z}

								if minetest.get_node(pos).name ~= nodes then
									add_mob=false
								elseif minetest.get_node(pos2).name ~= "air" then
									add_mob=false
								elseif not minetest.get_node_light(pos2) then
									add_mob=false
								elseif minetest.get_node_light(pos2) > max_light then
									add_mob=false
								elseif minetest.get_node_light(pos2) < min_light then
									add_mob=false
								end

								if add_mob then
									minetest.log("action", "Adding mob "..name.." at "..pos.x..", "..(pos.y+1)..", "..pos.z)
									minetest.add_entity({x=pos.x, y=pos.y+1, z=pos.z}, name)
									add_mob=false
								end
							end
						end
					end
				end
			end
			timer=0
		end
	end)
end

function stonesnake:register_arrow(name, def)
	minetest.register_entity(name, {
		physical = false,
		visual = def.visual,
		visual_size = def.visual_size,
		textures = def.textures,
		velocity = def.velocity,
		hit_player = def.hit_player,
		hit_node = def.hit_node,

		on_step = function(self, dtime)
			local pos = self.object:get_pos()
			if minetest.get_node(self.object:get_pos()).name ~= "air" then
				self.hit_node(self, pos, node)
				self.object:remove()
				return
			end
			pos.y = pos.y-1
			for _,player in pairs(minetest.get_objects_inside_radius(pos, 1)) do
				if player:is_player() then
					self.hit_player(self, player)
					self.object:remove()
					return
				end
			end
		end
	})
end
