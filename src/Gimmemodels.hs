import System.IO
import System.Environment
import qualified GimmeModels.Types as BT
import qualified GimmeModels.Lang.ObjectiveC.Types as OC
import qualified GimmeModels.Schema.JSONSchema.Types as JS
import Data.List
import Data.Maybe
import System.Exit
import Data.Foldable (foldlM)
import System.Console.GetOpt

data Options = Options {
      optTargetLang   :: String
    , optSchemaType   :: String
    , optClassPrefix  :: Maybe String
    , optClassSuffix  :: Maybe String
    , optSuperclass   :: Maybe BT.Type 
    , optInput        :: [FilePath]
    } deriving (Show)

defaultOptions = Options {
      optTargetLang   = ""
    , optSchemaType   = "json-schema"
    , optClassPrefix  = Nothing
    , optClassSuffix  = Just "Model"
    , optSuperclass   = Nothing
    , optInput        = []
    }

options :: String -> [OptDescr (Options -> IO Options)]

options helpMessage = 
    [ Option ['h'] ["help"] 
             (NoArg (\_ -> do putStr helpMessage; exitSuccess)) 
             "print usage information"
    , Option ['s']["schema"] 
             (ReqArg (\str opts -> do return $ opts { optSchemaType = str }) "schema")
             "*IGNORING* set specific schema type (json-schema assuming default)"
    , Option ['l']["lang"]
             (ReqArg (\str opts -> do return $ opts { optTargetLang = str }) "language")
             "*IGNORING* target language"
    , Option ['b']["prefix"]
            (ReqArg (\str opts -> do return $ opts { optClassPrefix = Just str}) "prefix")
            "set class prefix for generated models"
    , Option ['p']["superclass"]
             (ReqArg (\str opts -> do return $ opts { optSuperclass = Just $ BT.Type str }) "superclass")
             "generated models custom superclass"
    , Option ['e']["suffix"] (ReqArg (\str opts -> do return $ opts { optClassSuffix = Just str}) "suffix")
             "set class suffix for generated models" ] 

parseArgs = do
    argv     <- getArgs
    progName <- getProgName
    let header = "Usage: " ++ progName ++ " [OPTIONS...] path-to-schema"
        helpMessage = usageInfo header (options "")
    case getOpt RequireOrder (options helpMessage) argv of
        (opts, files, []) -> case files of 
                                [] -> do putStrLn helpMessage; exitSuccess 
                                _  -> foldlM (flip id) (defaultOptions {optInput = files}) opts
        (_, _, errs) -> ioError (userError (concat errs ++ helpMessage))


getModel :: Options -> String -> BT.Model 
getModel opts sc = 
    case schemaT of 
        "json-schema" -> case (JS.parseSchemaFromString sc) of 
                            Just s  -> BT.fromSchema s Nothing super 
                            Nothing -> error "Can't parse schema"
        _ -> error "Unknown schema type"
    where
       schemaT = optSchemaType opts
       super   = optSuperclass opts


getFiles :: BT.Model -> Options -> [BT.File]
getFiles mdl opts = 
    case lang of 
        "objc" -> BT.generate (BT.fromBase mdl $ BT.NamingOptions prefix suffix :: OC.Model)
        _      -> error "Unknown target language"
        where
            lang    = optTargetLang opts
            prefix  = optClassPrefix opts
            suffix  = optClassSuffix opts

-- | Read file with specific encoding
readFile' e name = do {h <- openFile name ReadMode; hSetEncoding h e; hGetContents h}  
  
run opts = do 
    let file = head $ optInput opts
    content <- readFile' utf8_bom file

    let bmodel = getModel opts content
        files  = getFiles bmodel opts

    mapM_ (\f -> writeFile (BT.fileName f) (BT.fileContent f)) files

main = do 
    options <- parseArgs
    run options