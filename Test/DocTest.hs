-- Copyright (c) 2009 Simon Hengel <simon.hengel@web.de>
module Test.DocTest where

import Control.Exception
import Test.HUnit
import System.Plugins
import System.IO
import System.FilePath
import System.Directory
import Test.DocTest.Util


loadTest :: FilePath -> FilePath -> IO Test
loadTest file dir = do
	mv <- load file [dir] [] "docTest"
	case mv of
		LoadFailure msg -> fail ("error while loading " ++ file ++ ": " ++ (concat msg))
		LoadSuccess _ v -> return v


compileModule filename dir = do
	status <- makeAll filename ["-i" ++ dir]
	case status of
		 MakeFailure errors -> fail (concat errors)
		 MakeSuccess _ file -> return file


-- Example:
--
-- > makeTest (DocTest "Fib.hs - line 6: " "Fib" "fib 10" "55")
-- "docTest = TestCase (assertEqual \"Fib.hs - line 6: \" (show (fib 10)) \"55\")"

makeTest (DocTest source _ expression result) = (
		"docTest = TestCase (assertEqual \"" ++
		source ++ "\" " ++
		"(show (" ++ expression ++ "))" ++ " \"" ++
		(escape result) ++ "\")"
	)

escape :: String -> String
escape str = replace "\"" "\\\"" $ replace "\\" "\\\\" str


data DocTest = DocTest {
	  source		:: String
	, _module		:: String
	, expression	:: String
	, result		:: String
	}
	deriving (Show)


writeModule test moduleName handle = do
	hPutStrLn handle ("module " ++ moduleName ++ " where")
	hPutStrLn handle "import Test.HUnit"
	hPutStrLn handle ("import " ++ (_module test))
	hPutStrLn handle (makeTest test)


doTest :: FilePath -> DocTest -> IO Test
doTest directory test = do
	let moduleBaseName = replace "." "_" (_module test)
	(filename, handle) <- openTempFile directory (moduleBaseName ++ ".hs")

	putStrLn filename
	let testModuleName = takeBaseName filename

	--withFile filename WriteMode (writeModule test testModuleName)
	writeModule test testModuleName handle
	hClose handle


	canonicalModulePath <- canonicalizePath $ source test
	putStrLn canonicalModulePath

	let baseDir = packageBaseDir canonicalModulePath (_module test)
	putStrLn baseDir

	obj_file <- compileModule filename baseDir
	loadTest obj_file directory

packageBaseDir :: FilePath -> String -> FilePath
packageBaseDir moduleSrcFile moduleName = stripPostfix (dropExtension moduleSrcFile) (replace "." [pathSeparator] moduleName)
