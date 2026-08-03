# Card-face font provenance

The complete-card pipeline uses `Noto Sans SC` only as a build-time source. The
Python step uses the exact font file for metrics; the Windows `System.Drawing`
step resolves the installed `Noto Sans SC` family and converts visible copy to
glyph outlines. The full font file is not copied into this repository or loaded
by the game at runtime.

- Family: Noto Sans SC
- Style: Regular, variable TrueType source
- Version: `2.04;241114210130;non-release`
- Source file used on the build machine: `C:\Windows\Fonts\NotoSansSC-VF.ttf`
- SHA-256: `763146584cf0710223441356b4395e279021b0806c196614377a7a0174ae074a`
- Copyright metadata: `© 2014-2021 Adobe, with Reserved Font Name 'Source'.`
- License metadata: SIL Open Font License, Version 1.1
- License URL from the font metadata: <http://scripts.sil.org/OFL>

Regeneration on another machine should use the same font version and verify the
hash above. A different font or version may change glyph geometry even when the
visible copy is unchanged.
