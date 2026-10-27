# Decisions

A dated log of project decisions. Add new entries at the bottom; if a decision is reversed, add a
new entry rather than editing the old one.

| Date | Decision |
| --- | --- |
| 2026-10-27 | Stack is native **Swift + Metal + SwiftUI** (over Rust + wgpu and Python): best display handling and lowest idle cost next to QLab. |
| 2026-10-27 | Name is **Cuemodo Cyc**, repo `cuemodo/cyc`. Cuemodo is the umbrella brand for a family of show-control apps ("Cuemodo X"). |
| 2026-10-27 | License is MIT. Dependencies only under permissive licenses (MIT, BSD, Apache 2.0). |
| 2026-10-27 | Swift Package (`Package.swift`) instead of an Xcode project: readable diffs; Xcode opens it directly. A script will wrap the build into a .app when signing is needed. |
| 2026-10-27 | First show output: one 3840 x 1200 display (two WUXGA projectors through a Matrox splitter). A second output window is not needed for now. |
| 2026-10-27 | Overlap uses a **hard cut** (quads meet edge to edge); edge blending is a later option. |
| 2026-10-27 | Art-Net is the show protocol (Hog 4, or SmartFade ML through an Art-Net node). sACN comes after the show. |
| 2026-10-27 | Fixture modes: RGB 3ch, Dim + RGB 4ch, Gradient 6ch, Dim + Gradient 7ch; dimmer channel first. |
| 2026-10-27 | Gradient runs top to bottom for now; an angle channel is a later idea (roadmap step 15). |
| 2026-10-27 | The output window never takes focus by itself, so QLab keeps the keyboard. |
| 2026-10-27 | Art-Net universes are shown and stored as the raw 15-bit Port-Address, counted from 0 like Art-Net itself, with a "Net, Sub-Net, Universe" label beside it. |
| 2026-10-27 | The Art-Net listener uses plain BSD sockets with SO_REUSEADDR and SO_REUSEPORT so other Art-Net apps on the Mac can share port 6454. |
