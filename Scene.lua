--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f     = require( "Vector3f" )
local Triangle     = require( "Triangle" )
local SpatialIndex = require( "SpatialIndex" )


local Scene = {};   Scene.__index = Scene




--- Grouping of the objects in the environment.
---
--- Makes a sub-grouping of emitting objects.
---
--- Constant.
---
--- @fields
--- * writeable: none
--- * readable:  none
---
--- @invariants
--- * triangles is Table, length <= MAX_TRIANGLES
--- * emitters  is Table, length <= MAX_TRIANGLES
--- * index     is SpatialIndex
--- * skyEmission      is Vector3f >= 0
--- * groundReflection is Vector3f >= 0




-- constants -------------------------------------------------------------------

-- 2^24 ~= 16 million
-- (must be power of two)
local MAX_TRIANGLES = 0x1000000




-- construction ----------------------------------------------------------------

--- @errors raises error if input file is invalid
---
--- @input       File to read from
--- @eyePosition Vector3f
---
function Scene.new( input, eyePosition )

   -- read sky and ground values (after skipping blank lines)
   local line;   repeat line = input:read("*l") until string.find(line, "%S")
   local s, g = string.match( line, "(%(.+%))%s*(%(.+%))" )
   --if not (s and g) then error( "invalid background", 0 ) end

   -- condition sky and ground values
   local skyEmission = Vector3f.new(s):clamped( Vector3f.ZERO, Vector3f.MAX )
   local groundReflection = skyEmission * Vector3f.new( g ):clamped(
      Vector3f.ZERO, Vector3f.ONE )

   -- read triangles
   local triangles = {}
   for i = 1, MAX_TRIANGLES do

      -- read next non-blank line, or break at eof
      repeat line = input:read("*l") until (not line) or string.find(line, "%S")
      if not line then break end

      table.insert( triangles, Triangle.new( line ) )
   end

   -- find emitting triangles
   local emitters = {}
   for _, t in ipairs( triangles ) do

      -- has non-zero emission and area
      if not t.emitivity:isZero() and (t:getArea() > 0) then
         table.insert( emitters, t )
      end
   end

   -- make index
   local index = SpatialIndex.new( eyePosition, triangles )

   local instance = { triangles = triangles, emitters = emitters, index = index,
      skyEmission = skyEmission, groundReflection = groundReflection, }

   return setmetatable( instance, Scene )

end




-- queries ---------------------------------------------------------------------

--- Find nearest intersection of ray with triangle.
---
--- @rayOrigin    Vector3f
--- @rayDirection Vector3f
--- @lastHit      Triangle previous intersected object
---
--- @return Triangle object hit or nil, Vector3f hit position
---
function Scene:getIntersection( rayOrigin, rayDirection, lastHit )

   return self.index:getIntersection( rayOrigin, rayDirection, lastHit )

end


--- Monte-carlo sample point on monte-carlo selected emitting triangle.
---
--- @random Random monte-carlo source
---
--- @return Vector3f position, Triangle or nil
---
function Scene:getEmitter( random )

   -- select emitter
   local index = math.min( #(self.emitters) - 1,
      math.floor( random:real64() * #(self.emitters) ) ) + 1
   local emitter = self.emitters[ index ]

   -- get position on triangle
   return (emitter and emitter:getSamplePoint(random) or Vector3f.ZERO), emitter

end


--- Number of emitters in scene.
---
function Scene:getEmittersCount()

   return #(self.emitters)

end


--- Default/'background' light of scene universe.
---
--- @backDirection Vector3f direction from emitting point
---
--- @return Vector3f emitted radiance
---
function Scene:getDefaultEmission( backDirection )

   -- sky for downward ray, ground for upward ray
   return (backDirection[2] < 0) and self.skyEmission or self.groundReflection

end




return Scene
