dofile(minetest.get_modpath(minetest.get_current_modname()).."/functions.lua")

stonesnake = {}

dofile(minetest.get_modpath(minetest.get_current_modname()).."/fmob_init.lua")

stonesnake.max_length = tonumber(minetest.settings:get("stonesnake_max_length") or 64)
stonesnake.min_highscore = tonumber(minetest.settings:get("stonesnake_min_highscore") or 8)
stonesnake.snakes = {}

-- SNAKE DEF START
stonesnake.snake = {}
stonesnake.snake.owner = ''
stonesnake.snake.alive = true
stonesnake.snake.entity = nil
stonesnake.snake.score = 0
stonesnake.snake.head = {
    pos = nil,
    tail = nil,
    dir = nil
}
stonesnake.snake.old_tail = nil
stonesnake.snake.in_air = 0
stonesnake.snake.dir = nil
stonesnake.snake.left = false
stonesnake.snake.right = false
stonesnake.snake.timer = 0  -- limit how often player controls are checked
stonesnake.snake.command_timer = 0  -- prevent accidental consecutive left or right turns
stonesnake.snake.pos_new = function(self)
    if self.left then
        return get_pos_relative(self.head.pos, {x=0, y=0, z=1}, self.dir)
    elseif self.right then
        return get_pos_relative(self.head.pos, {x=0, y=0, z=-1}, self.dir)
    else
        return get_pos_relative(self.head.pos, {x=1, y=0, z=0}, self.dir)
    end
end
stonesnake.snake.dir_new = function(self)
    if self.left then
        return vector.direction(self.head.pos, get_pos_relative(self.head.pos, {x=0, y=0, z=1}, self.dir))
    elseif self.right then
        return vector.direction(self.head.pos, get_pos_relative(self.head.pos, {x=0, y=0, z=-1}, self.dir))
    else
        return vector.direction(self.head.pos, get_pos_relative(self.head.pos, {x=1, y=0, z=0}, self.dir))
    end
end
stonesnake.snake.head_new = function(self)
    local pos_old = self.head.pos
    local pos_new = self:pos_new()
    local dir_new = self:dir_new()
    local head_new = {
        pos = pos_new,
        tail = nil,
        dir = dir_new
    }
    head_new.tail = self.head
    self.head = head_new

    self.left = nil
    self.right = nil

    self.dir = dir_new

    if self.entity then
        self.entity:set_move(pos_old)

        -- v = vector.multiply(vector.normalize(dir_new), 4)
        -- self.entity:set_velocity(v)
        self.entity:set_yaw(dir_new)
    end
end
stonesnake.snake.drag = function(self)
    local x1 = self.head
    while x1.tail do
        local pos_above = get_pos_relative(x1.pos, {x=0, y=1, z=0}, x1.dir)
        local objs = minetest.get_objects_inside_radius(pos_above, 1)
        for _, obj in pairs(objs) do
            if minetest.is_player(obj) then
                obj:add_velocity(vector.multiply(x1.dir, 3.95))
            else
                obj:set_velocity(vector.multiply(x1.dir, 3.95))
            end
        end
        x1 = x1.tail
    end
