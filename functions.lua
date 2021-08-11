
--vector to yaw
function vector_yaw(v)
    local yaw = math.pi
    if v.z < 0 then
        yaw = math.pi - math.atan(v.x/v.z)
    elseif v.z > 0 then
        yaw = -math.atan(v.x/v.z)
    elseif v.x > 0 then
        yaw = -math.pi/2
    elseif v.x < 0 then
        yaw = math.pi/2
    end
    return yaw
end

--yaw to vector
function yaw_vector(yaw)
    local v = {x=0, y=0, z=0}
    local tmp_yaw = yaw + math.pi/2
    v.x = math.cos(tmp_yaw)
    v.z = math.sin(tmp_yaw)
    v = vector.normalize(v)
    return v
end

--position, relative to
-- this function is available separatelly in coordinate_helper mod
if not _G['get_pos_relative'] then   --check global table if function already defined from coordinate_helper mod
    -- x-FRONT/BACK, z-LEFT/RIGHT, y-UP/DOWN
    function get_pos_relative(position, rel_pos, face_vector, down_vector)
        local pos = {x=position.x,y=position.y,z=position.z}

        if not face_vector then
            face_vector = {x=1, y=0, z=0}
            -- assert(vector.length(face_vector) == 1, "Incorrect face vector")
        end

        -- oh no! "wallmounted" and "facedir" cannot store down vector. i choose defaults.
        if not down_vector then
            down_vector = {x=0, y=0, z=0}
            if face_vector.y == 1 then
                down_vector.x = 1
            elseif face_vector.y == -1 then
                down_vector.x = -1
            else
                down_vector.y = -1
            end
        end

        assert(vector.length(down_vector) == 1, "Incorrect down vector")
        assert(vector.length(vector.multiply(face_vector, down_vector)) == 0, "Down vector(x"..down_vector.x..",y"..down_vector.y..",z"..down_vector.z..") incompatible with face vector(x"..face_vector.x..",y"..face_vector.y..",z"..face_vector.z..")")

        if rel_pos.x == 0 and rel_pos.y == 0 and rel_pos.z == 0 then
            return {x=pos.x, y=pos.y, z=pos.z}
        end

        local fdir = face_vector
        local ddir = down_vector

        if fdir.x == 1 then -- NORD
            pos.x = pos.x + rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.z = pos.z + rel_pos.z
            elseif ddir.x == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == 1 then
                pos.y = pos.y + rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.y = pos.y - rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.z = pos.z - rel_pos.z
            end
        elseif fdir.z == -1 then -- EAST
            pos.z = pos.z - rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.x = pos.x + rel_pos.z
            elseif ddir.x == 1 then
                pos.y = pos.y + rel_pos.z
                pos.x = pos.x - rel_pos.y
            elseif ddir.x == -1 then
                pos.y = pos.y - rel_pos.z
                pos.x = pos.x + rel_pos.y
            elseif ddir.z == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.x = pos.x - rel_pos.z
            end
        elseif fdir.x == -1 then -- SOUTH
            pos.x = pos.x - rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.z = pos.z - rel_pos.z
            elseif ddir.x == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == 1 then
                pos.y = pos.y - rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.y = pos.y + rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.z = pos.z + rel_pos.z
            end
        elseif fdir.z == 1 then -- WEST
            pos.z = pos.z + rel_pos.x
            if ddir.y == -1 then
                pos.y = pos.y + rel_pos.y
                pos.x = pos.x - rel_pos.z
            elseif ddir.x == 1 then
                pos.y = pos.y - rel_pos.z
                pos.x = pos.x - rel_pos.y
            elseif ddir.x == -1 then
                pos.y = pos.y + rel_pos.z
                pos.x = pos.x + rel_pos.y
            elseif ddir.z == 1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.z == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.y == 1 then
                pos.y = pos.y - rel_pos.y
                pos.x = pos.x + rel_pos.z
            end
        elseif fdir.y == 1 then -- UP
            pos.y = pos.y + rel_pos.x
            if ddir.y == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == 1 then
                pos.x = pos.x - rel_pos.y
                pos.z = pos.z + rel_pos.z
            elseif ddir.x == -1 then
                pos.x = pos.x + rel_pos.y
                pos.z = pos.z - rel_pos.z
            elseif ddir.z == 1 then
                pos.x = pos.x - rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.x = pos.x + rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                assert(false, "Impossible vector combination!")
            end
        elseif fdir.y == -1 then -- DOWN
            pos.y = pos.y - rel_pos.x
            if ddir.y == -1 then
                assert(false, "Impossible vector combination!")
            elseif ddir.x == 1 then
                pos.x = pos.x - rel_pos.y
                pos.z = pos.z - rel_pos.z
            elseif ddir.x == -1 then
                pos.x = pos.x + rel_pos.y
                pos.z = pos.z + rel_pos.z
            elseif ddir.z == 1 then
                pos.x = pos.x + rel_pos.z
                pos.z = pos.z - rel_pos.y
            elseif ddir.z == -1 then
                pos.x = pos.x - rel_pos.z
                pos.z = pos.z + rel_pos.y
            elseif ddir.y == 1 then
                assert(false, "Impossible vector combination!")
            end
        end
        return pos
    end
