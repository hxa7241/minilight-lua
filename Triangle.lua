--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f = require( "Vector3f" )


local Triangle = {};   Triangle.__index = Triangle




--- Simple, explicit/non-vertex-shared triangle.
---
--- Includes geometry and quality.
---
--- Constant.
---
--- @fields
--- * writeable: none
--- * readable:  reflectivity, emitivity.
---
--- @implementation
--- Adapts ray intersection code from:
--- 'Fast, Minimum Storage Ray-Triangle Intersection'; Moller, Trumbore; 1997.
--- Journal of Graphics Tools, v2 n1 p21.
--- http://www.acm.org/jgt/papers/MollerTrumbore97/
---
--- @invariants
--- * [1-3]        three Vector3f (the vertexs)
--- * reflectivity is Vector3f >= 0 and <= 1
--- * emitivity    is Vector3f >= 0




-- construction ----------------------------------------------------------------

--- @errors raises error if too few vector parts found in triangle data
---
--- @line String to read from
---
function Triangle.new( line )

   -- extract vectors from input string
   local v1, v2, v3, r, e = string.match( line,
      "(%(.+%))%s*(%(.+%))%s*(%(.+%))%s*(%(.+%))%s*(%(.+%))" )
   --if not (v1 and v2 and v3 and r and e) then
   --   error( "invalid triangle data", 0 ) end

   -- separate triangle parts (three vertexs, reflectivity, emitivity)
   local instance = {
      Vector3f.new(v1), Vector3f.new(v2), Vector3f.new(v3),
      reflectivity = Vector3f.new(r):clamped( Vector3f.ZERO, Vector3f.ONE ),
      emitivity    = Vector3f.new(e):clamped( Vector3f.ZERO, Vector3f.MAX ),
   }

   return setmetatable( instance, Triangle )

end




-- constants -------------------------------------------------------------------

-- one mm seems reasonable...
Triangle.TOLERANCE = 1 / 1024

Triangle.EPSILON   = 1 / 1048576




-- queries ---------------------------------------------------------------------

--- Axis-aligned bounding box of triangle.
---
--- @return Table of six Number, lower corner in [1-3], upper corner in [4-6]
---
function Triangle:getBound()

   -- initialize
   local bound = {};
   for i = 1, 6 do bound[i] = self[3][ ((i-1) % 3) + 1 ] end

   -- expand
   for i = 1, 3 do
      local v = self[i]
      for j = 1, 6 do
         local d, m = (j > 3) and -1 or 1, ((j-1) % 3) + 1

         -- include some tolerance
         local a = v[m] - (d * Triangle.TOLERANCE)
         if ((a - bound[j]) * d) < 0 then bound[j] = a end
      end
   end

   return bound

end


--- Intersection point of ray with triangle.
---
--- Vector operations are manually inlined (is much faster).
---
--- @rayOrigin    Vector3f
--- @rayDirection Vector3f
---
--- @return Number distance along ray or nil
---
function Triangle:getIntersection( rayOrigin, rayDirection )

   local v1, v2, v3    = self[1], self[2], self[3]
   local rdx, rdy, rdz = rayDirection[1], rayDirection[2], rayDirection[3]

   -- find vectors for two edges sharing vert0
   --local edge1 = self[2] - self[1]
   --local edge2 = self[3] - self[1]
   local e1x, e1y, e1z = (v2[1] - v1[1]), (v2[2] - v1[2]), (v2[3] - v1[3])
   local e2x, e2y, e2z = (v3[1] - v1[1]), (v3[2] - v1[2]), (v3[3] - v1[3])

   -- begin calculating determinant - also used to calculate U parameter
   --local pvec = rayDirection:cross( edge2 )
   local pvx = (rdy * e2z) - (rdz * e2y)
   local pvy = (rdz * e2x) - (rdx * e2z)
   local pvz = (rdx * e2y) - (rdy * e2x)

   -- if determinant is near zero, ray lies in plane of triangle
   --local det = edge1:dot( pvec )
   local det = (e1x * pvx) + (e1y * pvy) + (e1z * pvz)

   if (det > -Triangle.EPSILON) and (det < Triangle.EPSILON) then return end

   local inv_det = 1 / det

   -- calculate distance from vertex 0 to ray origin
   --local tvec = rayOrigin - self[1]
   local tvx = rayOrigin[1] - v1[1]
   local tvy = rayOrigin[2] - v1[2]
   local tvz = rayOrigin[3] - v1[3]

   -- calculate U parameter and test bounds
   --local u = tvec:dot( pvec ) * inv_det
   local u = ((tvx * pvx) + (tvy * pvy) + (tvz * pvz)) * inv_det
   if (u < 0) or (u > 1) then return end

   -- prepare to test V parameter
   --local qvec = tvec:cross( edge1 )
   local qvx = (tvy * e1z) - (tvz * e1y)
   local qvy = (tvz * e1x) - (tvx * e1z)
   local qvz = (tvx * e1y) - (tvy * e1x)

   -- calculate V parameter and test bounds
   --local v = rayDirection:dot( qvec ) * inv_det
   local v = ((rdx * qvx) + (rdy * qvy) + (rdz * qvz)) * inv_det
   if (v < 0) or (u + v > 1) then return end

   -- calculate t, ray intersects triangle
   --local hitDistance = edge2:dot( qvec ) * inv_det
   local hitDistance = ((e2x * qvx) + (e2y * qvy) + (e2z * qvz)) * inv_det

   -- only allow intersections in the forward ray direction
   return (hitDistance >= 0) and hitDistance or nil

end


--- Monte-carlo sample point on triangle.
---
--- @random dispenser of uniform deviates
--- @return Vector3f
---
function Triangle:getSamplePoint( random )

   -- get two randoms
   local sqr1, r2 = math.sqrt(random:real64()), random:real64()

   -- make barycentric coords
   local a, b = (1 - sqr1), ((1 - r2) * sqr1)
   --local c    = r2 * sqr1

   -- make position from barycentrics
   -- calculate interpolation by using two edges as axes scaled by the
   -- barycentrics
   return ((self[2] - self[1]) * a) + ((self[3] - self[1]) * b) + self[1]

end


--- @return Vector3f
---
function Triangle:getNormal()

   return self:getTangent():cross( self[3] - self[2] ):unitized()

end


--- @return Vector3f
---
function Triangle:getTangent()

   return (self[2] - self[1]):unitized()

end


--- @return Number
---
function Triangle:getArea()

   -- half area of parallelogram
   local pa2 = (self[2] - self[1]):cross( self[3] - self[2] )
   return math.sqrt( pa2:dot(pa2) ) * 0.5

end




return Triangle