end
stonesnake.snake.die = function(self)
    if self.alive == false then
        return
    end
    self.alive = false
    local x1 = self.head
    local x2 = self.head
    local node = minetest.get_node_or_nil(x2.pos)
    if node and (node.name == 'default:cobble' or node.name == 'stonesnake:cobble') then
        minetest.set_node(x2.pos, {name="air"})
    end
    effect(x2.pos, 20, "tnt_smoke.png")
    while x1.tail do
        x2 = x1
        x1 = x1.tail
        minetest.set_node(x1.pos, {name="air"})
        effect(x1.pos, 20, "tnt_smoke.png")
    end
    local node = minetest.get_node_or_nil(x1.pos)
    if node and (node.name == 'default:cobble' or node.name == 'stonesnake:cobble') then
        minetest.set_node(x1.pos, {name="air"})
    end
    effect(x1.pos, 20, "tnt_smoke.png")

    if self.entity then
        self.entity:set_velocity(false)
    end

    if self.entity and self.entity.driver then
        if self.score > stonesnake.min_highscore then
            local is_highscore = stonesnake:update(self.entity.driver, self.score)
            if is_highscore then
                minetest.chat_send_all("Player '"..self.entity.driver.."' got new highscore "..self.score.." in stonesnake game. See /stonesnake for list.")
                stonesnake:prize_drop(self.head.pos)
            elseif self.entity.driver then
                minetest.chat_send_player(self.entity.driver, "You scored "..self.score.." in stonesnake game.")
            end
        end
        minetest.log("action", "Player "..self.entity.driver.." ended stonesnake game. Score: "..self.score)
    end

    if self.entity then
        self.entity.snake_object = nil
    end
end
-- SNAKE DEF END

stonesnake.add_snake = function(pos, dir, player_name)
    local snake = {}
    setmetatable(snake, {__index = stonesnake.snake})
    snake.head.pos = vector.new(pos)
    snake.dir = vector.new(dir)
    snake.owner = player_name
    table.insert(stonesnake.snakes, snake)
    return snake
end

-- When snake go to next node
stonesnake.step = function()
    -- Remove old snakes
    for id,snake in pairs(stonesnake.snakes) do
        if snake.alive == false then
            table.remove(stonesnake.snakes, id)
        end
    end

    -- Put cobble at head
    for _,snake in pairs(stonesnake.snakes) do
        local node = minetest.get_node_or_nil(snake.head.pos)
        if node and node.name == 'air' then
            -- minetest.chat_send_all(snake.owner)
            if snake.owner == stonesnake.champion_active then
                minetest.set_node(snake.head.pos, {name="stonesnake:cobble"})
            else
                minetest.set_node(snake.head.pos, {name="default:cobble"})
            end
        end
    end

    -- Eat stone at new head, ignore air, or die.
    for id,snake in pairs(stonesnake.snakes) do
        local pos_new = snake:pos_new()
        local pos_above = get_pos_relative(snake.head.pos, {x=0, y=1, z=0}, snake.head.dir)
        local pos_under_new = get_pos_relative(pos_new, {x=0, y=-1, z=0}, snake.head.dir)
        local pos_above_new_1 = get_pos_relative(pos_new, {x=0, y=1, z=0}, snake.head.dir)
        local pos_above_new_2 = get_pos_relative(pos_new, {x=0, y=2, z=0}, snake.head.dir)
        local node = minetest.get_node_or_nil(pos_new)
        local node_under = minetest.get_node_or_nil(pos_under_new)
        local node_above_1 = minetest.get_node_or_nil(pos_above_new_1)
        local node_above_2 = minetest.get_node_or_nil(pos_above_new_2)
        if node_under and node_under.name == 'air' then
            snake.in_air = snake.in_air + 1
        else
            snake.in_air = 0
        end

        if snake.in_air > 3 then
            -- snake die here [fall]
            snake:die()
            table.remove(stonesnake.snakes, id)
        elseif node_above_1 == nil or node_above_1.name ~= 'air' then
            -- snake die here [suff]
            snake:die()
            table.remove(stonesnake.snakes, id)
        elseif node_above_2  == nil or node_above_2.name ~= 'air' then
            -- snake die here [suff2]
            snake:die()
            table.remove(stonesnake.snakes, id)
        elseif node == nil or not(node.name == 'air' or node.name == 'default:stone')  then
            -- snake die here [crash]
            snake:die()
            table.remove(stonesnake.snakes, id)
        elseif node and node.name == 'default:stone' then
            -- snake eat here
            minetest.set_node(pos_new, {name="air"})
            snake.score = snake.score + 1
            -- snake move head
            snake:head_new()
            -- snake move anything what on its back
            snake:drag()
            -- snake move tail too long
            local length = 0
            local x1 = snake.head
            local x2 = snake.head
            while x1.tail do
                x2 = x1
                x1 = x1.tail
                length = length + 1
            end
            if length > stonesnake.max_length then
                -- Cut tail
                if length > 1 then
                    snake.old_tail = x1
                    x2.tail = nil
                end
            end
        else
            -- snake move head
            snake:head_new()
            -- snake move anything what on its back
            snake:drag()
            -- snake move tail when not eaten
            local length = 0
            local x1 = snake.head
            local x2 = snake.head
            while x1.tail do
                x2 = x1
                x1 = x1.tail
                length = length + 1
            end
            -- Cut tail
            if length > 1 then
                snake.old_tail = x1
                x2.tail = nil
            end
        end
    end

    -- Remove cobble at old tail
    for _,snake in pairs(stonesnake.snakes) do
        if snake.old_tail ~= nil then
            local node = minetest.get_node_or_nil(snake.old_tail.pos)
            if node and (node.name == 'default:cobble' or node.name == 'stonesnake:cobble') then
                minetest.set_node(snake.old_tail.pos, {name="air"})
            end
            snake.old_tail = nil
        end
    end

