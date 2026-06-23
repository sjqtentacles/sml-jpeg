# sml-jpeg

[![CI](https://github.com/sjqtentacles/sml-jpeg/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-jpeg/actions/workflows/ci.yml)

JPEG **header** parsing for Standard ML: detect the JPEG SOI marker and read
image geometry (width/height) from the Start-of-Frame segment. This is a
header/metadata reader — it does **not** decode pixel data.

## What it does

- `isJpeg v` — true when the byte vector begins with the JPEG SOI marker
  (`FF D8`).
- `decodeBaseline v` — scans the marker segments, skipping length-prefixed
  segments, until it reaches a Start-of-Frame marker (`SOF0`/`SOF1`/`SOF2`/…)
  and returns the `(width, height)` encoded there.

```sml
Jpeg.isJpeg bytes                 (* true if FF D8 ... *)
val (w, h) = Jpeg.decodeBaseline bytes
```

## Scope and limitations

- **No entropy/pixel decoding.** Huffman tables, quantization tables, DCT and
  the scan data are not interpreted. Only the frame header geometry is read.
- Reads dimensions from the first SOF marker encountered (baseline or
  progressive). Arithmetic-coded and hierarchical variants are not special-cased.
- Input that is not a JPEG, or a JPEG with no SOF segment, yields no dimensions
  (the scan reaches end-of-input).

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
make clean
```

## Project layout

```
sml.pkg
Makefile
lib/github.com/sjqtentacles/sml-jpeg/
  jpeg.sig     JPEG signature
  jpeg.sml     SOI detection + SOF geometry parser
  jpeg.mlb
test/
  test.sml     SOI detection, SOF0/SOF2 geometry, error paths
```

## License

MIT. See [LICENSE](LICENSE).
