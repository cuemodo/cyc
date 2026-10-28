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
| 2026-10-27 | Shaders live in a Swift string and are compiled when the output opens, so `swift build` works without Xcode's Metal build step. |
| 2026-10-27 | The output follows every Art-Net packet straight away (no throttling); only the settings window refreshes at 10 Hz. |
| 2026-10-27 | Dim + Gradient is 8 channels, one dimmer per color (top DRGB, bottom DRGB), replacing the 7-channel layout: the desk patches it as two generic 4-channel LED fixtures on consecutive addresses. |
| 2026-10-27 | Settings are one versioned JSON file in Application Support (`"format": "cuemodo-cyc-settings"`), saved automatically; missing values fall back to defaults. The output display is remembered by ID with its name as a fallback. |
| 2026-10-27 | Mapping: quads hold `source` corners on the canvas and `destination` corners in output pixels; with no quads the canvas fills the output. The shader maps each output pixel back to the canvas with the inverse homography, so no textures are needed. |
| 2026-10-27 | The mapping is edited only in the Mapping window. The on-wall edit mode (8a) is removed; instead the output can show a test **Grid** (a third choice next to Art-Net and Test color). Nothing takes the keyboard away from QLab. |
| 2026-10-28 | "Test color" is renamed **Manual**: colors picked in the app instead of Art-Net, with a top and a bottom color in gradient modes. Old settings files (`testColor`) still load. Hints in the settings window are tooltips; only problems show as text. |
| 2026-10-28 | The main window shows only what the chosen source needs: Art-Net (universe, address, mode, status, levels), Manual (Solid/Gradient and colors, kept apart from the fixture mode so testing never changes the patch), or Test Pattern (renamed from Grid, room for more patterns later). Old `grid` settings still load. |
| 2026-10-28 | Mode names use channel letters like fixture manuals and desk libraries: RGB, DRGB, Gradient RGB, Gradient DRGB (D = dimmer). Saved values are unchanged. |
