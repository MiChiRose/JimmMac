# libwebp decoder

Original decoder sources from [libwebp 1.6.0](https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz), SHA-256
`e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564`.

The decoder sources follow the `dec`, `dsp` and `utils` lists in the
upstream Makefiles. The local empty configuration selects portable C.
JimmMac uses the decoder for photo previews on systems without WebP in ImageIO.
See [COPYING](COPYING) and [PATENTS](PATENTS).
