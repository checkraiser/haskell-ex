import System.IO
import System.Environment
import System.Directory
import Data.Bits
import qualified Data.Text as T
import Data.Text.Encoding
import qualified Data.ByteString.Lazy as BS

encrypt :: BS.ByteString -> BS.ByteString -> BS.ByteString
encrypt txt key = BS.pack $ BS.zipWith xor txt rollingKey
  where
    rollingKey = BS.cycle key

main :: IO ()
main = do
  [fileName, key] <- getArgs
  handle <- openBinaryFile fileName ReadMode
  contents <- BS.hGetContents handle

  (tempName, tempHandle) <- openBinaryTempFile "." "temp"
  
  BS.hPut tempHandle $ encrypt contents $ (BS.fromStrict . encodeUtf8 . T.pack) key

  hClose handle
  hClose tempHandle

  renameFile tempName fileName
