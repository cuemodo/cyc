# Architecture

Cuemodo Cyc is a small native macOS app that makes projectors behave like one DMX fixture. It
receives Art-Net, turns the fixture's channels into a solid color or a top-to-bottom gradient, and
draws that on the projector output through a few mapped quads. Everything outside the quads stays
black, which hides projector overlap and light spilling outside the wash area.

It runs on the same Mac as QLab, so the first rule is to stay light: draw only when something
changes.

## The ideas in plain words

- **DMX channel and address.** A DMX universe is 512 numbers, each 0 to 255. A fixture uses a few
  consecutive numbers starting at its *address*. At address 101 in RGB mode, Cyc reads 101 (red),
  102 (green) and 103 (blue).
- **Art-Net and sACN.** Two ways of sending DMX universes over a normal network as UDP packets.
  Art-Net usually broadcasts on port 6454. sACN (E1.31) uses multicast on port 5568 and adds a
  priority. Art-Net counts universes from 0, sACN from 1.
- **Virtual fixture.** Cyc pretends to be a light. A Hog 4, SmartFade, QLab or Cuemodo patches it
  like a generic LED and fades it.
- **Cyc.** A theatre backdrop, usually lit by top lights and a ground row in different colors. The
  gradient mode imitates that.
- **Input canvas.** An imaginary picture filled with the color or gradient, by default the size of
  the output (3840 x 1200).
- **Quad mapping.** A quad is a four-cornered shape. Each quad has *source* corners (a patch of the
  canvas) and *destination* corners (where that patch lands on the output). The patch is stretched
  to fit, like pinning a rubber sheet at four points. The math is a 3x3 *homography*, which maps
  one four-cornered shape onto another, perspective included.
- **Overlap and bleed.** Where two projectors hit the same spot it is twice as bright. Cyc uses a
  hard cut: quads meet edge to edge so each spot is lit by one projector. Bleed is light landing
  outside the wash area; black hides most of it, but projectors still glow faintly on black.

## Target setup (first show)

- MacBook Pro M1 Pro running QLab and Cyc.
- Two WUXGA projectors (1920 x 1200) behind a Matrox splitter: macOS sees one 3840 x 1200 display.
- DMX from a Hog 4 desk, or a SmartFade ML through a DMX-to-Art-Net node, over Ethernet. The Mac
  must be on the same IP subnet as the desk or node (often 2.x.x.x or 10.x.x.x).

## Fixture modes

| Mode | Channels | Meaning |
| --- | --- | --- |
| RGB | 3 | Red, green, blue for the whole canvas |
| Dim + RGB | 4 | Master intensity first (scales all colors), then RGB |
| Gradient | 6 | Top R, G, B, then bottom R, G, B |
| Dim + Gradient | 7 | Master intensity, then top RGB, then bottom RGB |

## Code layout

- `Sources/CycCore/`: everything testable without a screen: colors, DMX parsing, fixture modes,
  mapping math, settings. Unit tested with XCTest.
- `Sources/Cyc/`: the app. SwiftUI settings window, AppKit output window, Metal renderer.
- Values are normalized (0.0 to 1.0) inside the app; DMX bytes are converted at the edge.

## Signal path

1. **Network.** A UDP socket on port 6454 (with port reuse, so other apps can share it) keeps only
   ArtDmx packets for the chosen universe. sACN later joins the universe's multicast group.
2. **Fixture.** Address and mode turn the 512 values into a top and bottom color.
3. **Render.** One Metal draw on the output display. If DMX stops: hold the last look (default) or
   fade to black after a few seconds.

## Rendering

- One borderless window covers the output display, above its menu bar. It never takes keyboard
  focus by itself, so QLab keeps its GO key; click it, then Esc, to close it.
- The Metal view is paused and draws only when the color or the mapping changes.
- No textures: the shader computes the color from the canvas position (solid, or a top-to-bottom
  blend). Each quad is two triangles at its destination corners; the homography maps each output
  pixel back to a canvas position.
- Small random dithering on gradients hides 8-bit banding on a big wall.
- The pointer hides over the output, and the display is kept awake while the output is open.

## Mapping editor

- Edit mode shows a grid test pattern and corner handles on the projector output itself, so you
  align by looking at the wall.
- Drag corners with the mouse, Tab to select a quad or corner, arrow keys nudge 1 px (Shift for
  10 px), undo.
- A preview in the settings window shows the source quads on the canvas.
- Lock mode for the show: no editing, pointer hidden, display kept awake.

## Settings

One JSON file holds protocol, universe, address, mode, display and quads, with export and import
for backup.

## Risks and gotchas

- **Local network permission.** Recent macOS asks before an app receives network traffic. Click
  Allow once (when run with `swift run`, the prompt is for Terminal).
- **Displays and Spaces.** If QLab also uses a video output, the two apps must not claim the same
  screen.
- **Projector black is not black.** Masked areas still glow; lens shift or a flag may still be
  needed.
- **Color match between projectors.** Two models rarely match; a per-output color trim is a cheap
  later addition.
- **Unsigned builds.** Fine on your own Mac; other Macs need Developer ID signing (roadmap step 14).
