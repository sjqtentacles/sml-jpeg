signature JPEG =
sig
  (* True when the data starts with the SOI marker FF D8. *)
  val isJpeg : Word8Vector.vector -> bool

  (* (width, height) from the first SOF marker. Raises Fail on non-JPEG or no
     SOF. Kept for backward compatibility. *)
  val decodeBaseline : Word8Vector.vector -> int * int

  (* (width, height) as an option (NONE instead of raising). *)
  val dimensions : Word8Vector.vector -> (int * int) option

  (* Frame information from the first Start-Of-Frame marker. *)
  val frameInfo : Word8Vector.vector ->
    { width : int, height : int
    , precision : int            (* bits per sample, usually 8 *)
    , components : int           (* 1=grayscale, 3=YCbCr, 4=CMYK *)
    , sofType : int              (* the SOF marker byte, e.g. 0xC0 *)
    , progressive : bool }       (* true for SOF2 *)
    option

  (* A parsed marker segment: marker byte, file offset of the 0xFF prefix, and
     the payload length (0 for standalone markers like SOI/EOI/RSTn). *)
  type segment = { marker : int, offset : int, length : int }

  (* Enumerate all marker segments up to (and including) SOS. *)
  val segments   : Word8Vector.vector -> segment list
  (* Human-readable name for a marker byte (e.g. 0xD8 -> "SOI"). *)
  val markerName : int -> string

  (* JFIF APP0 density info. *)
  val jfif : Word8Vector.vector ->
    { version : int * int        (* (major, minor) *)
    , units : int                (* 0=aspect, 1=dpi, 2=dpcm *)
    , xDensity : int, yDensity : int }
    option

  (* The first JPEG comment (COM marker) as a string, if present. *)
  val comment : Word8Vector.vector -> string option

  (* Best-effort EXIF orientation (1..8) from an APP1/Exif segment, if present. *)
  val exifOrientation : Word8Vector.vector -> int option
end
