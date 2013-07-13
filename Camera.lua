--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f  = require( "Vector3f" )
local RayTracer = require( "RayTracer" )


local Camera = {};   Camera.__index = Camera




--- View definition with rasterization capability.
---
--- Constant.
---
--- @fields
--- * writeable: none
--- * readable:  viewPosition.
---
--- @invariants
--- * viewAngle     is Number >= VIEW_ANGLE_MIN and
---                 <= VIEW_ANGLE_MAX degrees in radians
--- * viewPosition  is Vector3f
--- * viewDirection is Vector3f unitized
--- * right         is Vector3f unitized
--- * up            is Vector3f unitized
--- * above three form a coordinate frame




-- constants -------------------------------------------------------------------

local VIEW_ANGLE_MIN =  10
local VIEW_ANGLE_MAX = 160




-- construction ----------------------------------------------------------------

--- @errors raises error if input file is invalid enough
---
--- @input File to read settings from
---
function Camera.new( input )

   -- read view definition (after skipping blank lines)
   local line;   repeat line = input:read("*l") until string.find(line, "%S")
   local p, d, a = string.match( line, "(%(.+%))%s*(%(.+%))%s*(%S+)" )
   --if not (p and d and a) then error( "invalid camera definition", 0 ) end

   -- extract and condition view definition parts
   local viewPosition  = Vector3f.new( p )
   local viewDirection = Vector3f.new( d ):unitized()
   if viewDirection:isZero() then viewDirection = Vector3f.new( 0, 0, 1 ) end
   local viewAngle = math.rad( math.min( math.max(tonumber(a or 90),
      VIEW_ANGLE_MIN), VIEW_ANGLE_MAX ) )

   -- make other directions of frame
   local up    = Vector3f.new( 0, 1, 0 )
   local right = up:cross( viewDirection ):unitized()

   if not right:isZero() then
      up    = viewDirection:cross( right ):unitized()
   else
      up    = Vector3f.new( 0, 0, (viewDirection[2] < 0) and 1 or -1 )
      right = up:cross( viewDirection ):unitized()
   end

   local instance = { viewAngle = viewAngle, viewPosition = viewPosition,
      viewDirection = viewDirection, right = right, up = up }

   return setmetatable( instance, Camera )

end




-- queries ---------------------------------------------------------------------

--- Accumulate a new frame to the image.
---
--- @scene  Scene to read from
--- @random not actually random really, is it?
--- @image  Image to write to
---
function Camera:getFrame( scene, random, image )

   local rayTracer = RayTracer.new( scene )

   -- do image sampling pixel loop
   for y = 0, image.height - 1 do
      for x = 0, image.width - 1 do

         -- make sample ray direction, stratified by pixels

         -- make image plane displacement vector coefficients
         local xCoefficient = ((x + random:real64()) * 2 / image.width ) - 1
         local yCoefficient = ((y + random:real64()) * 2 / image.height) - 1

         -- make image plane offset vector
         local offset = (self.right * xCoefficient) +
            (self.up * yCoefficient * (image.height / image.width))

         local sampleDirection = (self.viewDirection +
            (offset * math.tan(self.viewAngle * 0.5))):unitized()

         -- get radiance from RayTracer
         local radiance = rayTracer:getRadiance( self.viewPosition,
            sampleDirection, random )

         -- add radiance to pixel
         image:addToPixel( x, y, radiance )

      end
   end

end




return Camera
