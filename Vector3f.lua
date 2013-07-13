--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local Vector3f = {};   Vector3f.__index = Vector3f




--- Yes, its the 3D vector class!.
---
--- ...mostly the usual sort of stuff.
--- (Unused things are commented out. They do work fine though.)
---
--- Constant.
---
--- @fields
--- * writeable: none
--- * readable:  [1], [2], [3].
---
--- @invariants
--- * [1-3] are Number




-- construction ----------------------------------------------------------------

--- @x Number
--- @y Number
--- @z Number
---
local function new_( x, y, z )

   return setmetatable( { x, y, z, }, Vector3f )

end


--- @errors raises error if too few numbers found in string data
---
--- @x Number, or formatted String eg: (11  2.3e+1 -.007 ), or nil for zero
--- @y Number, or nil to duplicate x
--- @z Number, or nil to duplicate y
---
function Vector3f.new( x, y, z )

   -- extract x y z from string argument
   if type(x) == "string" then
      x, y, z = string.match( x, "%(%s*(%S+)%s+(%S+)%s+(%S+)%s*%)" )
      x, y, z = tonumber(x), tonumber(y), tonumber(z)
      --if not (x and y and z) then error( "invalid vector definition", 0 ) end
   end

   return new_( x or 0, y or (x or 0), z or (y or (x or 0)) )

end




-- constants -------------------------------------------------------------------

Vector3f.ZERO       = Vector3f.new()
-- Vector3f.HALF       = Vector3f.new( 0.5 )
Vector3f.ONE        = Vector3f.new( 1 )
-- Vector3f.EPSILON    = Vector3f.new( math.epsilon )
-- Vector3f.ALMOST_ONE = Vector3f.new( math.almostOne )
Vector3f.MIN        = Vector3f.new( -math.huge )
Vector3f.MAX        = Vector3f.new(  math.huge )
-- Vector3f.SMALL      = Vector3f.new( math.small )
-- Vector3f.LARGE      = Vector3f.new( math.large )
-- Vector3f.X          = Vector3f.new( 1, 0, 0 )
-- Vector3f.Y          = Vector3f.new( 0, 1, 0 )
-- Vector3f.Z          = Vector3f.new( 0, 0, 1 )




-- queries ---------------------------------------------------------------------

-- read

--[[function Vector3f:getX()
   return self[1]
end


function Vector3f:getY()
   return self[2]
end


function Vector3f:getZ()
   return self[3]
end--]]


-- reductions, statistical

--[[function Vector3f:sum()
   return self[1] + self[2] + self[3]
end

function Vector3f:average()
   return (self[1] + self[2] + self[3]) / 3
end

function Vector3f:smallest()
   local smallest = (self[1]  <= self[2]) and self[1]  or self[2]
   return           (smallest <= self[3]) and smallest or self[3]
end

function Vector3f:largest()
   local largest = (self[1] >= self[2]) and self[1] or self[2]
   return          (largest >= self[3]) and largest or self[3]
end--]]


-- reductions, geometrical

--[[function Vector3f:length()
   return math.sqrt(
      (self[1] * self[1]) + (self[2] * self[2]) + (self[3] * self[3]) )
end

function Vector3f:distance( v )
   local xDif, yDif, zDif = (self[1] - v[1]), (self[2] - v[2]), (self[3] - v[3])

   return math.sqrt( (xDif * xDif) + (yDif * yDif) + (zDif * zDif) )
end--]]

function Vector3f:dot( v )
   return (self[1] * v[1]) + (self[2] * v[2]) + (self[3] * v[3])
end


-- mappings, unary

function Vector3f.__unm( v )
   return new_( -v[1], -v[2], -v[3] )
end

--[[function Vector3f:abs()
   return new_( math.abs(self[1]), math.abs(self[2]), math.abs(self[3]))
end--]]

function Vector3f:unitized()
   local length = math.sqrt( self:dot( self ) )
   return self * ((length ~= 0) and (1 / length) or 0)
end

function Vector3f:cross( v )
   return new_( (self[2] * v[3]) - (self[3] * v[2]),
                (self[3] * v[1]) - (self[1] * v[3]),
                (self[1] * v[2]) - (self[2] * v[1]) )
end


-- mappings, binary (operator overloads)

--[[local function promoteOperands( a, b )
   return (getmetatable(a) == Vector3f) and a or Vector3f.new( a ),
          (getmetatable(b) == Vector3f) and b or Vector3f.new( b )
end--]]

function Vector3f.__add( a, b )
   --local a, b = promoteOperands( a, b )

   return new_( (a[1] + b[1]), (a[2] + b[2]), (a[3] + b[3]) )
end

function Vector3f.__sub( a, b )
   --local a, b = promoteOperands( a, b )

   return new_( (a[1] - b[1]), (a[2] - b[2]), (a[3] - b[3]) )
end

function Vector3f.__mul( a, b )
   --local a, b = promoteOperands( a, b )

   return (getmetatable(b) == Vector3f) and
      new_( (a[1] * b[1]), (a[2] * b[2]), (a[3] * b[3]) ) or
      new_( (a[1] * b), (a[2] * b), (a[3] * b) )
end

function Vector3f.__div( a, b )
   --local a, b = promoteOperands( a, b )

   return new_( (a[1] / b[1]), (a[2] / b[2]), (a[3] / b[3]) )
end


-- comparisons

--[[function Vector3f.__eq( a, b )
   return (a[1] == b[1]) and (a[2] == b[2]) and (a[3] == b[3])
end--]]

function Vector3f:isZero()
   return (self[1] == 0) and (self[2] == 0) and (self[3] == 0)
end


-- clamps

--- 0 to almost 1, ie: [0,1).
---
--[[function Vector3f:clamped01()
   return self:clamped( Vector3f.ZERO, Vector3f.ALMOST_ONE )
end--]]

function Vector3f:clamped( min, max )
   return new_( math.min( math.max( self[1], min[1] ), max[1] ),
                math.min( math.max( self[2], min[2] ), max[2] ),
                math.min( math.max( self[3], min[3] ), max[3] ) )
end


-- to string

--[[function Vector3f:__tostring()
   return string.format( "(%.6g %.6g %.6g)", self[1], self[2], self[3] )
   --return string.format( "(% .6e % .6e % .6e)", self[1], self[2], self[3] )
end--]]




return Vector3f
