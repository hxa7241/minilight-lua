--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f = require( "Vector3f" )


local SurfacePoint = {};   SurfacePoint.__index = SurfacePoint




--- Surface point at a ray-object intersection.
---
--- All direction parameters are away from surface.
---
--- Constant.
---
--- @fields
--- * writeable: none
--- * readable:  triangle, position.
---
--- @invariants
--- * triangle is Triangle
--- * position is Vector3f




-- construction ----------------------------------------------------------------

--- @triangle Triangle
--- @Position Vector3f
---
function SurfacePoint.new( triangle, position )

   local instance = { triangle = triangle, position = position, }

   return setmetatable( instance, SurfacePoint )

end




-- queries ---------------------------------------------------------------------

--- Emission from surface element to point.
---
--- @toPosition   Vector3f point being illuminated
--- @outDirection Vector3f direction from emitting point
--- @isSolidAngle Boolean is solid angle used
---
--- @return Vector3f emitted radiance
---
function SurfacePoint:getEmission( toPosition, outDirection, isSolidAngle )

   local ray       = toPosition - self.position
   local distance2 = ray:dot( ray )
   local cosArea   = outDirection:dot( self.triangle:getNormal() ) *
      self.triangle:getArea()

   -- clamp-out infinity
   local solidAngle = cosArea / math.max( distance2, 1e-6 )

   -- front face of triangle only
   return (cosArea > 0) and (self.triangle.emitivity *
      (isSolidAngle and solidAngle or 1)) or Vector3f.ZERO

end


--- Light reflection from ray to ray by surface.
---
--- @inDirection  Vector3f negative of inward ray direction
--- @inRadiance   Vector3f inward radiance
--- @outDirection Vector3f outward ray (towards eye) direction
---
--- @return Vector3f reflected radiance
---
function SurfacePoint:getReflection( inDirection, inRadiance, outDirection )

   local inDot  = inDirection:dot(  self.triangle:getNormal() )
   local outDot = outDirection:dot( self.triangle:getNormal() )

   -- directions must be on same side of surface
   return (-inDot * outDot) > 0 and Vector3f.ZERO or
      -- ideal diffuse BRDF:
      -- radiance scaled by cosine, 1/pi, and reflectivity
      (inRadiance * self.triangle.reflectivity) * (math.abs( inDot ) / math.pi)

end


--- Monte-carlo direction of reflection from surface.
---
--- @inDirection Vector3f eyeward ray direction
---
--- @return Vector3f sceneward ray direction, Vector3f color of
--- interaction point
---
function SurfacePoint:getNextDirection( random, inDirection )

   local outDirection, color = Vector3f.ZERO, Vector3f.ZERO

   local reflectivityMean = self.triangle.reflectivity:dot( Vector3f.ONE ) / 3

   -- russian-roulette for reflectance magnitude
   if random:real64() < reflectivityMean then

      color = self.triangle.reflectivity * (1 / reflectivityMean)

      -- cosine-weighted importance sample hemisphere

      local _2pr1 = math.pi * 2 * random:real64()
      local sr2   = math.sqrt(random:real64())

      -- make coord frame coefficients (z in normal direction)
      local x, y = (math.cos(_2pr1) * sr2), (math.sin(_2pr1) * sr2)
      local z    = math.sqrt( 1 - (sr2 * sr2) )

      -- make coord frame
      local normal  = self.triangle:getNormal()
      local tangent = self.triangle:getTangent()
      -- enable reflection from either face of surface
      normal = (normal:dot(inDirection) >= 0) and normal or -normal

      -- make vector from frame times coefficients
      outDirection = (tangent * x) + (normal:cross(tangent) * y) + (normal * z)

   end

   return outDirection, color

end




return SurfacePoint
