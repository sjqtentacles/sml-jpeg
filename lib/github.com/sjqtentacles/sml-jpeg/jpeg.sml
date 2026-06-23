structure Jpeg :> JPEG =
struct
  fun byte v i = Word8.toInt (Word8Vector.sub (v, i))

  (* SOI marker FF D8 *)
  fun isJpeg v =
    Word8Vector.length v >= 2 andalso byte v 0 = 0xFF andalso byte v 1 = 0xD8

  (* Start-Of-Frame markers carry the image geometry.  All SOFn markers
     (C0-CF) except DHT(C4), JPG(C8) and DAC(CC) begin a frame header whose
     payload is: precision(1) height(2) width(2) ... *)
  fun isSOF m =
    m >= 0xC0 andalso m <= 0xCF andalso m <> 0xC4 andalso m <> 0xC8 andalso m <> 0xCC

  (* Markers with no length/payload: standalone RSTn (D0-D7), SOI(D8),
     EOI(D9), TEM(01). *)
  fun isStandalone m =
    (m >= 0xD0 andalso m <= 0xD9) orelse m = 0x01

  (* Scan the marker segments looking for the first SOF; return (width,height)
     read straight out of the frame header.  This parses real geometry from
     the header; it does NOT perform entropy/IDCT pixel decoding. *)
  fun decodeBaseline v =
    let
      val n = Word8Vector.length v
      val () = if isJpeg v then () else raise Fail "not a JPEG (missing SOI)"

      fun u16 i = byte v i * 256 + byte v (i + 1)

      (* i points at the 0xFF of a marker prefix *)
      fun scan i =
        if i + 1 >= n then raise Fail "no SOF marker found"
        else if byte v i <> 0xFF then scan (i + 1)   (* resync on fill bytes *)
        else
          let val m = byte v (i + 1)
          in
            if isSOF m then
              (* i+2..i+3 = segment length, i+4 = precision,
                 i+5..i+6 = height, i+7..i+8 = width *)
              if i + 8 < n then (u16 (i + 7), u16 (i + 5))
              else raise Fail "truncated SOF header"
            else if isStandalone m then scan (i + 2)
            else
              (* marker with a 2-byte length covering the length field itself *)
              let val len = u16 (i + 2)
              in if len < 2 then raise Fail "bad segment length"
                 else scan (i + 2 + len) end
          end
    in
      scan 2   (* skip the SOI we already validated *)
    end
end
