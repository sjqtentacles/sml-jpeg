structure Jpeg :> JPEG =
struct
  fun byte v i = Word8.toInt (Word8Vector.sub (v, i))

  fun isJpeg v =
    Word8Vector.length v >= 2 andalso byte v 0 = 0xFF andalso byte v 1 = 0xD8

  fun isSOF m =
    m >= 0xC0 andalso m <= 0xCF andalso m <> 0xC4 andalso m <> 0xC8 andalso m <> 0xCC

  fun isStandalone m =
    (m >= 0xD0 andalso m <= 0xD9) orelse m = 0x01

  type segment = { marker : int, offset : int, length : int }

  fun markerName m =
    if m >= 0xD0 andalso m <= 0xD7 then "RST" ^ Int.toString (m - 0xD0)
    else if m >= 0xE0 andalso m <= 0xEF then "APP" ^ Int.toString (m - 0xE0)
    else if isSOF m then "SOF" ^ Int.toString (m - 0xC0)
    else case m of
        0xD8 => "SOI" | 0xD9 => "EOI" | 0xC4 => "DHT" | 0xCC => "DAC"
      | 0xDB => "DQT" | 0xDD => "DRI" | 0xDA => "SOS" | 0xFE => "COM"
      | 0x01 => "TEM" | _ => "0x" ^ Int.fmt StringCvt.HEX m

  (* ---- core marker walk ---- *)

  fun decodeBaseline v =
    let
      val n = Word8Vector.length v
      val () = if isJpeg v then () else raise Fail "not a JPEG (missing SOI)"
      fun u16 i = byte v i * 256 + byte v (i + 1)
      fun scan i =
        if i + 1 >= n then raise Fail "no SOF marker found"
        else if byte v i <> 0xFF then scan (i + 1)
        else
          let val m = byte v (i + 1)
          in
            if isSOF m then
              if i + 8 < n then (u16 (i + 7), u16 (i + 5))
              else raise Fail "truncated SOF header"
            else if isStandalone m then scan (i + 2)
            else
              let val len = u16 (i + 2)
              in if len < 2 then raise Fail "bad segment length"
                 else scan (i + 2 + len) end
          end
    in scan 2 end

  fun dimensions v = SOME (decodeBaseline v) handle _ => NONE

  fun frameInfo v =
    let
      val n = Word8Vector.length v
      fun u16 i = byte v i * 256 + byte v (i + 1)
      fun scan i =
        if i + 1 >= n then NONE
        else if byte v i <> 0xFF then scan (i + 1)
        else
          let val m = byte v (i + 1)
          in
            if isSOF m then
              if i + 9 < n then
                SOME { precision = byte v (i + 4)
                     , height = u16 (i + 5)
                     , width = u16 (i + 7)
                     , components = byte v (i + 9)
                     , sofType = m
                     , progressive = (m = 0xC2) }
              else NONE
            else if isStandalone m then scan (i + 2)
            else if i + 3 >= n then NONE
            else
              let val len = u16 (i + 2)
              in if len < 2 then NONE else scan (i + 2 + len) end
          end
    in
      if isJpeg v then scan 2 else NONE
    end

  (* enumerate segments up to and including SOS (or EOI) *)
  fun segments v =
    let
      val n = Word8Vector.length v
      fun u16 i = byte v i * 256 + byte v (i + 1)
      fun scan (i, acc) =
        if i + 1 >= n then List.rev acc
        else if byte v i <> 0xFF then scan (i + 1, acc)
        else
          let val m = byte v (i + 1)
          in
            if isStandalone m then
              let val seg = { marker = m, offset = i, length = 0 }
              in if m = 0xD9 then List.rev (seg :: acc)   (* EOI ends *)
                 else scan (i + 2, seg :: acc)
              end
            else if i + 3 >= n then List.rev acc
            else
              let
                val len = u16 (i + 2)
                val seg = { marker = m, offset = i, length = len }
              in
                if m = 0xDA then List.rev (seg :: acc)     (* SOS: stop, scan data follows *)
                else if len < 2 then List.rev (seg :: acc)
                else scan (i + 2 + len, seg :: acc)
              end
          end
    in
      if isJpeg v then scan (2, [ { marker = 0xD8, offset = 0, length = 0 } ])
      else []
    end

  (* ---- JFIF ---- *)

  fun findSegment v wanted =
    List.find (fn (s : segment) => #marker s = wanted) (segments v)

  fun jfif v =
    case findSegment v 0xE0 of
        NONE => NONE
      | SOME { offset, length, ... } =>
          let
            val d = offset + 4   (* payload start *)
            (* "JFIF\0" identifier (5 bytes) then version(2) units(1) x(2) y(2) *)
            val ident = String.implode (List.tabulate (4, fn j => Char.chr (byte v (d + j))))
          in
            if length >= 14 andalso ident = "JFIF" then
              SOME { version = (byte v (d + 5), byte v (d + 6))
                   , units = byte v (d + 7)
                   , xDensity = byte v (d + 8) * 256 + byte v (d + 9)
                   , yDensity = byte v (d + 10) * 256 + byte v (d + 11) }
            else NONE
          end

  fun comment v =
    case findSegment v 0xFE of
        NONE => NONE
      | SOME { offset, length, ... } =>
          let val payloadLen = length - 2
              val d = offset + 4
          in SOME (String.implode (List.tabulate (payloadLen, fn j => Char.chr (byte v (d + j))))) end

  (* ---- EXIF orientation (best effort) ---- *)

  fun exifOrientation v =
    case findSegment v 0xE1 of
        NONE => NONE
      | SOME { offset, length, ... } =>
          let
            val d = offset + 4
            val ident = String.implode (List.tabulate (4, fn j => Char.chr (byte v (d + j))))
          in
            if length < 16 orelse ident <> "Exif" then NONE
            else
              let
                val tiff = d + 6   (* after "Exif\0\0" *)
                val bigEndian = byte v tiff = 0x4D  (* 'M' = MM big-endian *)
                fun rd16 i =
                  if bigEndian then byte v i * 256 + byte v (i + 1)
                  else byte v (i + 1) * 256 + byte v i
                fun rd32 i =
                  if bigEndian then
                    ((byte v i * 256 + byte v (i+1)) * 256 + byte v (i+2)) * 256 + byte v (i+3)
                  else
                    ((byte v (i+3) * 256 + byte v (i+2)) * 256 + byte v (i+1)) * 256 + byte v i
                val ifdOff = tiff + rd32 (tiff + 4)
                val count = rd16 ifdOff
                (* walk IFD0 entries (12 bytes each) looking for tag 0x0112 *)
                fun findTag k =
                  if k >= count then NONE
                  else
                    let val e = ifdOff + 2 + k * 12
                        val tag = rd16 e
                    in if tag = 0x0112 then SOME (rd16 (e + 8)) else findTag (k + 1) end
              in
                findTag 0 handle _ => NONE
              end
          end
end
