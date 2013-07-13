--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f = require( "Vector3f" )
local Triangle = require( "Triangle" )


local SpatialIndex = {};   SpatialIndex.__index = SpatialIndex




--- Minimal spatial index for ray tracing.
---
--- Suitable for a scale of 1 metre == 1 numerical unit, and has a resolution of
--- 1 millimetre. (Implementation uses fixed tolerances.)
---
--- Constant.
---
--- @fields
--- * writeable: none
--- * readable:  none
---
--- @implementation
--- A degenerate State pattern: typed by isBranch field to be either a branch
--- or leaf cell.
---
--- Octree: axis-aligned, cubical. Subcells are numbered thusly:
---            110---111
---            /|    /|
---         010---011 |
---    y z   | 100-|-101
---    |/    |/    | /
---    .-x  000---001
---
--- Each cell stores its bound: fatter data, but simpler code.
---
--- Calculations for building and tracing are absolute rather than incremental
--- -- so quite numerically solid. Uses tolerances in: bounding triangles (in
--- Triangle.getBound), and checking intersection is inside cell (both effective
--- for axis-aligned items). Also, depth is constrained to an absolute subcell
--- size (easy way to handle overlapping items).
---
--- @invariants
--- * isBranch is Boolean
--- * bound is Table array of 6 Numbers
--- * bound[1-3] <= bound[4-6]
--- * bound encompasses the cell's contents
--- * vector is Table array
--- if isBranch
--- * vector length is 8
--- * vector fields are SpatialIndex or false
--- else
--- * vector fields are Triangles




-- constants -------------------------------------------------------------------

-- accommodates scene including sun and earth, down to cm cells
-- (use 47 for mm)
local MAX_LEVELS = 44
local MAX_ITEMS  =  8




-- implementation --------------------------------------------------------------

--- Bit test.
---
--- @n Number integer to test (0-7)
--- @i Number integer index of bit (1-3)
---
--- @return -1 for set or +1 for unset.
---
local function sbit( n, i )
   local b = (i < 3) and (i * 2) or 8
   return (n % b) > ((b - 1) / 2) and -1 or 1
end




-- construction ----------------------------------------------------------------

