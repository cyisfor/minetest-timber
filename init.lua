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

function set(list)
   local s = {}
   for _,l in ipairs(list) do s[l] = true end
   return s
end

-- this mod is based on http://minetest.net/forum/viewtopic.php?id=1590
local timber = {
   search = 4,
   -- how far to search for suspended trunks
   limit = 10000,
   -- hard limit to how many blocks to remove in one chop before giving up
   wait = 100,
   -- how many blocks to chop before waiting
   start = -1,
   -- how far up to go before searching around (0 = current level)
   delay = 1,
   -- how long to wait until felling more trees
   max_height = 50,
   -- how far up to follow the trunk before giving up
   -- (giant sequoia never gets above 50 blocks high)
}

timber.nodes = set {"default:papyrus", "default:cactus"}
timber.groups = {
   tree=true
}

function timber.dig_node(np,node, drop)
   core.remove_node(np)
   for _, item in ipairs(minetest.get_node_drops(node.name)) do
	  core.add_item(drop, item)
   end
end

local function counter(durability)
   return {
	  left = durability,
	  full = 0,
	  current = 0
   }
end

local currently_digging = 0

local function maybe_count(count,finally,on_wait,continue)
	 if count.left <= 0 then
			return finally()
	 end
	 count.left = count.left - 1
   if count.full > timber.limit then
	  return finally()
   end
   count.full = count.full + 1
   if currently_digging > timber.wait then
	  print('derp',currently_digging)
		on_wait()
	  core.after(timber.delay,function()
					print('derp resume')
					currently_digging = 0
					continue()
	  end)
   else
	  currently_digging = currently_digging + 1
	  continue()
   end
end


function timber.dig_around(center, node, drop, count, finally, on_wait, continue)
   maybe_count(count, finally, on_wait,
	function()
	   local downright = {x=center.x-timber.search,
						 y=center.y,
						 z=center.z-timber.search}
	   -- NOT timber.search below center.y though.
	   local topleft = {x=center.x+timber.search,
						 y=center.y+timber.search,
						 z=center.z+timber.search}
	   local nps = core.find_nodes_in_area(downright, topleft, node.name)
	   -- get tall stuff first... more like shaving than cutting down :/
	   table.sort(nps,function(a,b) return a.y > b.y end)
	   local function one_iteration(i)
		  if i > #nps then
			 -- we dug all successfully, so can continue on
			 return continue()
		  end
		  local np = nps[i]
		  local function doit()
			 maybe_count(count, finally, on_wait, 
						 function()
							timber.dig_around(
							   np, node, drop, count,
							   finally,
								 on_wait,
							   function()
								  one_iteration(i+1)
							end)
			 end)
		  end
		  if np == nil then
			 print("uhhhhh",i,#nps)
			 assert(false)
		  end
		  local below = minetest.get_node_or_nil({x=np.x,
												  y=np.y-1,
												  z=np.z})
		  print("eh?",below,below==nil or below.name)
		  if below == nil then
			 doit()
		  else
			 local ndef = minetest.registered_nodes[below.name]
			 if not ndef.walkable or ndef.groups.leaves or ndef.groups.leafdecay then
				doit()
			 end
		  end
	   end
	   local function breadth_first(i)
		  if i > #nps then
			 return one_iteration(1)
		  end
		  timber.just_dig_above(nps[i],
								node,
								drop,
								count,
								finally,
								on_wait,
						   function()
							  maybe_count(count, finally, on_wait, 
										  function()
											 breadth_first(i+1,count)
							  end)
						   end)
	   end

	   breadth_first(1)
   end)
end

function timber.want_this(node)
   if timber.nodes[node.name] then return node end
	 if not core.registered_nodes[node.name] then
			return nil
	 end
	 for group,_ in pairs(core.registered_nodes[node.name].groups) do
			if timber.groups[group] then return node end
	 end
   return nil
end


function timber.just_dig_above(pos, node, drop, count, finally, on_wait, continue)
   local height = nil
   local function have_height(height)
	  -- be sure to dig down, avoid floating trees
	  local function iterate(i)
		 if i < 0 then
			return continue(height)
		 end
		 maybe_count(count,finally,on_wait, function()
						local np = {x=pos.x,y=pos.y+i,z=pos.z}
						timber.dig_node(np,node,drop)
						iterate(i-1)
		 end)
	  end
	  return iterate(height)
   end
   -- check up first, to find what to dig
   for height = 1,timber.max_height do
	  local np = {x=pos.x,y=pos.y+height,z=pos.z}
	  local test = core.get_node_or_nil(np)
	  if test == nil then return have_height(height-1) end
	  if node.name ~= test.name then
		 return have_height(height-1)
	  end
   end
   -- even giant sequoias only get up to ~40
   return have_height(timber.max_height)
end

function timber.dig_above(pos, node, digger, finally)
	 local axe = digger:get_wielded_item()
	 if axe == nil then return end
	 local n = axe:get_name()
	 if not (
			string.match(n,"[^%a]axe[^%a]") or
			string.match(n,"[^%a]axe$") or
			string.match(n,"^axe[^%a]")
	 ) then return end
	 -- though the names only use pick,
	 -- be sure not to match pickaxe, just in case
	 
   local count = counter(axe:get_wear())
	 print("axe starts with",count)
	 local function update_wear()
			print("axe now has",count.left)
			axe:set_wear(count.left)
			return finally()
	 end
   local function have_height(height)
	  -- be sure to dig down, avoid floating trees
	  local function iterate(i)
		 local np = {x=pos.x,y=pos.y+i,z=pos.z}
		 timber.dig_around(np, node, pos, count,
							 update_wear,
							 function()
									print("waiting, so axe now has",count.left)
									axe:set_wear(count.left)
							 end,
						   function()
							  if i <= timber.start then
								 return update_wear()
							  end
							  return iterate(i-1)
		 end)		 
	  end

	  return iterate(height)
   end
   timber.just_dig_above(pos,node,pos,count,finally,on_wait, have_height)
end

minetest.register_on_dignode(function(pos, node, digger)
	  if not timber.want_this(node) then return end
	  timber.dig_above(pos,node,digger,function()
						  print("timber!")
	  end)
end)
