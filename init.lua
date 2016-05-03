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

-- this mod is based on http://minetest.net/forum/viewtopic.php?id=1590
local timber = {}
timber.nodenames={"default:papyrus", "default:cactus", "group:tree"}
timber.search = 3 -- how far to look for suspended trunks
timber.limit = 100 -- how many iterations before give up removing suspended

function dig_node(np) 
   minetest.env:remove_node(np)
   for _, item in ipairs(minetest.get_node_drops(name)) do
	  local tp = {x = np.x + math.random()/2 - 0.25, y = np.y, z = np.z + math.random()/2 - 0.25}
	  minetest.env:add_item(tp, item)
   end
end

function dig_air_trees(center, node, count)
   dig_node(np)
   count = count + 1
   while count < timber.limit do
	  local np = minetest.env:find_node_near(center, timber.search, node)
	  if np == nil then
		 break
	  end
	  local below = minetest.get_node_or_nil({np.X,np.Y-1,np.Z})
	  if below ~= nil and
	  not minetest.registered_nodes[below.name].walkable then
		 count += dig_air_trees(np, node, count+1)
	  end
   end
   return count
end

function dig_up(pos, nodes)
   local height = nil
   -- check up first, so it doesn't get dug by air trees
   for height = 1,100 do
	  local np = {pos.x,pos.y+height,pos.z}
	  if nil == minetest.env:find_node_near(np,1,nodes) then
		 break
	  end
	  dig_node(np)
   end
   for i = 1,height do
	  local np = {pos.x,pos.y+height,pos.z}
	  dig_air_trees(np, nodes, 0)
   end
end

minetest.register_on_dignode(function(pos, node)
	  dig_up(pos,timber.nodenames)
end)