end

local snake = {
	physical = false,
	collisionbox = {-0.4,-0.5,-0.4, 0.4,0.5,0.4},
	visual = "mesh",
	mesh = "snake.b3d",
	visual_size = {x=1, y=1},
	textures = {"snake.png"},

    hp_max = 8000,
	owner = nil,
    driver = nil,

    -- Special snake object
	snake_object = nil,

    on_rightclick = function(self, clicker)
    	if not clicker or not clicker:is_player() then
    		return
    	end
    	local player_name = clicker:get_player_name()
    	if self.owner == nil or player_name == self.owner then
            if self.driver == nil and not default.player_attached[player_name] then
                clicker:set_attach(self.object, "", {x=0, y=6, z=0}, {x=0, y=0, z=0})
                clicker:set_eye_offset({x=0, y=-4, z=0},{x=0, y=-4, z=0})
                self.driver = player_name
                self.owner = player_name

                local pos = self.object:get_pos()
                local dir = clicker:get_look_dir()
                dir.y = 0
                dir = vector.round(vector.normalize(dir))
                self.snake_object = stonesnake.add_snake(pos, dir, player_name)
                self.snake_object.entity = self
                local rpos = vector.round(pos)
                minetest.log("action", "Player "..player_name.." started stonesnake game at "..rpos.x..","..rpos.y..","..rpos.z)
            else
                clicker:set_detach()
                clicker:set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
                self.driver = nil
                if self.snake_object then
                    self.snake_object:die()
                    self.snake_object = nil
                end
            end
    	end
    end,
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction)
    	if not puncher or not puncher:is_player() then
            -- Punched by non-player
        elseif puncher:get_player_control().sneak then
            -- Player digs snake by sneak-punch
            if self.owner == nil or puncher:get_player_name() == self.owner then
        		-- Detach driver and items
        		if self.driver then
                    puncher:set_detach()
                    puncher:set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
                    self.driver = nil
        		end
                if self.snake_object then
                    self.snake_object:die()
                    self.snake_object = nil
                end

                local inv = puncher:get_inventory()
        		if not (creative and creative.is_enabled_for
        				and creative.is_enabled_for(puncher:get_player_name()))
        				or not inv:contains_item("main", "stonesnake:snake") then
        			local leftover = inv:add_item("main", "stonesnake:snake")
        			-- If no room in inventory add a replacement snake to the world
        			if not leftover:is_empty() then
        				minetest.add_item(self.object:get_pos(), leftover)
        			end
        		end
        		self.object:remove()
            end
        end
    end,
    on_step = function(self, dtime)
        -- Get player controls
        if self.driver and self.snake_object then
            local player = minetest.get_player_by_name(self.driver)
            if player == nil then
                self.snake_object:die()
                return
            end
            self.snake_object.timer = self.snake_object.timer + dtime
            self.snake_object.command_timer = self.snake_object.command_timer + dtime
            if player and self.snake_object.timer > 0.07 then
                local ctrl = player:get_player_control()

                if self.snake_object.command_timer > 0.15 and ctrl and ctrl.right then
                    if self.snake_object.left then
                        self.snake_object.left = false
                        self.snake_object.right = false
                    else
                        self.snake_object.right = true
                        self.snake_object.command_timer = 0
                    end
                elseif self.snake_object.command_timer > 0.15 and ctrl and ctrl.left then
                    if self.snake_object.right then
                        self.snake_object.left = false
                        self.snake_object.right = false
                    else
                        self.snake_object.left = true
                        self.snake_object.command_timer = 0
                    end
                elseif ctrl and ctrl.up then
                    self.snake_object.left = false
                    self.snake_object.right = false
                end
                self.snake_object.timer = 0
            end
        else
            self:set_velocity(false)
        end
    end,
    set_move = function(self, pos)

        self.object:move_to(pos, true)
    end,
    set_yaw = function(self, v)
        if v.x == 0 and v.z == 0 then
            return  --keep old jaw
        end

        local yaw = vector_yaw(v)

        self.object:set_yaw(yaw)
    end,
    set_velocity = function(self, v)
        if not v then
            v = {x=0, y=0, z=0}
        end
        self.object:set_velocity(v)
    end,


    get_staticdata = function(self)
        local tmp = {
            owner = self.owner,
            hp = self.object:get_hp(),
        }
        return minetest.serialize(tmp)
    end,
    on_activate = function(self, staticdata, dtime_s)
        self:set_velocity(false)

        if staticdata then
            local olddata = minetest.deserialize(staticdata)
            if olddata then
                if olddata.owner then
                    self.owner = olddata.owner
                end
                if olddata.hp then
                    self.object:set_hp(olddata.hp)
                end
            end
            -- minetest.log("action", "Stonesnake game resumes")
        end
    end,
}

