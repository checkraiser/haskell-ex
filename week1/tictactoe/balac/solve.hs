import Control.Monad
import System.Random
import System.IO
import Data.Array
import Data.List
import Data.Char
import Data.Maybe
import Data.Function
import System.Console.ANSI
import Text.Read

data Label = FREE | O | X
    deriving ( Eq, Show, Enum, Bounded )

type Size = (Int, Int)

type Board = Array Size Label

type Pos = (Int, Int)

type Move = (Pos, Label)

type Turn = Board -> Label -> IO Board

type ScoredBoard = (Int, Board)

data MinimaxTurn = MAX | MIN

data BoardStatus = WIN | DRAW | PLAY

other :: Label -> Label
other O = X
other X = O
other FREE = FREE

bSize = 3

emptyBoard :: Board
emptyBoard = array boardRange [ ( idx, FREE ) | idx <- range boardRange ]
    where
        boardRange = ( ( 1, 1 ), ( bSize, bSize ) )

showBoard :: Board -> String
showBoard board = unlines $ headerRows ++ intersperse sepRow ( map showRow rows ) ++ [ footerRow ]
    where
        headerRows= [ xLabelRow, topBoxRow ]
        xLabelRow = "  " ++ intersperse ' ' ( take bSize [ 'A'..'Z' ] )
        topBoxRow = borderRow '┌' '┬' '┐'
        sepRow    = borderRow '├' '┼' '┤'
        footerRow = borderRow '└' '┴' '┘'
        borderRow start middle end = [ ' ', start ] ++ intersperse middle ( replicate bSize '─' ) ++ [ end ]
        showRow ( rowIdx, rowData ) = show rowIdx ++ ( '│' : intersperse '│' ( map lookupLabel rowData ) ++ ['│'] )
        rows = map (\i -> ( i, [ board ! (i,j) | j <- [1..bSize] ] ) ) [1..bSize]
        lookupLabel label = case label of
                                FREE -> ' '
                                O    -> 'O'
                                X    -> 'X'

printBoard :: Board -> IO ()
printBoard board = do
    let string = showBoard board
    printBoard' string
    where
        printBoard' :: String -> IO ()
        printBoard' []       = return ()
        printBoard' ('X':xs) = printChar 'X' Green >> printBoard' xs
        printBoard' ('O':xs) = printChar 'O' Red >> printBoard' xs
        printBoard' (x:xs)   = printChar x White >> printBoard' xs
        printChar char color = setSGR [SetColor Foreground Vivid color] >> putStr [char] >> setSGR [Reset]

strToPos :: String -> Maybe Pos
strToPos str = do
    guard $ length str' >= 2
    row <- getRow
    col <- getCol
    guard $ all ( \x -> x > 0 && x <= bSize ) [ row, col ]
    return (row, col)
    where
        str'   = trim $ map toLower str
        trim   = unwords . words
        getCol = Just ( ord ( head str' ) - 96 )
        rowStr = tail str'
        getRow = readMaybe rowStr

applyMove :: Board -> Move -> Board
applyMove board move = board // [ move ]

humanTurn :: Turn
humanTurn board label = do
    putStr "Your move:\n> "
    moveStr <- getLine
    case strToPos moveStr of
        Nothing -> humanTurn board label
        Just pos -> if board ! pos == FREE
                        then return $ applyMove board ( pos, label )
                        else do
                            putStrLn "This cell is already taken!" 
                            humanTurn board label

winVectors :: [ [ Pos ] ]
winVectors = rows ++ cols ++ diagonals
    where
        idxs = [1..bSize]
        rows = map (\row -> map (\col -> ( row, col ) ) idxs ) idxs
        cols = map (\col -> map (\row -> ( row, col ) ) idxs ) idxs
        diagonals = [ map (\idx -> (idx, idx) ) idxs, zip idxs $ reverse idxs ] 


getWinner :: Board -> Maybe Label
getWinner board 
    | null winningVectors = Nothing
    | otherwise           = Just ( board ! ( head . head $ winningVectors ) )
    where
        winningVectors = filter isWinning winVectors
        isWinning vec = case uniq of
            [FREE]  -> False
            [_]     -> True
            _       -> False
            where
                uniq = nub $ map ( board ! ) vec

        
minimax :: Label -> Label -> Board -> ScoredBoard
minimax topLabel curLabel board
    | hasWon    = if isTopWinning then ( 1, board ) else ( -1, board )
    | isDraw    = ( 0, board )
    | otherwise = head sortedBoards
    where
        hasWon          = isJust posWinner
        posWinner       = getWinner board
        winLabel        = fromJust posWinner
        isTopWinning    = winLabel == topLabel
        isDraw          = null availMoves
        availMoves      = [ ( pos, curLabel ) | ( pos, l ) <- assocs board, l == FREE ]
        availBoards     = map ( applyMove board ) availMoves
        scoredBoards'   = map ( minimax topLabel $ other curLabel ) availBoards
        scoredBoards    = zipWith ( \( score, _ ) board -> (score, board) ) scoredBoards' availBoards
        minSort         = sortBy ( compare `on` fst ) scoredBoards
        maxSort         = reverse minSort
        sortedBoards    = if topLabel == curLabel then maxSort else minSort

minimaxTurn :: Turn
minimaxTurn board label = return $ snd $ minimax label label board

winGame :: Board -> IO ()
winGame board = do
    printBoard board
    putStrLn $ ( "Match Won by " ++ ) $ show . fromJust . getWinner $ board

drawGame :: Board -> IO ()
drawGame board = do
    printBoard board
    putStrLn "Match Drawn" 

isDrawn :: Board -> Bool
isDrawn = notElem FREE . elems

hasWon :: Board -> Bool
hasWon = isJust . getWinner

boardStatus :: Board -> BoardStatus
boardStatus board
    | isDrawn board = DRAW
    | hasWon board  = WIN
    | otherwise     = PLAY

play :: Board -> Label -> Turn -> Turn -> IO ()
play board label turn1 turn2 = do
    printBoard board
    newBoard <- turn1 board label
    case boardStatus newBoard of
        WIN  -> winGame newBoard
        DRAW -> drawGame newBoard
        PLAY -> play newBoard ( other label ) turn2 turn1

main :: IO ()
main = do
    hSetEncoding stdout utf8
    hSetBuffering stdout NoBuffering
    putStrLn "Who goes first (human/computer)?"
    opt <- map toLower <$> getLine
    if opt == "h"
        then play emptyBoard X humanTurn minimaxTurn
        else play emptyBoard X minimaxTurn humanTurn