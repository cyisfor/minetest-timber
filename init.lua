--[[
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- this mod is vaguely inspired by http://minetest.net/forum/viewtopic.php?id=1590
local timber = {
   search = 4,
   -- how far to search for suspended trunks
   limit = 10000,
   -- hard limit to how many blocks to remove in one chop before giving up
   wait = 50,
   -- how many blocks to chop before waiting
   delay = 1,
   -- how long to wait until felling more trees
   start = -1,
   -- how far up to go before searching around (0 = current level)
   max_height = 50,
   -- how far up to follow the trunk before giving up
   -- (giant sequoia never gets above 50 blocks high)
	 max_recursion = 4,
	 -- don't wander more than this many hops away from the main trunk
}

function set(list)
   local s = {}
   for _,l in ipairs(list) do s[l] = true end
   return s
end

timber.nodes = set {"default:papyrus", "default:cactus"}
timber.groups = {
   tree=true
}

local function counter(wear, cost, digger)
	 local left = 65536 - wear
	 local full = 0
	 local current = 0
	 local currently_digging = 0
	 local level = 0

   return {
			next = function()
				 if cost == nil then
						local item = digger:get_wielded_item()
						if item:get_definition() then
							 error("after_drop destroyed the wielded item")
						end
				 else
						left = left - cost
						if left <= 0 then
							 print('BOING')
							 error("tool ran out")
						end
				 end
				 full = full + 1
				 if full > timber.limit then
						print('DOING')
						error("hard limit to trunk digging")
				 end

				 if currently_digging > timber.wait then
						if not coroutine.yield() then
							 -- or lua will sit on a dead coroutine forever
							 error("bailing out")
						end
						currently_digging = 0
				 else
						currently_digging = currently_digging + 1
				 end
			end,
			broaden = function()
				 level = level + 1
				 print("going to level",level,timber.max_recursion)
				 return level < timber.max_recursion
			end,
			narrow = function()
				 level = level - 1
			end
	 }
end

-- see dig_around.svg
function timber.dig_around(center, node, digger, count)
	 local downright = {x=center.x-timber.search,
											y=center.y,
											z=center.z-timber.search}
	 -- do NOT search below center.y though.
	 local topleft = {x=center.x+timber.search,
										y=center.y+timber.search,
										z=center.z+timber.search}
	 local nps = core.find_nodes_in_area(downright, topleft, node.name)
	 print("found",#nps,"nearby")
	 -- get distant stuff first...
	 table.sort(nps,function(a,b)
								 return vector.distance(a,center) < vector.distance(b,center)
	 end)
	 print('uhhh',#nps)
	 print(nps[1],nps[2],nps[3])
	 -- this algorithm is more like shaving than cutting down :/
	 -- might leave dangling trunks if your axe breaks, but oh well

	 for _,subpos in ipairs(nps) do
			-- delete subnodes, because we already deleted the parentmost node
			local below = core.get_node_or_nil({x=center.x,
																					y=center.y-1,
																					z=center.z})
			print('below',below == nil)
			if below ~= nil then
				 if below.name == 'air' then
						print('air')
						count.next()
						core.node_dig(subpos,node,digger)
				 else
						print('nair')
						below.def = core.registered_nodes[below.name]
						-- if they're not sitting on something solid/notleafy.
						if ((not below.def.walkable)
									or below.def.airlike
									or below.def.groups.leaves
							 or below.def.groups.leafdecay) then
							 count.next()
							 core.node_dig(subpos,node,digger)
						end
				 end
			end
	 end
	 -- don't dig around, until we've got this batch done
	 for _,subpos in ipairs(nps) do
			-- don't go too deep into recursion
			-- return false if we hit recursion limit, nothing to do
			-- with whether our trunk was dug or not.
			-- remember dig_around will NEVER hop to trunks lower than us
			-- only basic_dig_above will iterate down to the trunk bottom
			if count.broaden() then
				 basic_dig_above(subpos, node, digger, count)
			end
			count.narrow()
	 end
end

function timber.want_this(node)
	 local ndef = core.registered_nodes[node.name]
	 if not ndef then
			return nil
	 end
	 if timber.nodes[node.name] then return ndef end
	 for group,_ in pairs(ndef.groups) do
			if timber.groups[group] then return ndef end
	 end
end

function basic_dig_above(pos, node, digger, count)
	 -- check up first, to find where to start above
	 local height
   for i = 1,timber.max_height do
			height = i
			local np = {x=pos.x,y=pos.y+i,z=pos.z}
			local test = core.get_node_or_nil(np)
			if test == nil or node.name ~= test.name then
				 -- past the top of `node.name` trunks
				 break
			end
   end

	 print("found height",height)

	 -- now dig straight above as a priority, then check around where you dug
	 -- always (really) dig downward
	 local np = {x=pos.x,y=pos.y+height,z=pos.z}

	 for i = height,0,-1 do
			count.next()
			core.node_dig(np, node, digger) -- builtin/game/item.lua
			np.y = np.y - 1
   end
	 np.y = np.y + height

	 -- now go down, digging around
	 for i = height,timber.start,-1 do
			timber.dig_around(np, node, digger, count)
			np.y = np.y - 1
	 end
end

function timber.dig_above(pos, node, digger, axe)
	 local wear = nil
	 local wdef = axe:get_definition()
	 -- make sure it's not a special tool that doesn't have simple wear
	 -- we have to check EVERY TIME if it is :p
	 if not wdef or not wdef.after_use then
			local tp = axe:get_tool_capabilities()
			local dp = core.get_dig_params(node.def.groups, tp)
			wear = dp.wear
			assert(wear ~= nil)
	 end
	 
	 return basic_dig_above(pos,node,digger,counter(axe:get_wear(), wear, digger))
end


local maincoro = coroutine.running()
core.register_on_dignode(function(pos, node, digger)
			-- core.node_dig then calls the core.register_on_dignode functions...
			if coroutine.running() ~= maincoro then return end
			print('in the main coro!')
			local ndef = timber.want_this(node)
			if not ndef then return end
			node.def = ndef -- HAX

			-- remember this, so we can check if it's legit after yielding
			local axe = digger:get_wielded_item()
			
			if axe == nil then return end
			local axe_name = axe:get_name()
			if not (
				 string.match(axe_name,"[^%a]axe[^%a]") or
						string.match(axe_name,"[^%a]axe$") or
						string.match(axe_name,"^axe[^%a]")
			) then return end
			-- be sure not to match pickaxe, just in case
			-- though the pickaxe names only use "pick"

			local oldpos = digger:getpos()

			local coro = coroutine.create(function()
						timber.dig_above(pos,node,digger,axe)
						print("timber!")
			end)
			local function resume()
				 local test = digger:get_wielded_item()
				 if (
						-- if the axe broke, or we dropped it, or w/ev
						((not test) or axe_name ~= test:get_name())
						-- if we died
						or (digger:get_hp() == 0)
						-- disconnected
						or (digger:is_player() and not digger:is_player_connected())
						-- we walked away
						or (vector.distance(digger:getpos(),oldpos) > 10)
						) then
						coroutine.resume(coro,false) -- bail out
						return
				 end

				 local ok, delay = coroutine.resume(coro,true)
				 if ok then
						if delay == nil then delay = 3 end
						core.after(delay, resume)
				 else
						if delay == "cannot resume dead coroutine" then
							 -- ok
						else
							 print("error",delay)
						end
				 end
			end
			resume()
end)
