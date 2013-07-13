--------------------------------------------------------------------------------
--                                                                            --
--  MiniLight Lua : minimal global illumination renderer                      --
--  Harrison Ainsworth / HXA7241 : 2007-2008, 2013.                           --
--                                                                            --
--  http://www.hxa.name/minilight                                             --
--                                                                            --
--------------------------------------------------------------------------------


local bit = bit32 or require( "bit" )


local Random = {};   Random.__index = Random




--- Simple, fast, good random number generator.
---
--- Constant (sort-of: internally/non-semantically modifying).
---
--- @fields
--- * writeable: none
--- * readable:  none
---
--- @implementation
--- 'Maximally Equidistributed Combined Tausworthe Generators'; L'Ecuyer; 1996.
--- http://www.iro.umontreal.ca/~lecuyer/myftp/papers/tausme2.ps
--- http://www.iro.umontreal.ca/~simardr/rng/lfsr113.c
---
--- 'Conversion of High-Period Random Numbers to Floating Point'; Doornik; 2006.
--- http://www.doornik.com/research/randomdouble.pdf
---
--- @invariants
--- * an Array of 4 Numbers, 32-bit int (Lua unsigned, LuaJIT signed)




-- implementation --------------------------------------------------------------

local band, bxor, bshl, bshr = bit.band, bit.bxor, bit.lshift, bit.rshift




-- construction ----------------------------------------------------------------

--[[function Random.new()

   -- default seed and minimum seeds
   local SEED, SEED_MINS = 987654321, { 2, 8, 16, 128 }

   -- probably Unix time -- signed 32-bit, seconds since 1970
   -- make unsigned, with 2s-comp bit-pattern
   -- rotate to make frequently changing bits more significant
   local time  = (math.floor(os.time()) + 2147483648.0) % 4294967296.0
   time = time + ((time >= 0.0) and -1.0 or 1.0) * 2147483648.0
   local timeu = (time >= 0.0) and time or (time + 4294967296.0)
   local seed  = ((timeu * 256) + math.floor(timeu / 16777216)) % 4294967296

   -- *** VERY IMPORTANT ***
   -- The initial seeds z1, z2, z3, z4  MUST be larger
   -- than 1, 7, 15, and 127 respectively.
   local sa = {}
   for i = 1,4 do sa[i] = (seed >= SEED_MINS[i]) and seed or SEED end

   -- store seed/id as 8 digit hex number string
   local id = string.format( "%08X", sa[4] % 4294967296 )

   local instance = { sa[1], sa[2], sa[3], sa[4], id = id }
   return setmetatable( instance, Random )

end--]]

function Random.new()

   local SEED = 987654321

   -- *** VERY IMPORTANT ***
   -- The initial seeds z1, z2, z3, z4  MUST be larger
   -- than 1, 7, 15, and 127 respectively.
   local instance = { SEED, SEED, SEED, SEED }

   return setmetatable( instance, Random )

end




-- queries ---------------------------------------------------------------------

--- Random integer, 32-bit signed, >= -2^31 and <= 2^31-1.
---
--- @return Number integer
---
function Random:int32()

   self[1] = bxor( bshl(band( self[1], 0xFFFFFFFE ), 18),
                   bshr(bxor(bshl( self[1],  6 ), self[1]), 13) )
   self[2] = bxor( bshl(band( self[2], 0xFFFFFFF8 ),  2),
                   bshr(bxor(bshl( self[2],  2 ), self[2]), 27) )
   self[3] = bxor( bshl(band( self[3], 0xFFFFFFF0 ),  7),
                   bshr(bxor(bshl( self[3], 13 ), self[3]), 21) )
   self[4] = bxor( bshl(band( self[4], 0xFFFFFF80 ), 13),
                   bshr(bxor(bshl( self[4],  3 ), self[4]), 12) )

   local int = bxor( table.unpack( self ) )
   -- make result signed
   -- (Lua bit-ops produce unsigned results, LuaJIT bit-ops produce signed)
   return (int < 2147483648) and int or (int - 4294967296)

end


--- Random real, [0,1) double-precision.
---
--- @return Number in [0,1) range (never returns 1)
---
function Random:real64()

   return (self:int32() * (1 / 4294967296)) + 0.5 +
      ((self:int32() % 2097152) * (1 / 9007199254740992))

end




return Random