end

-- get node but use fallback for nil or unknown
-- local node_ok = function(pos)
function node_ok(pos)
    local node = minetest.get_node_or_nil(pos)

    if node and minetest.registered_nodes[node.name] then
        return node
    end

    return minetest.registered_nodes["air"] -- {name = fallback}
end

function is_walkable(pos)
    local node = minetest.get_node_or_nil(pos)
    if node and minetest.registered_nodes[node.name] then
        if minetest.registered_nodes[node.name].walkable == false then
            return false
        else
            return true
        end
    else
        return true     -- walk on undefined or unknow nodes but also see them as obstacle
    end
end

-- custom particle effects
-- local effect = function(pos, amount, texture, min_size, max_size, radius, gravity, glow)
function effect(pos, amount, texture, min_size, max_size, radius, gravity, glow)
	radius = radius or 2
	min_size = min_size or 0.5
	max_size = max_size or 1
	gravity = gravity or -10
	glow = glow or 0

	minetest.add_particlespawner({
		amount = amount,
		time = 0.25,
		minpos = pos,
		maxpos = pos,
		minvel = {x = -radius, y = -radius, z = -radius},
		maxvel = {x = radius, y = radius, z = radius},
		minacc = {x = 0, y = gravity, z = 0},
		maxacc = {x = 0, y = gravity, z = 0},
		minexptime = 0.1,
		maxexptime = 1,
		minsize = min_size,
		maxsize = max_size,
		texture = texture,
		glow = glow,
	})
end



function add_tool_wear(itemstack, pos)
    local tool_definition = itemstack:get_definition()
    local uses = 20
    if tool_definition and tool_definition.tool_capabilities then
        if tool_definition.tool_capabilities.groupcaps.climbing then
            uses = tool_definition.tool_capabilities.groupcaps.climbing.uses
        elseif tool_definition.tool_capabilities.groupcaps.snappy then
            uses = tool_definition.tool_capabilities.groupcaps.snappy.uses
        elseif tool_definition.tool_capabilities.groupcaps.cracky then
            uses = tool_definition.tool_capabilities.groupcaps.cracky.uses
        end
    end

    uses = uses * 4 -- because default uses are meant for block digging. it is not enough for fighting.

    -- wear tool
    itemstack:add_wear(math.floor(65535/(uses-1)))
    -- tool break sound
    if itemstack:get_count() == 0 and tool_definition.sound and tool_definition.sound.breaks then
        minetest.sound_play(tool_definition.sound.breaks, {pos = pos, gain = 0.5})
    end

    return itemstack

    -- simple tool wear
    -- if puncher and puncher:is_player() and puncher:get_wielded_item() then
    --     local itemstack = puncher:get_wielded_item()
    --     local pos = puncher:get_pos()
    --     itemstack = add_tool_wear(itemstack, pos)
    --     puncher:set_wielded_item(itemstack)
    -- end
end