minetest.register_entity("stonesnake:snake", snake)

local golden_snake = table.copy(snake)
golden_snake.textures = {"golden_snake.png"}
minetest.register_entity("stonesnake:golden_snake", golden_snake)

minetest.register_craftitem("stonesnake:snake", {
	description = "Stonesnake game",
	inventory_image = minetest.inventorycube("default_cobble.png", "default_cobble.png", "stonesnake.png"),
	wield_image = "default_cobble.png",
    stack_max = 1,
    wield_scale = {x=2, y=2, z=2},

	on_place = function(itemstack, placer, pointed_thing)
		if not pointed_thing.type == "node" then
			return
		end
        if minetest.get_node(pointed_thing.above).name == "air" then
            local pos = pointed_thing.above
            local owner = placer:get_player_name()
            if owner == stonesnake.champion_active then
                local snake_entity = minetest.add_entity(pos, "stonesnake:golden_snake")
            else
    		    local snake_entity = minetest.add_entity(pos, "stonesnake:snake")
            end

            -- snake_entity:set_properties({owner=owner})

    		if not minetest.settings:get_bool("creative_mode") then
    			itemstack:take_item()
    		end
        end
		return itemstack
	end,
})

minetest.register_chatcommand("stonesnake", {
	params = "",
	description = "Stonesnake info",
	func = function(playername, text)
        if text == 'all' then
            --
        else
            minetest.chat_send_player(playername, 'Stonesnake leave in stone desert and eats stone. It is rare and wery strong.')
            minetest.chat_send_player(playername, 'If defeated, Stonesnake drop special item.')

            for id, item in pairs(stonesnake.champions_list) do
                local name = item[1] or ''
                local score = tonumber(item[2]) or 0
                if name == stonesnake.champion_active then
                    minetest.chat_send_player(playername, score.." ".."***"..name.."*** - current stonesnake champion")
                else
                    minetest.chat_send_player(playername, score.." "..name.."")
                end
            end
        end
	end,
})

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 0.2 then
		stonesnake.step()
		timer = 0
	end
