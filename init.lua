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
   search = 6,
   -- how far to look for suspended trunks
   limit = 100,
   -- how many iterations before give up removing suspended   
   wait = 10,
   -- how many iterations before trampolining off a timer
   start = 3
   -- how far up to go before searching around
}

timber.nodes = set {"default:papyrus", "default:cactus"}
timber.groups = {
   tree=true
}

function timber.dig_node(np,node) 
   core.remove_node(np)
   for _, item in ipairs(minetest.get_node_drops(node.name)) do
	  local tp = {x = np.x + math.random()/2 - 0.25, y = np.y, z = np.z + math.random()/2 - 0.25}
	  core.add_item(tp, item)
   end
end

local function counter()
   return {
	  full = 0,
	  current = 0
   }
end

local function maybe_count(count,finally,continue)
   if count.full > timber.limit then
	  finally(count)
	  return
   end
   count.full = count.full + 1
   if count.current > timber.wait_threshold then
	  core.after(timber.delay,function()
					count.current = 0
					continue(count)
	  end)
   else
	  count.current = count.current + 1
	  continue(count)
   end
end


function timber.dig_around(center, node, count, finally)
   maybe_count(count, finally,
	function(count)
	   local downright = {x=center.x-timber.search,
						 y=center.y,
						 z=center.z-timber.search}
	   -- NOT below center.y though.
	   local topleft = {x=center.x+timber.search,
						 y=center.y+timber.search,
						 z=center.z+timber.search}
	   local nps = core.find_nodes_in_area(downright, topleft, node.name)
	   local function one_iteration(i,count)
		  if i > #nps then
			 -- a second finally?
			 -- "finished"?
			 -- when count hasn't overflown, but no more nearby nodes,
			 -- so can go to the next guy?
			 return finally(count)
		  end
		  local np = nps[i]
		  local below = minetest.get_node_or_nil({x=np.x,
												  y=np.y-1,
												  z=np.z})	  
		  if below ~= nil then
			 local ndef = minetest.registered_nodes[below.name]
			 if not ndef.walkable or ndef.groups.leaves then
				timber.dig_node(np,node)
				maybe_count(count+1, finally,
				 function(count)
					timber.dig_around(np, node, count,
					 function(count)
						one_iteration(i+1, count)
					 end)
				 end)
			 end
		  end
	   end
   end)
end

function timber.want_this(node)
   if timber.nodes[node.name] then return node end
   for group,_ in pairs(core.registered_nodes[node.name].groups) do
	  if timber.groups[group] then return node end
   end
   return nil
end


function timber.dig_above(pos, node, count, finally)
   count = count or counter()
   local height = nil
   -- check up first, so it doesn't get dug by air trees
   for derp = 1,100 do
	  height = derp
	  local np = {x=pos.x,y=pos.y+height,z=pos.z}
	  local test = core.get_node_or_nil(np)
	  if test == nil then break end
	  if node.name ~= test.name then break end
	  timber.dig_node(np,node)
   end
   print('above',height)
   function iterate(i,count)
	  if i == height then
		 finally(count)
		 return
	  end

	  local np = {x=pos.x,y=pos.y+i,z=pos.z}
	  timber.dig_around(np, node, count,
						function(count)
						   iterate(i+1,count)
						end)
   end
end

minetest.register_on_dignode(function(pos,node)
	  if not timber.want_this(node) then return end
	  timber.dig_above(pos,node,function(count)
						  print("tree derped")
	  end)
end)
