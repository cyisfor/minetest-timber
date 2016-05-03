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
local timber = {}
timber.nodenames=set {"default:papyrus", "default:cactus", "group:tree"}
timber.search = 3 -- how far to look for suspended trunks
timber.limit = 100 -- how many iterations before give up removing suspended

function timber.dig_node(np,node) 
   core:remove_node(np)
   for _, item in ipairs(minetest.get_node_drops(node.name)) do
	  local tp = {x = np.x + math.random()/2 - 0.25, y = np.y, z = np.z + math.random()/2 - 0.25}
	  core:add_item(tp, item)
   end
end

function timber.dig_air_trees(center, node, count)
   timber.dig_node(center,node)
   count = count + 1
   while count < timber.limit do
	  local np = core:find_node_near(timber.search, center, node.name)
	  if np == nil then
		 break
	  end
	  local below = minetest.get_node_or_nil({np.X,np.Y-1,np.Z})
	  if below ~= nil and
	  not minetest.registered_nodes[below.name].walkable then
		 count = count + dig_air_trees(np, node, count+1)
	  end
   end
   return count
end

function timber.same_node(np,nodes)
   local node = core:get_node_or_nil(np)
   if node == nil then return nil end
   if nodes[node.name] then return node end
   for _,group in ipairs(minetest.registered_nodes[node.name].groups) do
	  print("group",group)
	  if nodes[group] then return node end
   end
   return nil
end


function timber.dig_up(pos, node)
   assert pos.X
   local height = nil
   -- check up first, so it doesn't get dug by air trees
   for derp = 1,100 do
	  height = derp
	  local np = {pos.x,pos.y+height,pos.z}
	  timber.dig_node(np,node)
   end
   for i = 1,height do
	  local np = {pos.x,pos.y+height,pos.z}
	  timber.dig_air_trees(np, node, 0)
   end
end

minetest.register_on_dignode(timber.dig_up)
