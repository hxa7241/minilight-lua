--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f = require( "Vector3f" )


local Image = {};   Image.__index = Image




--- Pixel sheet, with simple tone-mapping and file formatting.
---
--- Uses PPM image format:
--- http://netpbm.sourceforge.net/doc/ppm.html
---
--- @fields
--- * writeable: none
--- * readable:  width, height.
---
--- @implementation
--- Uses Ward simple tonemapper:
--- 'A Contrast Based Scalefactor For Luminance Display'; Ward; 1994.
--- Graphics Gems 4, AP.
---
--- @invariants
--- * width  is Number integer >= 1 and <= IMAGE_DIM_MAX
--- * height is Number integer >= 1 and <= IMAGE_DIM_MAX
--- * pixels is Table, containing Number fields
--- * pixels length == (width * height * 3)




-- constants -------------------------------------------------------------------

local IMAGE_DIM_MAX = 4000




-- construction ----------------------------------------------------------------

--- @errors raises error if input file is invalid enough
---
--- @input File to read settings from
---
function Image.new( input )

   -- read width and height (after skipping empty space)
   local width, height = input:read( "*n", "*n" )
   --if not (width and height) then error( "invalid image size", 0 ) end

   -- condition width and height
   width  = math.min( math.max( width,  1 ), IMAGE_DIM_MAX )
   height = math.min( math.max( height, 1 ), IMAGE_DIM_MAX )

   -- make pixels (actually, flattened into channels)
   local pixels = {}
   for i = 1, (width * height * 3) do pixels[i] = 0 end

   local instance = { width = width, height = height, pixels = pixels, }

   return setmetatable( instance, Image )

end




-- commands --------------------------------------------------------------------

--- Accumulate (add, not just assign) a value to the image.
---
--- @x        Number integer x coord, 0 to width-1
--- @y        Number integer y coord, 0 to height-1
--- @radiance Vector3f to add
---
function Image:addToPixel( x, y, radiance )

   if (x >= 0) and (x < self.width) and (y >= 0) and (y < self.height) then

      local index = (x + ((self.height - 1 - y) * self.width)) * 3
      for i, channel in ipairs(radiance) do
         self.pixels[index + i] = self.pixels[index + i] + channel
      end

   end

end




-- implementation --------------------------------------------------------------

-- format items
local PPM_ID        = "P6"
local MINILIGHT_URI = "http://www.hxa.name/minilight"

-- ITU-R BT.709 standard gamma
local GAMMA_ENCODE = 0.45

-- guess of average screen maximum brightness
local DISPLAY_LUMINANCE_MAX = 200

-- ITU-R BT.709 standard RGB luminance weighting
local RGB_LUMINANCE = Vector3f.new( 0.2126, 0.7152, 0.0722 )


-- make Lua 5.1 / LuaJIT 2 look like Lua 5.2
local log = math.log
math.log = function( x, b ) return b and (log(x) / log(b)) or log(x) end


--- Calculate tone-mapping scaling factor.
---
--- @pixels  Table of Number fields
--- @divider Number pixel scaling factor
---
--- @return Number scaling factor
---
local function calculateToneMapping( pixels, divider )

   -- calculate estimate of world-adaptation luminance
   -- as log mean luminance of scene
   local sumOfLogs = 0
   for i = 1, #pixels, 3 do
      local Y = Vector3f.new( table.unpack( pixels, i, i+2 ) ):dot(
         RGB_LUMINANCE ) * divider
      -- clamp luminance to a perceptual minimum
      sumOfLogs = sumOfLogs + math.log( math.max(Y, 1e-4), 10 )
   end
   local adaptLuminance = math.pow( 10, sumOfLogs / (#pixels / 3) )

   -- make scale-factor from:
   -- ratio of minimum visible differences in luminance, in display-adapted
   -- and world-adapted perception (discluding the constant that cancelled),
   -- divided by display max to yield a [0,1] range
   local a = 1.219 + math.pow( DISPLAY_LUMINANCE_MAX * 0.25, 0.4 )
   local b = 1.219 + math.pow( adaptLuminance, 0.4 )

   return math.pow( a / b, 2.5 ) / DISPLAY_LUMINANCE_MAX

end




-- queries ---------------------------------------------------------------------

--- Format the image.
---
--- @out       File to receive the image
--- @iteration Number integer of accumulations made to the image
---
function Image:getFormatted( out, iteration )

   -- make pixel value accumulation divider
   local divider = 1 / ((iteration >= 1) and iteration or 1)

   local tonemapScaling = calculateToneMapping( self.pixels, divider )

   -- write ID and comment
   out:write( PPM_ID, "\n", "# ", MINILIGHT_URI, "\n\n" )

   -- write width, height, maxval
   out:write( self.width,  " ", self.height, "\n", 255, "\n" )

   -- write pixels
   for _, channel in ipairs(self.pixels) do
      -- tonemap
      local mapped = channel * divider * tonemapScaling

      -- gamma encode
      mapped = math.pow( ((mapped > 0) and mapped or 0), GAMMA_ENCODE )

      -- quantize
      mapped = math.floor( (mapped * 255) + 0.5 )

      -- output as byte
      out:write( string.char( (mapped <= 255) and mapped or 255 ) )
   end

end




return Image
