structure Tests = struct open Harness structure J = Jpeg
fun bytes ws = Word8Vector.fromList (List.map Word8.fromInt ws)

fun run () = let
  val () = section "SOI detection"
  val () = checkBool "FF D8 is jpeg"     (true,  J.isJpeg (bytes [0xFF,0xD8,0x00]))
  val () = checkBool "PNG is not jpeg"   (false, J.isJpeg (bytes [0x89,0x50,0x4E,0x47]))
  val () = checkBool "too short"         (false, J.isJpeg (bytes [0xFF]))

  (* JFIF APP0: ident "JFIF\0" version 1.1 units=1(dpi) x=72 y=72 *)
  val app0 = [0xFF,0xE0,0x00,0x10]
             @ [0x4A,0x46,0x49,0x46,0x00]   (* "JFIF\0" *)
             @ [0x01,0x01]                   (* version 1.1 *)
             @ [0x01]                        (* units = dpi *)
             @ [0x00,0x48, 0x00,0x48]        (* x=72, y=72 *)
             @ [0x00,0x00]                   (* thumbnail 0x0 *)
  val sof0 = [0xFF,0xC0,0x00,0x11, 0x08, 0x00,0xF0, 0x01,0x40, 0x03]
             @ [0x01,0x22,0x00, 0x02,0x11,0x01, 0x03,0x11,0x01]
  val sos  = [0xFF,0xDA,0x00,0x08, 0x01,0x01,0x00,0x00,0x3F,0x00]
  val img  = bytes ([0xFF,0xD8] @ app0 @ sof0 @ sos @ [0xFF,0xD9])

  val () = section "decodeBaseline + dimensions"
  val (w, h) = J.decodeBaseline img
  val () = checkInt "width 320"  (320, w)
  val () = checkInt "height 240" (240, h)
  val () = checkBool "dimensions SOME" (true, J.dimensions img = SOME (320, 240))
  val () = checkBool "dimensions of garbage = NONE"
             (true, J.dimensions (bytes [0x00,0x01]) = NONE)

  val () = section "frameInfo SOF0 (baseline)"
  val fi = J.frameInfo img
  val () = checkBool "frameInfo SOME" (true, Option.isSome fi)
  val fiv = valOf fi
  val () = checkInt "precision 8" (8, #precision fiv)
  val () = checkInt "components 3" (3, #components fiv)
  val () = checkInt "sofType 0xC0" (0xC0, #sofType fiv)
  val () = checkBool "not progressive" (false, #progressive fiv)
  val () = checkInt "fi width" (320, #width fiv)

  val () = section "frameInfo SOF2 (progressive)"
  val sof2img = bytes ([0xFF,0xD8] @
                  [0xFF,0xC2,0x00,0x11, 0x08, 0x00,0x40, 0x00,0x80, 0x01]
                  @ [0x01,0x22,0x00, 0x02,0x11,0x01, 0x03,0x11,0x01]
                  @ [0xFF,0xD9])
  val fi2 = valOf (J.frameInfo sof2img)
  val () = checkInt "SOF2 width 128" (128, #width fi2)
  val () = checkInt "SOF2 height 64" (64, #height fi2)
  val () = checkInt "SOF2 sofType 0xC2" (0xC2, #sofType fi2)
  val () = checkBool "SOF2 progressive" (true, #progressive fi2)
  val () = checkInt "SOF2 grayscale 1 comp" (1, #components fi2)

  val () = section "segments enumeration"
  val segs = J.segments img
  val markers = List.map #marker segs
  val () = checkBool "starts with SOI" (true, List.hd markers = 0xD8)
  val () = checkBool "contains APP0" (true, List.exists (fn m => m = 0xE0) markers)
  val () = checkBool "contains SOF0" (true, List.exists (fn m => m = 0xC0) markers)
  val () = checkBool "contains SOS" (true, List.exists (fn m => m = 0xDA) markers)
  val () = checkBool "stops at SOS (last is SOS)" (true, #marker (List.last segs) = 0xDA)

  val () = section "markerName"
  val () = checkString "SOI" ("SOI", J.markerName 0xD8)
  val () = checkString "APP0" ("APP0", J.markerName 0xE0)
  val () = checkString "SOF0" ("SOF0", J.markerName 0xC0)
  val () = checkString "DQT" ("DQT", J.markerName 0xDB)
  val () = checkString "COM" ("COM", J.markerName 0xFE)

  val () = section "JFIF density/units"
  val jf = J.jfif img
  val () = checkBool "jfif SOME" (true, Option.isSome jf)
  val jfv = valOf jf
  val () = checkInt "version major 1" (1, #1 (#version jfv))
  val () = checkInt "version minor 1" (1, #2 (#version jfv))
  val () = checkInt "units dpi" (1, #units jfv)
  val () = checkInt "xDensity 72" (72, #xDensity jfv)
  val () = checkInt "yDensity 72" (72, #yDensity jfv)
  val () = checkBool "no JFIF -> NONE" (true, J.jfif sof2img = NONE)

  val () = section "comment (COM)"
  val com = [0xFF,0xFE,0x00,0x05] @ List.map Char.ord (String.explode "hey")
  val comImg = bytes ([0xFF,0xD8] @ app0 @ com @ sof0 @ sos @ [0xFF,0xD9])
  val () = checkBool "comment found" (true, J.comment comImg = SOME "hey")
  val () = checkBool "no comment -> NONE" (true, J.comment img = NONE)

  val () = section "EXIF orientation (best-effort)"
  (* APP1 Exif, big-endian TIFF, IFD0 with one tag 0x0112 (orientation) = 6 *)
  val tiff = [0x4D,0x4D, 0x00,0x2A, 0x00,0x00,0x00,0x08]   (* MM, 0x002A, IFD@8 *)
             @ [0x00,0x01]                                  (* 1 entry *)
             @ [0x01,0x12, 0x00,0x03, 0x00,0x00,0x00,0x01,  (* tag, type SHORT, count 1 *)
                0x00,0x06, 0x00,0x00]                        (* value 6 *)
             @ [0x00,0x00,0x00,0x00]                         (* next IFD = 0 *)
  val exifPayload = [0x45,0x78,0x69,0x66,0x00,0x00] @ tiff   (* "Exif\0\0" + TIFF *)
  val exifLen = 2 + List.length exifPayload
  val app1 = [0xFF,0xE1, (exifLen div 256) mod 256, exifLen mod 256] @ exifPayload
  val exifImg = bytes ([0xFF,0xD8] @ app1 @ sof0 @ sos @ [0xFF,0xD9])
  val () = checkBool "orientation = 6" (true, J.exifOrientation exifImg = SOME 6)
  val () = checkBool "no exif -> NONE" (true, J.exifOrientation img = NONE)

  val () = section "error paths"
  val () = checkRaises "non-jpeg raises" (fn () => J.decodeBaseline (bytes [0x00,0x01,0x02]))
  val () = checkRaises "jpeg without SOF raises"
             (fn () => J.decodeBaseline (bytes [0xFF,0xD8,0xFF,0xD9]))

in Harness.run () end end
