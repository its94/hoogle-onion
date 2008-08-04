
module Web.Action(actionWeb) where

import CmdLine.All
import Hoogle.All
import Hoogle.Query.All
import Hoogle.Item.All
import Hoogle.Search.All
import General.Code
import System.IO.Unsafe(unsafeInterleaveIO)
import Web.Page
import Text.ParserCombinators.Parsec
import Data.TagStr


actionWeb :: CmdQuery -> IO ()
actionWeb q = do
    (skipped,dbs) <- loadDataBases q
    let res = unlines $ header (escapeHTML $ queryText q) ++ runQuery dbs q ++ footer
    when (Debug `elem` queryFlags q) $
        writeFile "temp.htm" res
    putStrLn res


-- is the package not something that might go wrong
safePackage :: String -> Bool
safePackage = all $ \x -> isAlphaNum x || x `elem` "-_"


-- return the databases you loaded, and those you can't
-- guarantees not to actually load the databases unless necessary
-- TODO: Should say which databases are ignored
loadDataBases :: CmdQuery -> IO ([String], [DataBase])
loadDataBases CmdQuery{query=Right q} = do
    let pkgs = nub [x | PlusPackage x <- scope q, safePackage x]
        files = if null pkgs then ["default"] else pkgs
    files <- filterM doesFileExist $ map (\x -> "res" </> x <.> "hoo") files
    dbs <- unsafeInterleaveIO $ mapM loadDataBase files
    return ([], dbs)
loadDataBases _ = return ([], [])


-- TODO: Should escape the query text
runQuery :: [DataBase] -> CmdQuery -> [String]
runQuery dbs CmdQuery{queryText = text, query = Left err} =
    ["<h1>Parse error in user query</h1>"
    ,"<p>"
    ,"  Query: <tt>" +? pre ++ "<span id='error'>" +? post2 ++ "</span></tt><br/>"
    ,"</p><p>"
    ,"  Error: " +? drop 1 (dropWhile (/= ':') $ show err) ++ "<br/>"
    ,"</p><p>"
    ,"  For information on what queries should look like, see the user manual."
    ,"</p>"
    ]
    where
        (pre,post) = splitAt (sourceColumn (errorPos err) - 1) text
        post2 = if null post then concat (replicate 3 "&nbsp;") else post


runQuery dbs q | not $ usefulQuery $ fromRight $ query q =
    ["<h1>Welcome to Hoogle</h1>"
    ,"<p>"
    ,"  Hoogle is a Haskell API search engine, have fun!"
    ,"</p>"
    ]


runQuery dbs CmdQuery{query = Right q} =
    ["<h1>Searched for " ++ qstr ++ "</h1>"
    ,"<p>todo</p>"
    ]
    where
        qstr = unwords $ names q ++
               ["::" | names q /= [] && isJust (typeSig q)] ++
               [showTagHTML (renderEntryText view $ renderTypeSig t) | Just t <- [typeSig q]]
        view = [ArgPosNum i i | i <- [0..10]]





a +? b = a ++ escapeHTML b


escapeHTML = concatMap f
    where
        f '\"' = "&quot;"
        f '<' = "&lt;"
        f '>' = "&gt;"
        f x = [x]


showTagHTML (Str x) = escapeHTML x
showTagHTML (Tags xs) = concatMap showTagHTML xs
showTagHTML (TagBold x) = "<b>" ++ showTagHTML x ++ "</b>"
showTagHTML (TagUnderline x) = "<i>" ++ showTagHTML x ++ "</i>"
showTagHTML (TagHyperlink url x) = "<a href=\"" +? url ++ "\">" ++ showTagHTML x ++ "</a>"
showTagHTML (TagColor i x) = "<span class='c" ++ show i ++ "'>" ++ showTagHTML x ++ "</span>"
