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
timber.nodes = set {"default:papyrus", "default:cactus"}
timber.groups = {"tree"}
timber.search = 3 -- how far to look for suspended trunks
timber.limit = 100 -- how many iterations before give up removing suspended

function timber.dig_node(np,node) 
   core.remove_node(np)
   for _, item in ipairs(minetest.get_node_drops(node.name)) do
	  local tp = {x = np.x + math.random()/2 - 0.25, y = np.y, z = np.z + math.random()/2 - 0.25}
	  core.add_item(tp, item)
   end
end

function timber.dig_around(center, node, count)
   count = count + 1
   while count < timber.limit do
	  local np = core.find_node_near(center, timber.search, node.name)
	  if np == nil then 
		 break
	  end
	  if np.y >= node.y then
		 local below = minetest.get_node_or_nil({np.X,np.Y-1,np.Z})
		 if below ~= nil and
		 not minetest.registered_nodes[below.name].walkable then
			count = count + dig_around(np, node, count+1)
		 end
	  end
   end
   return count
end

function timber.want_this(node)
   if timber.nodes[node.name] then return node end
   print("ummm",core.registered_nodes[node.name].groups)

   for group,_ in pairs(core.registered_nodes[node.name].groups) do
	  print("group",group)
	  if timber.groups[group] then return node end
   end
   return nil
end


function timber.dig_above(pos, node, count)
   count = count or 0
   local height = nil
   -- check up first, so it doesn't get dug by air trees
   for derp = 1,100 do
	  height = derp
	  local np = {x=pos.x,y=pos.y+height,z=pos.z}
	  local test = core.get_node_or_nil(np)
	  if test == nil then break end
	  if node.name ~= test.name then break end
	  timber.dig_node(np,node,height+count)
   end
   print('above',height)
   for i = 1,height do
	  local np = {x=pos.x,y=pos.y+height,z=pos.z}
	  timber.dig_around(np, node, 0)
   end
end

minetest.register_on_dignode(function(pos,node)
	  if not timber.want_this(node) then return end
	  timber.dig_above(pos,node,0)
end)
