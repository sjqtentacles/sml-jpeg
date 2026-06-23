signature JPEG =
sig
  val isJpeg : Word8Vector.vector -> bool
  val decodeBaseline : Word8Vector.vector -> int * int
end
