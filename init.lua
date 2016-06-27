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
   wait = 10,
   -- how many blocks to chop before waiting
   start = -1,
   -- how far up to go before searching around (0 = current level)
   delay = 1,
   -- how long to wait until felling more trees
   max_height = 50,
   -- how far up to follow the trunk before giving up
   -- (giant sequoia never gets above 50 blocks high)
	 max_recursion = 2,
	 -- don't wander more than 2 hops away from the main trunk
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

local function augment(handlers,updated)
	 local res = {}
	 for n,v in pairs(handlers) do
			if updated[n] then
				 v = updated[n]
			end
			res[n] = v
	 end
	 return res
end

local function continue(handlers,f)
	 return augment(handlers,{continue=f})
end
local function finally(handlers,f)
	 return augment(handlers,{finally=f})
end
local function counter(wear)
	 local left = 65536 - wear
	 local full = 0
	 local current = 0
	 local currently_digging = 0
	 local level = 0

   return {
			next = function()
				 left = left - 1
				 if left <= 0 then
						error("tool ran out")
				 end
				 full = full + 1
				 if full > timber.limit then
						error("hard limit to trunk digging")
				 end

				 if currently_digging > timber.wait then
						coroutine.yield()
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
	 -- don't go too deep into recursion
	 -- return false if we hit recursion limit, nothing to do
	 -- with whether our trunk was dug or not.
	 -- remember dig_around will NEVER hop to trunks lower than us
	 -- only basic_dig_above will iterate down to the trunk bottom
	 if not count.broaden() then
			count.narrow()
			return false
	 end

	 local downright = {x=center.x-timber.search,
											y=center.y,
											z=center.z-timber.search}
	 -- NOT timber.search below center.y though.
	 local topleft = {x=center.x+timber.search,
										y=center.y+timber.search,
										z=center.z+timber.search}
	 local nps = core.find_nodes_in_area(downright, topleft, node.name)
	 -- get tall stuff first...
	 table.sort(nps,function(a,b) return a.y > b.y end)
	 -- this algorithm is more like shaving than cutting down :/
	 -- might leave dangling trunks if your axe breaks, but oh well

	 for _,subpos in ipairs(nps) do
			-- delete subnodes, because we already deleted the parentmost node
			local below = core.get_node_or_nil({x=center.x,
																					y=center.y-1,
																					z=center.z})
			if below ~= nil then
				 local ndef = core.registered_nodes[below.name]
				 -- if they're not sitting on something solid/notleafy.
				 if (not ndef.walkable
								or ndef.groups.leaves
						 or ndef.groups.leafdecay) then
						count.next()
						core.node_dig(subpos,node,digger)
				 end
			end

			if not timber.dig_around(subpos, node, digger, count) then
				 count.narrow()
				 return false
			end

	 end

	 count.narrow()
	 return true
end

function timber.want_this(node)
   if timber.nodes[node.name] then return true end
	 if not core.registered_nodes[node.name] then
			return false
	 end
	 for group,_ in pairs(core.registered_nodes[node.name].groups) do
			if timber.groups[group] then return true end
	 end
   return nil
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

function timber.dig_above(pos, node, digger)
	 local axe = digger:get_wielded_item()
	 if axe == nil then return end
	 local n = axe:get_name()
	 if not (
			string.match(n,"[^%a]axe[^%a]") or
			string.match(n,"[^%a]axe$") or
			string.match(n,"^axe[^%a]")
	 ) then return end
	 -- be sure not to match pickaxe, just in case
	 -- though the pickaxe names only use "pick"

	 return basic_dig_above(pos,node,digger,counter(axe:get_wear()))
end

-- keep this non-reentrant stuff from getting reentered
local already_doing = false

core.register_on_dignode(function(pos, node, digger)
			if already_doing then return end
			already_doing = true
			-- core.node_dig then calls the core.register_on_dignode functions...
	  if not timber.want_this(node) then return end
	  local coro = coroutine.create(function()
					timber.dig_above(pos,node,digger)
					print("timber!")
		end)
		local function resume()
			 local ok, delay = coroutine.resume(coro)
			 if ok then
					if delay == nil then delay = 3 end
					core.after(delay, resume)
			 else
					already_doing = false;
					if delay == "cannot resume dead coroutine" then
						 -- ok
					else
						 print("error",delay)
					end
			 end
		end
		resume()
end)
