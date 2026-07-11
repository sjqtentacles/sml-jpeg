(* demo.sml - parse a small synthetic in-memory JPEG byte stream (SOI, JFIF
   APP0, a comment, a baseline SOF0, SOS, EOI) and walk its markers,
   dimensions, JFIF density, and comment. Deterministic: identical output on
   every run and both compilers; no file I/O. *)

structure J = Jpeg

fun bytes ws = Word8Vector.fromList (List.map Word8.fromInt ws)

(* JFIF APP0: ident "JFIF\0", version 1.1, units=1 (dpi), x=72, y=72 *)
val app0 = [0xFF,0xE0,0x00,0x10]
           @ [0x4A,0x46,0x49,0x46,0x00]
           @ [0x01,0x01]
           @ [0x01]
           @ [0x00,0x48, 0x00,0x48]
           @ [0x00,0x00]

(* a COM comment segment: "demo" *)
val com = [0xFF,0xFE,0x00,0x06] @ List.map Char.ord (String.explode "demo")

(* baseline SOF0: precision 8, 64 x 48, 3 components (YCbCr) *)
val sof0 = [0xFF,0xC0,0x00,0x11, 0x08, 0x00,0x30, 0x00,0x40, 0x03]
           @ [0x01,0x22,0x00, 0x02,0x11,0x01, 0x03,0x11,0x01]

val sos = [0xFF,0xDA,0x00,0x08, 0x01,0x01,0x00,0x00,0x3F,0x00]

val img = bytes ([0xFF,0xD8] @ app0 @ com @ sof0 @ sos @ [0xFF,0xD9])

val () = print ("isJpeg              = " ^ Bool.toString (J.isJpeg img) ^ "\n")

val (w, h) = J.decodeBaseline img
val () = print ("decodeBaseline      = " ^ Int.toString w ^ " x " ^ Int.toString h ^ "\n")

val fi = valOf (J.frameInfo img)
val () = print ("frameInfo           = precision " ^ Int.toString (#precision fi)
                ^ ", components " ^ Int.toString (#components fi)
                ^ ", sofType 0x" ^ Int.fmt StringCvt.HEX (#sofType fi)
                ^ ", progressive " ^ Bool.toString (#progressive fi) ^ "\n")

val jf = valOf (J.jfif img)
val () = print ("jfif                = version " ^ Int.toString (#1 (#version jf)) ^ "."
                ^ Int.toString (#2 (#version jf))
                ^ ", units " ^ Int.toString (#units jf)
                ^ ", " ^ Int.toString (#xDensity jf) ^ "x" ^ Int.toString (#yDensity jf) ^ " dpi\n")

val () = print ("comment             = " ^ valOf (J.comment img) ^ "\n")

val () = print "\nsegments up to SOS:\n"
val segs = J.segments img
val () =
  List.app
    (fn { marker, offset, length } =>
      print ("  " ^ J.markerName marker
             ^ "  offset=" ^ Int.toString offset
             ^ "  length=" ^ Int.toString length ^ "\n"))
    segs

val () = print "\nnon-JPEG input:\n"
val notJpeg = bytes [0x89,0x50,0x4E,0x47]
val () = print ("  isJpeg              = " ^ Bool.toString (J.isJpeg notJpeg) ^ "\n")
val () = print ("  dimensions          = "
                ^ (case J.dimensions notJpeg of
                     NONE => "NONE"
                   | SOME (w, h) => Int.toString w ^ " x " ^ Int.toString h)
                ^ "\n")
