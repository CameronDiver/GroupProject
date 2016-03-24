module Emulator.Memory where

import Emulator.Memory.AddressSpace
import Emulator.Memory.Regions
import Emulator.Types

import Data.Proxy

type AddressSpace m =
  ( Functor m, Monad m
  , CanRead WRAM m, CanWrite WRAM m
  , CanRead ROM m
  , CanRead OAM m, CanWrite OAM m
  , CanRead VRAM m, CanWrite VRAM m )

writeAddressHalfWord :: AddressSpace m => Address -> HalfWord -> m ()
writeAddressHalfWord addr hw =
  case addressToRegionType addr of
    (_, BIOS) -> return ()
    (_, WRAM) -> writeHalfWord (Proxy :: Proxy WRAM) addr hw
    (_, VRAM) -> writeHalfWord (Proxy :: Proxy VRAM) addr hw
    (_, ObjAttributes) -> writeHalfWord (Proxy :: Proxy OAM) addr hw
    (_, Unused) -> return ()
    (_, r) -> error $ "writeAddress: unhandled region type: " ++ show r

readAddressHalfWord :: AddressSpace m => Address -> m HalfWord
readAddressHalfWord addr =
  case addressToRegionType addr of
    (_, BIOS) -> return 0
    (_, WRAM) -> readHalfWord (Proxy :: Proxy WRAM) addr
    (_, VRAM) -> readHalfWord (Proxy :: Proxy VRAM) addr
    (_, ObjAttributes) -> readHalfWord (Proxy :: Proxy OAM) addr
    (_, Unused) -> return 0
    (_, r) -> error $ "writeAddress: unhandled region type: " ++ show r

writeAddressWord :: AddressSpace m => Address -> MWord -> m ()
writeAddressWord addr hw =
  case addressToRegionType addr of
    (_, WRAM) -> writeWord (Proxy :: Proxy WRAM) addr hw
    (_, r) -> error $ "writeAddress: unhandled region type: " ++ show r

readAddressWord :: AddressSpace m => Address -> m MWord
readAddressWord addr =
  case addressToRegionType addr of
    (off, WRAM) -> readWord (Proxy :: Proxy WRAM) addr
    (off, GamePakROM) -> readWord (Proxy :: Proxy ROM) addr
    (_, r) -> error $ "writeAddress: unhandled region type: " ++ show r

