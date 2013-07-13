#!/usr/bin/env lua
--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------




local Random = require( "Random" )
local Image  = require( "Image" )
local Scene  = require( "Scene" )
local Camera = require( "Camera" )




--- Control module and entry point.
---
--- Handles command-line UI, and runs the main progressive-refinement render
--- loop.
---
--- Supply a model file pathname as the command-line argument. Or -? for help.




-- version compatibility -------------------------------------------------------

-- make Lua 5.1 / LuaJIT 2 look like Lua 5.2
if not table.unpack then table.unpack = unpack end




-- user messages ---------------------------------------------------------------

local BANNER_MESSAGE = "\
  MiniLight 1.6 Lua - http://www.hxa.name/minilight\
"

local HELP_MESSAGE = "\
----------------------------------------------------------------------\
  MiniLight 1.6 Lua\
\
  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.\
  http://www.hxa.name/minilight\
\
  2013-05-04\
----------------------------------------------------------------------\
\
MiniLight is a minimal global illumination renderer.\
\
usage:\
  minilight modelFilePathName\
\
The model text file format is:\
  #MiniLight\
\
  iterations\
\
  imagewidth imageheight\
  viewposition viewdirection viewangle\
\
  skyemission groundreflection\
\
  vertex0 vertex1 vertex2 reflectivity emitivity\
  vertex0 vertex1 vertex2 reflectivity emitivity\
  ...\
\
- where iterations and image values are integers, viewangle is a real,\
and all other values are three parenthised reals. The file must end\
with a newline. E.g.:\
  #MiniLight\
\
  100\
\
  200 150\
  (0 0.75 -2) (0 0 1) 45\
\
  (3626 5572 5802) (0.1 0.09 0.07)\
\
  (0 0 0) (0 1 0) (1 1 0)  (0.7 0.7 0.7) (0 0 0)\
"




-- entry point -----------------------------------------------------------------

local MODEL_FORMAT_ID = "#MiniLight"
local EXIT_SUCCESS, EXIT_FAILURE = 0, 1


local function main()

   -- check for help request
   if (not arg[1]) or (arg[1] == "-?") or (arg[1] == "--help") then

      print( HELP_MESSAGE )

   -- execute
   else

      print( BANNER_MESSAGE )

      -- make random generator
      local random = Random.new()

      -- get file names
      local modelFilePathname = arg[1]
      imageFilePathname = modelFilePathname .. ".ppm"

      -- open model file
      local modelFile = io.open( modelFilePathname, "r" )
      if not modelFile then error( "file not found", 0 ) end

      -- check model file format identifier at start of first line
      if string.sub( modelFile:read("*l"), 1, #MODEL_FORMAT_ID ) ~=
         MODEL_FORMAT_ID then error( "invalid model file", 0 ) end

      -- read frame iterations
      local iterations = math.floor( modelFile:read( "*n" ) )

      -- create top-level rendering objects with model file
      image = Image.new( modelFile )
      local camera = Camera.new( modelFile )
      local scene  = Scene.new( modelFile, camera.viewPosition )

      modelFile:close()

      -- do progressive refinement render loop
      for frameNo = 1, iterations do

         -- display latest frame number
         io.write( "\riteration: " .. frameNo )
         io.flush()

         -- render a frame
         camera:getFrame( scene, random, image )

         -- save image at twice error-halving rate, and at start and end
         if (math.frexp(frameNo) == 0.5) or (frameNo == iterations) then

            -- write image frame to file
            local imageFile = io.open( imageFilePathname, "wb" )
            image:getFormatted( imageFile, frameNo )
            imageFile:close()
         end

      end

      print( "\nfinished" )

   end

end


-- run the program
local ok, message = pcall( main )

-- catch error and wrap message
if not ok then

   -- ctrl-c
   if string.find( message, "interrupted") then
      print( "\ninterrupted" )
      ok = true

   -- anything else
   else
      print( "\n*** execution failed:  " .. message )
   end

end

return ok and EXIT_SUCCESS or EXIT_FAILURE