end)


stonesnake.champions_list = {}  --{name, score}
stonesnake.champions_highscore_min = nil
stonesnake.champion_active = ''

-- Save and load champion list
stonesnake.filename = minetest.get_worldpath() .. "/stonesnake_champions_by_name.txt"

function stonesnake:save()
    local datastring = minetest.serialize(self.champions_list)
    if not datastring then
        return
    end
    local file, err = io.open(self.filename, "w")
    if err then
        return
    end
    file:write(datastring)
    file:close()
end

function stonesnake:load()
    local file, err = io.open(self.filename, "r")
    if err then
        self.champions_list = {}
        return
    end
    self.champions_list = minetest.deserialize(file:read("*all"))
    if type(self.champions_list) ~= "table" then
        self.champions_list = {}
    end
    file:close()

    local highscore_max = 0
    -- find smallest record
    -- find active champion
    for id, item in pairs(self.champions_list) do
        local name = item[1] or ''
        local score = tonumber(item[2]) or 0
        if self.champions_highscore_min == nil then
            self.champions_highscore_min = score
        end
        if score < self.champions_highscore_min then
            self.champions_highscore_min = score
        end
        if score > highscore_max then
            self.champion_active = name
            highscore_max = score
        end
    end
end
-- Update champion list
function stonesnake:update(new_name, new_score)
    if self.champions_highscore_min == nil or new_score > self.champions_highscore_min then
        table.insert(self.champions_list, {new_name, new_score})
    else
        return false
    end

    function compare(a,b)
        return a[2] > b[2]
    end
    table.sort(self.champions_list, compare)

    local items_to_take = 5
    if #self.champions_list < items_to_take then
        items_to_take = #self.champions_list
    end

    local new_champions_list = {}
    for id=1,items_to_take do
        table.insert(new_champions_list, self.champions_list[id])
    end

    self.champions_list = new_champions_list

    local highscore_max = 0
    -- find smallest record
    -- find active champion
    for id, item in pairs(self.champions_list) do
        local name = item[1] or ''
        local score = tonumber(item[2]) or 0
        if self.champions_highscore_min == nil then
            self.champions_highscore_min = score
        end
        if score < self.champions_highscore_min then
            self.champions_highscore_min = score
        end
        if score > highscore_max then
            self.champion_active = name
            highscore_max = score
        end
    end

    self:save()

    return true
end
-- Drop prize from stonesnake game
function stonesnake:prize_drop(pos)
    	local drops = {
            {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
            {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
            {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
            {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
            {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
            {name = "default:obsidian", chance = 3, min = 1,	max = 2,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:mese_crystal", chance = 2, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:gold_ingot", chance = 1, min = 1, max = 1,},
            {name = "default:diamond", chance = 3, min = 1, max = 1,},
            {name = "default:diamond", chance = 3, min = 1, max = 1,},
            {name = "default:diamond", chance = 3, min = 1, max = 1,},
            {name = "default:diamond", chance = 3, min = 1, max = 1,},
            {name = "default:diamond", chance = 3, min = 1, max = 1,},
        }

    	for n = 1, #drops do
    		if math.random(1, drops[n].chance) == 1 then
    			num = math.random(drops[n].min, drops[n].max)
    			item = drops[n].name

    			-- add item if it exists
    			obj = minetest.add_item(pos, ItemStack(item .. " " .. num))

    			if obj and obj:get_luaentity() then
    				obj:set_velocity({
    					x = math.random(-10, 10) / 10,
    					y = 12,
    					z = math.random(-10, 10) / 10,
    				})
    			elseif obj then
    				obj:remove() -- item does not exist
    			end
    		end
    	end

    	drops = {}
end

stonesnake:load()

-- Register golden stonesnake cobble
minetest.register_node("stonesnake:cobble", {
	description = "Stonesnake cobble",
	tiles = {"stonesnake_cobble.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {cracky = 1, level = 3, not_in_creative_inventory = 1},
})
