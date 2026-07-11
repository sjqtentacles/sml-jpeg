# sml-jpeg

[![CI](https://github.com/sjqtentacles/sml-jpeg/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-jpeg/actions/workflows/ci.yml)

JPEG **header / metadata** parsing for Standard ML by walking the marker
segments: detect the SOI, read image geometry and frame info, enumerate
segments, decode JFIF density, extract comments, and read EXIF orientation. This
is a metadata reader — it does **not** decode pixel data.

## API

```sml
val isJpeg         : Word8Vector.vector -> bool
val decodeBaseline : Word8Vector.vector -> int * int          (* raises on failure *)
val dimensions     : Word8Vector.vector -> (int * int) option

val frameInfo : Word8Vector.vector ->
  { width:int, height:int, precision:int, components:int
  , sofType:int, progressive:bool } option

type segment = { marker : int, offset : int, length : int }
val segments   : Word8Vector.vector -> segment list           (* up to SOS *)
val markerName : int -> string                                 (* 0xD8 -> "SOI" *)

val jfif    : Word8Vector.vector ->
  { version:int*int, units:int, xDensity:int, yDensity:int } option
val comment : Word8Vector.vector -> string option              (* first COM *)
val exifOrientation : Word8Vector.vector -> int option         (* 1..8, best-effort *)
```

## Examples

```sml
val (w, h) = Jpeg.decodeBaseline data        (* (320, 240) *)
val dim    = Jpeg.dimensions data            (* SOME (320, 240), NONE if invalid *)

val fi = valOf (Jpeg.frameInfo data)
(* { width=320, height=240, precision=8, components=3, sofType=0xC0, progressive=false } *)

(* enumerate the marker structure *)
List.map (fn s => Jpeg.markerName (#marker s)) (Jpeg.segments data)
(* ["SOI","APP0","SOF0","SOS"] *)

val Jpeg.jfif data            (* SOME { version=(1,1), units=1, xDensity=72, yDensity=72 } *)
val Jpeg.comment data         (* SOME "created by ..." | NONE *)
val Jpeg.exifOrientation data (* SOME 6 | NONE *)
```

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
builds a small synthetic in-memory JPEG (SOI, JFIF APP0, a comment, a
baseline SOF0, SOS, EOI) and walks its markers, dimensions, frame info, JFIF
density, and comment (output is byte-identical under MLton and Poly/ML):

```
isJpeg              = true
decodeBaseline      = 64 x 48
frameInfo           = precision 8, components 3, sofType 0xC0, progressive false
jfif                = version 1.1, units 1, 72x72 dpi
comment             = demo

segments up to SOS:
  SOI  offset=0  length=0
  APP0  offset=2  length=16
  COM  offset=20  length=6
  SOF0  offset=28  length=17
  SOS  offset=47  length=8

non-JPEG input:
  isJpeg              = false
  dimensions          = NONE
```

## Scope and limitations

- **No entropy/pixel decoding.** Huffman/quantization tables, DCT, and scan data
  are not interpreted — only header structure and metadata.
- `frameInfo` reads the first SOF marker; `progressive` is true for SOF2.
- `segments` stops at SOS (the entropy-coded scan data follows and is not
  segment-structured).
- `exifOrientation` is best-effort: it parses the APP1/Exif TIFF IFD0 for tag
  0x0112 (handles both `MM`/`II` byte orders) and returns `NONE` on anything
  unexpected. It does not chase sub-IFDs or MakerNotes.
- Input that is not a JPEG, or has no SOF, yields `NONE`/raises as documented.

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-jpeg
smlpkg sync
```

Reference from your `.mlb`:

```
lib/github.com/sjqtentacles/sml-jpeg/jpeg.mlb
```

## Building and testing

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make example     # build + run the demo
make clean
```

## Project layout

```
sml.pkg
Makefile
lib/github.com/sjqtentacles/sml-jpeg/
  jpeg.sig     JPEG signature
  jpeg.sml     marker walk: SOI/SOF/frameInfo/segments/JFIF/COM/EXIF
  jpeg.mlb
test/
  test.sml     dimensions, frameInfo SOF0/SOF2, segments, JFIF, comment, EXIF, errors
```

## License

MIT. See [LICENSE](LICENSE).
