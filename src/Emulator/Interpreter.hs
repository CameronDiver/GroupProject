module Emulator.Interpreter where

import Emulator.CPU hiding (System)
import Emulator.CPU.Instructions.Parser
import Emulator.Memory
import Emulator.Memory.RAM
import Utilities.Show

import Control.Lens
import Control.Monad
import Control.Monad.Trans.Class
import Control.Monad.Trans.State
import Data.Array.Unboxed
import Data.ByteString.Lazy (ByteString)
import Data.Default.Class
import Emulator.Types
import qualified Data.ByteString.Lazy as BS

data SystemState =
  SystemState { _systemStateSysRegisters :: Registers
              , _systemStateSysROM :: Memory
              , _systemStateSysRAM :: Memory }
  deriving (Show, Eq)

makeFields ''SystemState

buildInitialState :: ByteString -> SystemState
buildInitialState bs =
  SystemState (def & r15 .~ 0x08000000) romArray initialRAM
    where
      initialRAM = accumArray const 0 (0x02000000, 0x0203FFFF) []
      -- not totally sure that this is producing the correct output
      romArray = accumArray (flip const) 0 (0x08000000, 0x0DFFFFFF) $ zip [0x8000000..] $ BS.unpack bs

instance HasRegisters SystemState where
  registers = sysRegisters

newtype System m a =
  System { runSystem :: StateT SystemState m a }
  deriving (Functor, Applicative, Monad)

instance Monad m => Mem (System m) where
  writeByte a b = System $ zoom sysRAM $ modify (// [(a, b)])
  readByte a = System $ zoom sysRAM $ gets (! a)

interpretLoop :: Monad m => System m ()
interpretLoop = do
  forever $ do
    -- this is super wrong. it's reading from RAM when it should be consulting the regions
    --   lookup table and finding where the memory address is actually stored. for now, we
    --   will just error instead of trying to run this nonsense.
    pc <- System (use (sysRegisters.r15))
    _ <- error $ "interpretLoop: program counter says " ++ showHex pc
    newInstr <- System (use (sysRegisters.r15)) >>= readWordLE
    case parseARM newInstr of
      Left err -> error $ "interpretLoop: instruction parse failed (" ++ err ++ ")"
      Right (cond, instr) ->
        error $ "interpretLoop: unimplemented condition handling (" ++ show instr ++ ")"

interpretARM :: Monad m => Instruction ARM -> System m ()
interpretARM instr =
  case instr of
    Branch (Link l) offset -> do
      -- if the link bit is set, we put the current pc into r14
      when l $ System $ sysRegisters.r14 <~ use (sysRegisters.r15)
      -- not totally sure how prefetch interacts with this
      System $ sysRegisters.r15 %= \x -> fromIntegral (fromIntegral x + offset)
    DataProcessing _ _ _ _ _ ->
      error "interpretARM: undefined data processing instruction handler"
    _ -> error "interpretARM: unknown instruction"
