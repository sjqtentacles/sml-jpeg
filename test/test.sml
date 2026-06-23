structure Tests = struct open Harness structure J = Jpeg
fun bytes ws = Word8Vector.fromList (List.map Word8.fromInt ws)

fun run () = let
  val () = section "SOI detection"
  val () = checkBool "FF D8 is jpeg"     (true,  J.isJpeg (bytes [0xFF,0xD8,0x00]))
  val () = checkBool "PNG is not jpeg"   (false, J.isJpeg (bytes [0x89,0x50,0x4E,0x47]))
  val () = checkBool "too short"         (false, J.isJpeg (bytes [0xFF]))

  (* A minimal but real JPEG marker stream:
       SOI                         FF D8
       APP0 (len 16, 14 payload)   FF E0 00 10 [14 bytes]
       SOF0 (len 17)               FF C0 00 11
         precision 8               08
         height  = 0x00F0 = 240    00 F0
         width   = 0x0140 = 320    01 40
         3 components              03  [9 bytes]
       EOI                         FF D9
     decodeBaseline must skip APP0 by its length and read (320, 240). *)
  val app0 = [0xFF,0xE0,0x00,0x10] @ List.tabulate (14, fn _ => 0x00)
  val sof0 = [0xFF,0xC0,0x00,0x11, 0x08, 0x00,0xF0, 0x01,0x40, 0x03]
             @ [0x01,0x22,0x00, 0x02,0x11,0x01, 0x03,0x11,0x01]
  val img  = bytes ([0xFF,0xD8] @ app0 @ sof0 @ [0xFF,0xD9])

  val () = section "SOF0 geometry parse"
  val (w, h) = J.decodeBaseline img
  val () = checkInt "width 320"  (320, w)
  val () = checkInt "height 240" (240, h)

  (* Different dimensions, and SOF2 (progressive) marker, with no APP0 *)
  val sof2 = bytes ([0xFF,0xD8] @
                    [0xFF,0xC2,0x00,0x11, 0x08, 0x00,0x40, 0x00,0x80, 0x03]
                    @ [0x01,0x22,0x00, 0x02,0x11,0x01, 0x03,0x11,0x01]
                    @ [0xFF,0xD9])
  val (w2, h2) = J.decodeBaseline sof2
  val () = checkInt "SOF2 width 128"  (128, w2)
  val () = checkInt "SOF2 height 64"  (64,  h2)

  val () = section "error paths"
  val () = checkRaises "non-jpeg raises" (fn () => J.decodeBaseline (bytes [0x00,0x01,0x02]))
  val () = checkRaises "jpeg without SOF raises"
             (fn () => J.decodeBaseline (bytes [0xFF,0xD8,0xFF,0xD9]))
in Harness.run () end end
