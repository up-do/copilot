-- | An example showing the usage of the What4 backend in copilot-theorem for
-- structs and arrays. Particular focus is on nested structs.
-- For general usage of structs, refer to the general structs example.

{-# LANGUAGE DataKinds #-}

module Main where

import qualified Prelude as P
import Control.Monad (void, forM_)

import Language.Copilot
import Copilot.Theorem.What4

-- | Definition for `Volts`.
data Volts = Volts
  { numVolts :: Field "numVolts" Word16
  , flag     :: Field "flag"     Bool
  }

-- | `Struct` instance for `Volts`.
instance Struct Volts where
  typeName _ = "volts"
  toValues volts = [ Value Word16 (numVolts volts)
                   , Value Bool   (flag volts)
                   ]
  -- Note that we do not implement `updateField` here. `updateField` is only
  -- needed to make updates to structs work in the Copilot interpreter, and we
  -- do not use the interpreter in this example. (See
  -- `examples/StructsUpdateField.hs` for an example that does implement
  -- `updateField`.)

-- | `Volts` instance for `Typed`.
instance Typed Volts where
  typeOf = Struct (Volts (Field 0) (Field False))

data Battery = Battery
  { temp  :: Field "temp"  Word16
  , volts :: Field "volts" (Array 10 Volts)
  , other :: Field "other" (Array 10 (Array 5 Word32))
  }

-- | `Battery` instance for `Struct`.
instance Struct Battery where
  typeName _ = "battery"
  toValues battery = [ Value typeOf (temp battery)
                     , Value typeOf (volts battery)
                     , Value typeOf (other battery)
                     ]
  -- Note that we do not implement `updateField` here for the same reasons as in
  -- the `Struct Volts` instance above.

-- | `Battery` instance for `Typed`. Note that `undefined` is used as an
-- argument to `Field`. This argument is never used, so `undefined` will never
-- throw an error.
instance Typed Battery where
  typeOf = Struct (Battery (Field 0) (Field undefined) (Field undefined))

spec :: Spec
spec = do
  let battery :: Stream Battery
      battery = extern "battery" Nothing

  -- Check equality, indexing into nested structs and arrays. Note that this is
  -- trivial by equality.
  void $ prop "Example 1" $ forAll $
    (((battery#volts) ! 0)#numVolts) == (((battery#volts) ! 0)#numVolts)

  -- Same as previous example, but get a different array index (so should be
  -- false).
  void $ prop "Example 2" $ forAll $
    (((battery#other) ! 2) ! 3) == (((battery#other) ! 2) ! 4)

  -- Update a struct field, then check it for equality.
  void $ prop "Example 3" $ forAll $
    ((battery ## temp =$ (+1))#temp == (battery#temp + 1))

main :: IO ()
main = do
  spec' <- reify spec

  -- Use Z3 to prove the properties.
  results <- prove Z3 spec'

  -- Print the results.
  forM_ results $ \(nm, res) -> do
    putStr $ nm <> ": "
    case res of
      Valid   -> putStrLn "valid"
      Invalid -> putStrLn "invalid"
      Unknown -> putStrLn "unknown"
