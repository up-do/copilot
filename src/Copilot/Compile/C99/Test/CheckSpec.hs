--------------------------------------------------------------------------------
-- Copyright © 2011 National Institute of Aerospace / Galois, Inc.
--------------------------------------------------------------------------------

module Copilot.Compile.C99.Test.CheckSpec (checkSpec) where

import Copilot.Compile.C99 (compile)
import Copilot.Core (Spec)
import Copilot.Core.Interpret.Eval (eval)
import Copilot.Compile.C99.Params (Params (..), defaultParams)
import Copilot.Compile.C99.Test.Driver (driver)
import Copilot.Compile.C99.Test.Iteration (Iteration, execTraceToIterations)
import Copilot.Compile.C99.Test.ReadCSV (iterationsFromCSV)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as B
import qualified Data.Map as M
import qualified Data.Text.IO as TIO
import System.Directory (removeFile)
import System.Process (system, readProcess)

--------------------------------------------------------------------------------

checkSpec :: Int -> Spec -> IO Bool
checkSpec numIterations spec =
  do
    genCFiles numIterations spec
    compileCFiles
    csv <- execute numIterations
    let
      is1 = iterationsFromCSV csv
      is2 = interp numIterations spec
    print is1
    print "..."
    print is2
    cleanUp
    return (is1 == is2)

genCFiles :: Int -> Spec -> IO ()
genCFiles numIterations spec =
  do
    compile (defaultParams { prefix = Nothing }) spec
    TIO.writeFile "driver.c" (driver M.empty numIterations spec)
    return ()

compileCFiles :: IO ()
compileCFiles =
  do
    _ <- system $ "gcc copilot.c driver.c -o _test"
    return ()

execute :: Int -> IO ByteString
execute _ =
  do
    fmap B.pack (readProcess "./_test" [] "")

interp :: Int -> Spec -> [Iteration]
interp numIterations = execTraceToIterations . eval numIterations []

cleanUp :: IO ()
cleanUp =
  do
    removeFile "copilot.c"
    removeFile "copilot.h"
    removeFile "driver.c"
    removeFile "_test"
    return ()
