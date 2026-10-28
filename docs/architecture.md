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
| DRGB | 4 | Dimmer (intensity) first (scales the color), then RGB |
| Gradient RGB | 6 | Top R, G, B, then bottom R, G, B |
| Gradient DRGB | 8 | Top dimmer + RGB, then bottom dimmer + RGB |

Gradient modes are simply two RGB (or dimmer + RGB) blocks in a row, so on the desk they patch as
two ordinary 3- or 4-channel LED fixtures on consecutive addresses, no custom profile needed.

## Code layout

- `Sources/CycCore/`: everything testable without a screen: colors, DMX parsing, fixture modes,
  mapping math, settings. Unit tested with XCTest.
- `Sources/Cyc/`: the app. SwiftUI main window (`MainView`), AppKit output window, Metal renderer.
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

The **Mapping window** ("Mapping…" in the main window) works with the output open or closed.
It shows every quad twice: on the canvas (the patch of the picture it takes) and on the output
(where it lands). Drag corners on either side, or click a corner and nudge it with the arrow keys
(Shift: 10 px, Tab for the next corner). Click a quad to select it: its corners are listed as
numbers (canvas and output) in the sidebar, boxed so you can see which corner is selected, and
can be typed exactly or stepped with the up / down arrows. Add or remove quads, and set the canvas
size. Edit > Undo (Cmd-Z) undoes each change, and every change saves itself.

A room with four walls of different sizes is four quads: each wall's source patch can have its own
size and height on the canvas, so the gradient lines up the way you want across walls.

To line up on the wall, set the output to **Test Pattern**: the quads show a white test grid drawn on the
canvas (a line every 100 canvas pixels, a thicker one every 500). When the mapping is right, the
lines run straight across the seam between projectors. Moves that would dent a quad or cross its
edges are refused.

## Settings

One JSON file, `~/Library/Application Support/Cuemodo Cyc/settings.json`, holds the universe,
fixture (address and mode), output source, Manual colors, display, mapping and the show options
below. It
starts with `"format": "cuemodo-cyc-settings"` and a version number. Cyc loads it at launch and saves
it half a second after the last change and at quit. To back it up or move it to another Mac, copy
the file (File > Show Settings File in Finder).

The File menu works on copies: **Save Settings As…** (Cmd-S) writes the current settings anywhere,
for example one file per show; **Open Settings…** (Cmd-O) loads such a file back in; **New
Settings** (Cmd-N) starts fresh from the defaults, keeping the chosen display. Open and New ask
first and are off while the show is locked. The app's own file keeps saving itself either way.

## Typing a mapping by hand

The editors cover everything, but the mapping can also be typed in the settings file, for example
to start from exact numbers.

Quit Cyc, open the settings file (File > Show Settings File in Finder), edit the `mapping` block, and relaunch.
All numbers are pixels. `source` corners are on the canvas, `destination` corners on the output
(the Matrox output is 3840 x 1200: the left projector shows x 0 to 1920, the right one 1920 to
3840). Corners go clockwise from top-left. With an empty `quads` list the canvas fills the output.

For a hard cut, split the canvas where the seam should be on the wall, give each projector the
canvas patch it should light, and move its destination corners until the patch lands on the wall
edge to edge with the other one. Everything outside the quads stays black.

```json
"mapping" : {
  "canvasWidth" : 3840,
  "canvasHeight" : 1200,
  "quads" : [
    {
      "source" : {
        "topLeft" : { "x" : 0, "y" : 0 },        "topRight" : { "x" : 1920, "y" : 0 },
        "bottomRight" : { "x" : 1920, "y" : 1200 }, "bottomLeft" : { "x" : 0, "y" : 1200 }
      },
      "destination" : {
        "topLeft" : { "x" : 40, "y" : 30 },       "topRight" : { "x" : 1880, "y" : 0 },
        "bottomRight" : { "x" : 1900, "y" : 1200 }, "bottomLeft" : { "x" : 0, "y" : 1170 }
      }
    },
    {
      "source" : {
        "topLeft" : { "x" : 1920, "y" : 0 },      "topRight" : { "x" : 3840, "y" : 0 },
        "bottomRight" : { "x" : 3840, "y" : 1200 }, "bottomLeft" : { "x" : 1920, "y" : 1200 }
      },
      "destination" : {
        "topLeft" : { "x" : 1980, "y" : 0 },      "topRight" : { "x" : 3840, "y" : 20 },
        "bottomRight" : { "x" : 3800, "y" : 1200 }, "bottomLeft" : { "x" : 1960, "y" : 1180 }
      }
    }
  ]
}
```

Quads with a dent, crossed edges or squashed corners are skipped; the main window says how
many.

## Show safety

- **Signal loss.** If Art-Net stops (desk, node or cable), the output either holds the last look
  (default) or fades to black over 2 s, after a timeout you choose (5 s by default). The main
  window says so in red. The next packet brings the look straight back.
- **Display at launch.** If the saved display is not connected yet (projectors switched on after
  the Mac), it is selected as soon as it shows up.
- **Display drop-out.** If the projectors' display disappears while the output is open, the output
  reopens on it when it comes back.
- **Lock.** The Lock button makes the main and Mapping windows ignore clicks and keys, and Esc on
  the output does nothing. It stays locked after a relaunch.
- **Quit.** Cmd-Q asks first while the output is live.

See [show-checklist.md](show-checklist.md) for the steps before a show, including the CPU/GPU check
next to QLab.

## Risks and gotchas

- **Local network permission.** Recent macOS asks before an app receives network traffic. Click
  Allow once (when run with `swift run`, the prompt is for Terminal).
- **Displays and Spaces.** If QLab also uses a video output, the two apps must not claim the same
  screen.
- **Projector black is not black.** Masked areas still glow; lens shift or a flag may still be
  needed.
- **Color match between projectors.** Two models rarely match; a per-output color trim is a cheap
  later addition.
- **Signed builds only for other Macs.** `swift run` builds are unsigned and fine on your own Mac;
  to copy the app to the show Mac, use the notarized zip from `scripts/package.sh`.
