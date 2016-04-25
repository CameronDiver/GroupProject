module Emulator.Video.Util where

import Emulator.Memory
import Emulator.Types

import Control.Monad.IO.Class
import Data.Array.IArray
import Data.Array.Storable
import Data.Bits
import Graphics.Rendering.OpenGL

type AddressIO m = (AddressSpace m, MonadIO m)
type Palette = Array Address Byte
type PixFormat = Bool
type Tile = Array Address Byte
type TileOffset = (GLdouble, GLdouble)
type TileSet = Array Address Byte
type TileSetBaseAddress = Address

drawTile :: StorableArray Address HalfWord -> (GLdouble, GLdouble) -> (GLdouble, GLdouble) -> IO ()
drawTile arr (x1, x2) (y1, y2) = do
  _ <- liftIO $ loadTexture arr
  textureFilter Texture2D $= ((Nearest, Nothing), Nearest)
  renderPrimitive Quads $ do
    texCoord $ TexCoord2 0 (0 :: GLdouble)
    vertex $ Vertex2 x1 (y1 :: GLdouble)
    texCoord $ TexCoord2 1 (0 :: GLdouble)
    vertex $ Vertex2 x2 (y1 :: GLdouble)
    texCoord $ TexCoord2 1 (1 :: GLdouble)
    vertex $ Vertex2 x2 (y2 :: GLdouble)
    texCoord $ TexCoord2 0 (1 :: GLdouble)
    vertex $ Vertex2 x1 (y2 :: GLdouble)
  return ()

loadTexture :: StorableArray Address HalfWord -> IO TextureObject
loadTexture arr = withStorableArray arr $ \ptr -> do
    tile <- genObjectName
    textureBinding Texture2D $= Just tile
    texImage2D Texture2D NoProxy 0 RGBA' (TextureSize2D 8 8) 0 (PixelData RGB UnsignedByte ptr)
    return tile

bytesToHalfWord :: Byte -> Byte -> HalfWord
bytesToHalfWord lower upper = ((fromIntegral upper :: HalfWord) `shiftL` 8) .|. ((fromIntegral lower :: HalfWord) .&. 0xFF) :: HalfWord

-- If pixel format is 8bpp then the tileIndex read from the map is in steps of 40h
-- If pixel format is 4bpp then the tileIndex read from the map is in steps of 20h
convIntToAddr :: Int -> PixFormat -> Address
convIntToAddr 0 _ = 0x00000000
convIntToAddr n True = (0x00000040 * fromIntegral n)
convIntToAddr n _ = (0x00000020 * fromIntegral n)

-- If pixel format is 8bpp then TileSet is read in chunks of 40h
-- If not then TileSet is read in chunks of 20h
getTile :: PixFormat -> Address -> TileSet -> Tile
getTile True tileIdx tileSet = (ixmap (tileIdx, tileIdx + 0x0000003F) (id) tileSet :: Tile)
getTile _ tileIdx tileSet = (ixmap (tileIdx, tileIdx + 0x0000001F) (id) tileSet :: Tile)
