# Roadmap

Each step is one reviewable commit, a few hundred lines at most, and ends with something you can
run and see. Steps 1 to 9 make a show-ready first version; the rest is polish.

**Status (2026-10-27):** steps 1 and 2 are done. Next up: step 3 (Art-Net in).
**Deadline:** dress rehearsal on Sunday 2026-11-01, so steps 1 to 9 must land by Saturday Oct 31.

## Show-ready version

| # | Step | Status |
| --- | --- | --- |
| 1 | **Skeleton.** Swift package, settings window, README, MIT license, CI | done |
| 2 | **Output window.** Pick a display, borderless fullscreen Metal window, test color; pointer hidden, display kept awake, Esc closes | done |
| 3 | **Art-Net in.** UDP listener on 6454, ArtDmx parser, universe filter, tests from sample packets; settings show live channel values | |
| 4 | **Fixture.** Address and mode (RGB, Dim + RGB, Gradient, Dim + Gradient) turn 512 values into top and bottom colors; tests. First time the desk drives the wall | |
| 5 | **Settings file.** Save and load JSON: display, universe, address, mode | |
| 6 | **Homography math.** Four point pairs to a 3x3 matrix; tests | |
| 7 | **Mapped render.** Shader draws N quads with source and destination corners, black elsewhere, dithering; quads read from JSON | |
| 8 | **Mapping editor on the output.** Grid test pattern, corner handles, drag, keyboard nudge, select quad, undo | |
| 9 | **Show hardening.** Lock mode, signal-loss behavior, auto-open output at launch, CPU/GPU check next to QLab | |

## After the show

| # | Step | Status |
| --- | --- | --- |
| 10 | **sACN in.** Multicast join, E1.31 parser with priority and sequence, protocol picker | |
| 11 | **Second output.** Separate window and quads per display, for setups with two cables | not needed for now |
| 12 | **Edge blend.** Soft fade across quad edges, adjustable width and curve | |
| 13 | **Fixture profiles.** Hog, QLab and Cuemodo fixture definitions; short user guide | |
| 14 | **Signing.** Wrap into a .app, Developer ID signing and notarization | |
| 15 | **Gradient angle.** One more channel rotates the gradient (Gradient + Angle 7ch, Dim + Gradient + Angle 8ch) | |
