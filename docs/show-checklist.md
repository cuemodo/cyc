# Show checklist

Before the dress rehearsal and every show. Takes ten minutes.

## Once, when setting up

1. Connect the Matrox (projectors on) before opening Cuemodo Cyc. Check the display list shows
   one 3840 x 1200 display.
2. Pick that display, set Show to **Test Pattern**, Start, and check the grid lines run straight
   across the seam and stop at the edges of each wall. Fix corners in the Mapping window.
3. On the desk, patch the fixture with the universe, address and mode shown under **Art-Net
   Patch** (for Gradient DRGB: two generic 4-channel LED fixtures on consecutive addresses).
4. Set Show to **Art-Net**, run a few cues and fades, and check Show Levels moves with the desk.
5. Choose **Signal loss**: hold (safer if the desk may reboot mid-scene) or fade to black.

## CPU and GPU check next to QLab

1. Open QLab with the real show and Cuemodo Cyc with the output running on Art-Net.
2. Open Activity Monitor: Window > GPU History, and the CPU tab sorted by % CPU.
3. Run the heaviest part of the show in QLab (video cues, many audio cues) while the desk runs a
   long fade on the cyc.
4. Expected: Cuemodo Cyc well under 10 % CPU and a small slice of GPU; fades smooth on the wall,
   QLab playback unaffected. If not, note the numbers and tell Claude.
5. Leave it running 30 minutes and check the display didn't sleep and nothing got slower.

## Before each show

1. Projectors and Matrox on, then the Mac; open QLab and Cuemodo Cyc.
2. Check the output is on the projectors and the Art-Net status says it's receiving.
3. Pull the Art-Net cable for a few seconds: check the signal-loss behavior, then plug it back.
4. Click **Lock**. Bring QLab to the front.
