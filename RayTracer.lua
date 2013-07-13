--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f     = require( "Vector3f" )
local SurfacePoint = require( "SurfacePoint" )


local RayTracer = {};   RayTracer.__index = RayTracer




--- Ray tracer for general light transport.
---
--- Traces a path with emitter sampling each step: A single chain of ray-steps
--- advances from the eye into the scene with one sampling of emitters at each
--- node.
---
--- Constant.
---
--- @fields
--- * writeable: none
--- * readable:  none
---
--- @invariants
--- * scene is Scene




-- construction ----------------------------------------------------------------

--- @scene Scene
---
function RayTracer.new( scene )

   local instance = { scene = scene }

   return setmetatable( instance, RayTracer )

end




-- implementation --------------------------------------------------------------

--- Radiance from an emitter sample.
---
--- @rayDirection Vector3f ray direction
--- @surfacePoint SurfacePoint
--- @random       random
---
--- @return Vector3f radiance back along ray direction
---
local function sampleEmitters( self, rayDirection, surfacePoint, random )

   local radiance = Vector3f.ZERO

   -- single emitter sample, ideal diffuse BRDF:
   -- reflected = (emitivity * solidangle) * (emitterscount) *
   -- (cos(emitdirection) / pi * reflectivity)
   -- -- SurfacePoint does the first and last parts (in separate methods)

   -- check an emitter is found
   local emitterPosition, emitter = self.scene:getEmitter( random )
   if emitter then

      -- make direction to emit point
      local emitDirection = (emitterPosition - surfacePoint.position):unitized()

      -- send shadow ray
      local hitObject, _ = self.scene:getIntersection( surfacePoint.position,
         emitDirection, surfacePoint.triangle )

      -- if unshadowed, get inward emission value
      local emissionIn = Vector3f.ZERO
      if (not hitObject) or (emitter == hitObject) then
         emissionIn = SurfacePoint.new( emitter, emitterPosition ):getEmission(
            surfacePoint.position, -emitDirection, true )
      end

      -- get amount reflected by surface
      radiance = surfacePoint:getReflection( emitDirection,
         (emissionIn * self.scene:getEmittersCount()), -rayDirection )

   end

   return radiance

end




-- queries ---------------------------------------------------------------------

--- Returned radiance from a trace.
---
--- @rayOrigin    Vector3f ray start point
--- @rayDirection Vector3f ray direction
--- @random       pseudo-quasi-ersatz-randomness
--- @lastHit      Triangle previous intersected object in scene
---
--- @return Vector3f radiance back along ray direction
---
function RayTracer:getRadiance( rayOrigin, rayDirection, random, lastHit )

   -- intersect ray with scene
   local hitObject, hitPosition = self.scene:getIntersection(
      rayOrigin, rayDirection, lastHit )

   local radiance
   if hitObject then

      -- make surface point of intersection
      local surfacePoint = SurfacePoint.new( hitObject, hitPosition )

      -- add local emission only for first-hit
      radiance = lastHit and Vector3f.ZERO or
         surfacePoint:getEmission( rayOrigin, -rayDirection, false )

      -- add emitter sample
      radiance = radiance + sampleEmitters( self, rayDirection, surfacePoint,
         random )

      -- add recursive reflection:
      -- single hemisphere sample, ideal diffuse BRDF:
      -- reflected = (inradiance * pi) * (cos(in) / pi * color) * reflectance
      -- -- reflectance magnitude is 'scaled' by the russian roulette, cos is
      -- importance sampled (both done by SurfacePoint), and the pi and 1/pi
      -- cancel out
      local nextDirection, color = surfacePoint:getNextDirection( random,
         -rayDirection )
      -- check surface bounces ray
      if not nextDirection:isZero() then

         -- recurse
         radiance = radiance + (color * self:getRadiance( surfacePoint.position,
            nextDirection, random, surfacePoint.triangle ))

      end

   else
      -- no hit: default/background scene emission
      radiance = self.scene:getDefaultEmission( -rayDirection )
   end

   return radiance

end




return RayTracer