--- @arg   Vector3f eyePosition or Table of 6 Number bound
--- @items Table of Triangle
--- @level Number or nil
---
function SpatialIndex.new( arg, items, level )

   level = level or 0

   -- set the overall bound, if root call of recursion
   local bound, itemsBounded
   if getmetatable(arg) == Vector3f then
      bound, itemsBounded = {}, {}

      -- pre-calculate all item bounds
      for k, v in pairs(items) do
         itemsBounded[k] = { bound = v:getBound(), item = v }
      end

      -- accommodate eye position (makes tracing algorithm simpler)
      for i = 1, 6 do bound[i] = arg[((i-1) % 3) + 1] end

      -- accommodate all items
      for _, item in pairs(itemsBounded) do
         for j, b in ipairs(bound) do
            if ((item.bound[j] - b) * (3.5 - j)) < 0 then
               bound[j] = item.bound[j] end
         end
      end

      -- make cubical
      local size = math.max( table.unpack( Vector3f.new( table.unpack(
         bound, 4, 6 ) ) - Vector3f.new( table.unpack( bound, 1, 3 ) ) ) )
      for i = 1, 3 do if bound[i + 3] < (bound[i] + size) then
         bound[i + 3] = bound[i] + size
      end end
   else
      bound, itemsBounded = arg, items
   end

   -- is branch if items overflow leaf and tree not too deep
   local isBranch = (#itemsBounded > MAX_ITEMS) and (level < (MAX_LEVELS - 1))

   -- be branch: make sub-cells, and recurse construction
   local vector = {}
   if isBranch then

      -- make subcells
      local q1 = 0
      for s = 0, 7 do

         -- make subcell bound
         local subBound = {}
         for j = 0, 5 do
            local m = (j % 3) + 1
            subBound[j + 1] = ((sbit(s, m) * (2.5 - j)) < 0) and
               (bound[m] + bound[m + 3]) * 0.5 or bound[j + 1]
         end

         -- collect items that overlap subcell
         local subItems = {}
         for _, item in pairs(itemsBounded) do
            local b = item.bound

            -- must overlap in all dimensions
            if (b[4] >= subBound[1]) and (b[1] < subBound[4]) and
               (b[5] >= subBound[2]) and (b[2] < subBound[5]) and
               (b[6] >= subBound[3]) and (b[3] < subBound[6]) then
               table.insert( subItems, item )
            end
         end

         -- curtail degenerate subdivision by adjusting next level
         -- (degenerate if two or more subcells copy entire contents of parent,
         -- or if subdivision reaches below mm size)
         -- (having a model including the sun requires one subcell copying
         -- entire contents of parent to be allowed)
         if #subItems == #itemsBounded then q1 = q1 + 1 end
         local q2 = (subBound[4] - subBound[1]) < (Triangle.TOLERANCE * 4.0)

         -- recurse
         vector[s+1] = (#subItems > 0) and SpatialIndex.new( subBound, subItems,
            (((q1 > 1) or q2) and MAX_LEVELS or level + 1) ) or false

      end

   -- be leaf: store items, and end recursion
   else
      for i, item in ipairs(itemsBounded) do vector[i] = item.item end
   end

   local instance = { isBranch = isBranch, bound = bound, vector = vector }

   return setmetatable( instance, SpatialIndex )

end




-- queries ---------------------------------------------------------------------

--- Find nearest intersection of ray with item.
---
--- @rayOrigin    Vector3f
--- @rayDirection Vector3f
--- @lastHit      Triangle previous intersected item
--- @start        Vector3f traversal position
---
--- @return Triangle item intersected or nil, Vector3f position or nil
---
function SpatialIndex:getIntersection( rayOrigin, rayDirection, lastHit, start )

   local hitObject, hitPosition

   -- is branch: step through subcells and recurse
   if self.isBranch then

      start = start or rayOrigin

      -- find which subcell holds ray origin (ray origin is inside cell)
      local subCell = 0
      for i = 1, 3 do
         -- compare dimension with center
         subCell = subCell + ( (start[i] >= ((self.bound[i] + self.bound[i+3]) *
            0.5)) and (2 ^ (i - 1)) or 0 )
      end

      -- step through intersected subcells (in ray intersection order)
      local cellPosition = start
      while true do

         if self.vector[subCell + 1] then
            -- intersect subcell
            hitObject, hitPosition = self.vector[subCell + 1]:getIntersection(
               rayOrigin, rayDirection, lastHit, cellPosition )
            -- exit if item hit
            if hitObject then break end
         end

         -- find next subcell ray moves to
         -- (by finding which face of the corner ahead is crossed first)
         local step, axis = math.huge, 1
         for i = 1, 3 do
            local high = sbit( subCell, i )
            local face = ((rayDirection[i] * -high) < 0) and (self.bound[i] +
               self.bound[i + 3]) * 0.5 or self.bound[i + ((1 - high) * 1.5)]
            local distance = (face - rayOrigin[i]) / rayDirection[i]

            if distance <= step then step, axis = distance, i end
         end

         local subCellAxisSign = sbit( subCell, axis )

         -- leaving branch if: subcell is low and direction is negative,
         -- or subcell is high and direction is positive
         if (subCellAxisSign * rayDirection[axis]) < 0 then break end

         -- move to (outer face of) next subcell (flip one subcell bit)
         cellPosition = rayOrigin + (rayDirection * step)
         subCell = subCell + (subCellAxisSign * (2 ^ (axis - 1)))

      end

   -- is leaf: exhaustively intersect contained items
   else

      local nearestDistance = math.huge

      -- step through items
      for _, item in pairs(self.vector) do
         -- avoid false intersection with surface just come from
         if item ~= lastHit then

            -- intersect ray with item, and inspect if nearest so far
            local distance = item:getIntersection( rayOrigin, rayDirection )
            if distance and (distance < nearestDistance) then

               -- check intersection is inside cell bound (with tolerance)
               local hit = rayOrigin + (rayDirection * distance)
               if (self.bound[1] - hit[1] <= Triangle.TOLERANCE) and
                  (hit[1] - self.bound[4] <= Triangle.TOLERANCE) and
                  (self.bound[2] - hit[2] <= Triangle.TOLERANCE) and
                  (hit[2] - self.bound[5] <= Triangle.TOLERANCE) and
                  (self.bound[3] - hit[3] <= Triangle.TOLERANCE) and
                  (hit[3] - self.bound[6] <= Triangle.TOLERANCE) then

                  hitObject, hitPosition = item, hit
                  nearestDistance = distance
               end

            end

         end
      end

   end

   return hitObject, hitPosition

end




return SpatialIndex
