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
   limit = 1000,
   -- how many iterations before give up removing suspended   
   wait = 100,
   -- how many iterations before trampolining off a timer
   start = -1,
   -- how far up to go before searching around (0 = current level)
   delay = 1,
   -- how long to wait until felling more trees
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

local currently_digging = 0

local function maybe_count(count,finally,continue)
   if count.full > timber.limit then
	  finally(count)
	  return
   end
   count.full = count.full + 1
   if currently_digging > timber.wait then
	  print('derp',currently_digging)
	  core.after(timber.delay,function()
					print('derp resume')
					currently_digging = 0
					continue(count)
	  end)
   else
	  currently_digging = currently_digging + 1
	  continue(count)
   end
end


function timber.dig_around(center, node, count, finally, continue)
   maybe_count(count, finally,
	function(count)
	   local downright = {x=center.x-timber.search,
						 y=center.y-1,
						 z=center.z-timber.search}
	   -- NOT timber.search below center.y though.
	   local topleft = {x=center.x+timber.search,
						 y=center.y+timber.search,
						 z=center.z+timber.search}
	   local nps = core.find_nodes_in_area(downright, topleft, node.name)
	   local function one_iteration(i,count)
		  if i > #nps then
			 -- we dug all successfully, so can continue on
			 return continue(count)
		  end
		  local np = nps[i]
		  local function doit()
			 maybe_count(count, finally,
						 function(count)
							timber.dig_around(
							   np, node, count,
							   finally,
							   function(count)
								  one_iteration(i+1, count)
							end)
			 end)
		  end
		  if np == nil then
			 print("uhhhhh",i,#nps)
			 assert(false)
		  end
		  print("eh?",np,np==nil)
		  local below = minetest.get_node_or_nil({x=np.x,
												  y=np.y-1,
												  z=np.z})	  
		  if below == nil then
			 doit()
		  else
			 local ndef = minetest.registered_nodes[below.name]
			 if not ndef.walkable or ndef.groups.leaves or ndef.groups.leafdecay then
				doit()
			 end
		  end
	   end
	   local function breadth_first(i,count)
		  if i > #nps then
			 return one_iteration(1,count)
		  end
		  timber.just_dig_above(nps[i],
								node,
								count,
								finally,
						   function(count)
							  maybe_count(count, finally,
										  function(count)
											 breadth_first(i+1,count)
							  end)
						   end)
	   end
						 
	   breadth_first(1,count)
   end)
end

function timber.want_this(node)
   if timber.nodes[node.name] then return node end
   for group,_ in pairs(core.registered_nodes[node.name].groups) do
	  if timber.groups[group] then return node end
   end
   return nil
end


function timber.just_dig_above(pos, node, count, finally, continue)
   local height = nil
   -- check up first, so it doesn't get dug by air trees
   local function iterate(height,count)
	  if height == 100 then
		 return continue(height)
	  end
	  local np = {x=pos.x,y=pos.y+height,z=pos.z}
	  local test = core.get_node_or_nil(np)
	  if test == nil then return continue(height) end
	  if node.name ~= test.name then return continue(height) end
	  timber.dig_node(np,node)
	  maybe_count(count,finally,function(count)
					 iterate(height+1,count)
	  end)
   end
   maybe_count(count,finally,function(count)
				  iterate(0,count)
							 end)
   return height
end

function timber.dig_above(pos, node, finally)
   local count = counter()
   local function have_height(height)
	  local function iterate(i,count)
		 if i == height then
			finally(count)
			return
		 end
		 local np = {x=pos.x,y=pos.y+i,z=pos.z}
		 timber.dig_around(np, node, count,
						   finally,
						   function(count)
							  iterate(i+1,count)
		 end)
	  end

	  iterate(timber.start,count)
   end
   timber.just_dig_above(pos,node,count,finally,have_height)
end

minetest.register_on_dignode(function(pos,node)
	  if not timber.want_this(node) then return end
	  timber.dig_above(pos,node,function(count)
						  print("tree derped")
	  end)
end)
