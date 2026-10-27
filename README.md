# pcbstitch

**New here? Start with the [Quick start](QUICKSTART.md) · [クイックスタート(日本語)](QUICKSTART.ja.md)**

Stitch overlapping close-up photos of a flat object, mainly PCB teardown photography, into
one high-resolution image. Hugin does the work; `pcbstitch` wraps it in a recipe that was
tuned and checked against hand-made Hugin stitches of real boards.

```
pcbstitch front1.ARW front2.ARW front3.ARW
```

```
• developing 3 raw file(s) with RawTherapee -> ./png
front_stitched: 3 images, anchor front2.png -> ./stitched/front_stitched.png
• project (HFOV 15.19°)
• control points
• geometric optimisation
• photometric optimisation
• rendering layers
• blending (routed seams)
done: front_stitched.png 5942x8406
  control points 132, mean error 1.14px, max 2.99px
  ghost pixels 610 in 0 region(s)
```

- [Install](#install)
- [Usage](#usage)
- [What it does](#what-it-does)
- [Why it works this way](#why-it-works-this-way): background and lessons learned
- [Validation](#validation)
- [Shooting tips](#shooting-tips)
- [Troubleshooting](#troubleshooting)
- [Limitations](#limitations)

---

## Install

You need these on your `PATH`:

| Tool | Used for | Tested with |
|---|---|---|
| Hugin command-line tools: `pto_gen cpfind cpclean pto_var autooptimiser vig_optimize pano_modify nona pano_trafo checkpto` | alignment and remapping | Hugin 2025.0.1 |
| `enblend` | only for `--blend enblend` | 4.2.1 |
| `rawtherapee-cli` | only for raw input | 5.12 / 5.13 |
| [`uv`](https://docs.astral.sh/uv/) | runs the script and installs numpy, opencv-python-headless and pillow on first use | 0.12 |

On Arch / CachyOS: `pacman -S hugin enblend-enfuse rawtherapee uv`.

**One-step setup**, the easiest way. It installs all of the above with your package manager,
clones to `~/pcbstitch` (or `$PCBSTITCH_DIR`), runs `install.sh` and does a test run:
```
curl -fsSL https://raw.githubusercontent.com/kage-engineering/pcbstitch/main/setup.sh | bash
```
It supports pacman (Arch / CachyOS / Manjaro), apt (Ubuntu / Debian / Mint), dnf (Fedora) and
zypper (openSUSE). Messages are in Japanese when the system language is Japanese. Re-running it
updates the checkout.

**Manual:**

```
git clone https://github.com/kage-engineering/pcbstitch.git
cd pcbstitch && ./install.sh
```

`install.sh` links the script into uv's bin directory (usually `~/.local/bin`). If that
directory isn't on your PATH, it adds a guarded, marked line to `~/.bashrc`, the bash login
file (`~/.bash_profile`, `~/.bash_login` or `~/.profile`, whichever exists first) and
`~/.zshrc`, plus `~/.config/fish/conf.d/pcbstitch.fish`. Then it checks the dependencies.
Open a new terminal afterwards.
- **Updating:** the link points at the checkout, so `git pull` updates the command.
- **Removing:** `./install.sh --uninstall` removes the link and every line it added.

The script is one file with [inline script metadata](https://packaging.python.org/en/latest/specifications/inline-script-metadata/),
and its shebang is `uv run --script`, so you don't need a virtualenv.

## Usage

```
pcbstitch [options] IMAGE [IMAGE ...]
```

Give it the photos of **one side** of a board, **in order along the strip** (top to bottom
or left to right). The input can be raws (`.ARW .NEF .CR2 .CR3 .DNG .RAF .ORF .RW2 …`) or
PNG/TIFF/JPEG, but not a mix of both.

```
pcbstitch ~/Pictures/board/front*.ARW               # raws -> board/png/, result -> board/stitched/
pcbstitch PCB/PCB2/back/png/*.png                   # result -> PCB/PCB2/back/stitched/
pcbstitch --name board_back back3.ARW back2.ARW back1.ARW
pcbstitch --rotate 180 *.ARW                        # board was shot upside down
pcbstitch --blend enblend --qa-image a.png b.png    # Hugin's normal blender + QA overlay
pcbstitch front1.ARW front2.ARW front3.ARW --detail IC.ARW   # extra shot lit to read chip markings
```

### Outputs

| File | Contents |
|---|---|
| `<name>_stitched.png` | the result: RGBA, cropped to the fully covered area, with the ICC profile and EXIF copied from the anchor image |
| `<name>_stitched.pto` | the Hugin project, with image paths relative to the output directory |
| `<name>_stitched.log` | the full output of every tool that ran |
| `<name>_qa.jpg` | with `--qa-image`: a downscaled preview with ghost pixels marked in red |

Default locations follow a `set/png/*.png` → `set/stitched/` layout:
- If the input images are in a folder named `png`, the output goes to a sibling `stitched/` folder; otherwise it goes to `stitched/` next to the images.
- Raws are developed into `png/` next to the raws.
- The default name is the common prefix of the file names with trailing digits and separators removed (`front1 front2 front3` → `front`, `PCB_PCB2_back_1 …_2` → `PCB_PCB2_back`).

### Options

| Option | Default | Meaning |
|---|---|---|
| `-o, --outdir DIR` | `<set>/stitched` | output directory |
| `-n, --name NAME` | from file names | writes `NAME_stitched.png` |
| `--anchor I` | middle image (first of two) | index, in the order given, of the image that stays fixed |
| `--crop-factor F` | `1.5` | sensor crop factor (APS-C = 1.5, full frame = 1) |
| `--focal MM` | EXIF | focal length if it isn't in EXIF |
| `--fov DEG` | from focal and crop | horizontal field of view, overrides the two above |
| `--blend auto\|seams\|enblend` | `auto` | `auto` routes seams for a single row or column and uses enblend otherwise |
| `--band PX` | `24` | seam feather width |
| `--points K` | `4` | cpfind density: up to 25·K points per image pair |
| `--ransac-px PX` | `3` | how far a control point may sit from the flat-board fit |
| `--png-dir DIR` | `<raw dir>/png` | where developed raws go |
| `--rotate 0\|90\|180\|270` | `0` | coarse rotation applied when developing raws |
| `--redevelop` | off | develop raws again even if PNGs exist |
| `--detail IMAGE …` | none | extra photo(s), e.g. re-lit or refocused on a chip, used **only** where they show more detail than the stitch (see [Detail frames](#detail-frames-reading-chip-markings)) |
| `--vignetting` | off | also correct vignetting; only for photos developed without a lens correction |
| `--keep-redundant` | off | use every image, even ones fully covered by the others |
| `--qa-image` | off | write `<name>_qa.jpg` |
| `--keep-temp` | off | keep the work directory (layers, intermediate `.pto` files) |

### Reading the summary

- **mean / max error**: control-point residuals after optimisation, in pixels. A good flat
  stitch is about 1 px mean and under 3–4 px max. Larger values mean parallax, moving objects
  or wrong matches; see [Troubleshooting](#troubleshooting).
- **ghost pixels / regions**: pixels of the result that match **none** of the source photos
  covering them (more than 40/255 apart, after a 5×5 blur). That happens when a seam cuts
  through something that differs between shots. Up to a few thousand scattered pixels is
  noise; a "region" is a connected blob over 400 px and is worth a look (use `--qa-image`).
- **transparent pixels**: only printed when non-zero. The crop should be fully covered.

---

## What it does

1. **Develop raws** (raw input only):
   - Runs `rawtherapee-cli -d -s -n -b8`: your RawTherapee *default raw profile*, plus a `.pp3` sidecar where one exists, giving 8-bit PNG.
   - Existing PNGs newer than the raw are reused.
2. **Create the project** (`pto_gen -f <hfov>`):
   - The anchor image becomes image 0.
   - The horizontal field of view (HFOV) is computed from the EXIF focal length and the crop factor.
3. **Find control points**:
   1. `cpfind --multirow --sieve2size 4`: 4× Hugin's default density.
   2. `cpclean`: Hugin's statistical outlier removal.
   3. **Planar filter**: for each image pair, keep only points consistent with one homography (RANSAC, 3 px).
   4. **Weak-pair removal**: drop a pair with under 20% of the strongest pair's points, if the images stay connected without it.
4. **Optimise geometry** (`autooptimiser -n`):
   - Image 0 is fixed. Every other image gets roll, pitch, yaw and X/Y/Z translation; barrel distortion `b` is shared.
   - The HFOV is **not** optimised.
   - Then up to three rounds of: compute each point's residual in source-image pixels, drop points above max(3 px, 3× median), re-optimise.
   - **Session check:** if the photos' EXIF capture times span more than an hour, it warns and lists them, because loose parts may have moved in between.
   - **Redundant frames:** with three or more images, each image's outline is projected onto the panorama. An image whose area is at least 97% covered by the others is skipped and reported, and steps 2–4 run again without it. It never drops the anchor; it prefers to drop a frame taken furthest in time from the others, then the least sharp one. `--keep-redundant` turns this off.
5. **Optimise photometrics** (`vig_optimize`): exposure of each non-anchor image and the camera response curve (`Ra…Re`). Vignetting (`Vb Vc Vd`) is only fitted with `--vignetting`, because the lens profile in RawTherapee already corrects it ([why](#photometrics)). The anchor frame keeps its developed colours exactly. Detail frames are aligned in steps 2–4 like the others, but are marked `disabled` for this step. They're then given the strip's exposure, and the output exposure `E` is set to the strip's mean.
6. **Set up output** (`pano_modify`): rectilinear projection, automatic FOV and canvas, autocrop.
7. **Render** each image as its own full-canvas layer (`nona -m TIFF_m`).
8. **Blend**:
   - **seams** (a single row or column): for each neighbouring pair, find the cheapest left-to-right path through the overlap, where cost is how much the two layers differ. Each pixel is then assigned to **exactly one** layer: the one whose band between seams contains it, or else the nearest layer in the strip that covers it. The labels are feathered (σ = `band`/2) into the composite.
   - **enblend**: plain `enblend` on the layers, as Hugin itself does.

   Detail frames are left out of both.
9. **Patch in detail frames** (`--detail`): paste each one into the regions where it shows clearly more fine detail than the stitch while agreeing with it at a coarse scale. The patch keeps the frame's fine detail but takes the stitch's coarse tone.
10. **Write output**:
   - Crop to Hugin's autocrop rectangle, computed over the strip only and shrunk by a few pixels (see below).
   - Write the PNG and insert the `iCCP` and `eXIf` chunks from the anchor image.
   - Write the `.pto`, with any detail frames included but disabled, and print the QA summary.

---

## Why it works this way

This recipe came from reverse-engineering ten hand-made Hugin stitches, re-stitching them, and
fixing what went wrong on a harder 3-shot board. The findings below are the useful part. Most
apply to Hugin stitching of flat subjects in general.

### The reference workflow (Hugin GUI)

The hand-made projects were all 2-image pairs shot with a Sony ILCE-6300 (APS-C) and an
FE 90mm F2.8 Macro G OSS, developed in RawTherapee and stitched in the Hugin 2025.0.1 GUI.
Every project was set up the same way:

- **Projection** `f0`, rectilinear, the right choice for a flat subject shot square-on.
- **Image 0 is the anchor** (`r0 p0 y0 TrX0 TrY0 TrZ0`). Image 1 gets `r p y TrX TrY TrZ`, the
  mosaic or translation model, because the camera moves over the board instead of rotating
  about a point.
- **Geometric optimiser switch `46`** = positions (2) + view/HFOV (4) + barrel (8) + translation (32):
  `v0` and `b0` are optimised along with the positions.
- **Photometric optimiser switch `21`** = exposure (1) + vignetting (4) + camera response (16):
  `Eev1`, `Vb Vc Vd`, `Ra…Re`.
- **About 25 control points per pair**, never cleaned. This is cpfind's default cap:
  `--sieve2width 5 × --sieve2height 5 × --sieve2size 1`.
- **Output**: enblend, PNG, autocrop. The stitched PNG is exactly the `.pto`'s crop rectangle
  (`S` on the `p` line).

### HFOV: the crop factor, and why it isn't optimised

- **The crop factor is missing from EXIF.** RawTherapee PNGs carry `FocalLength = 90` but no
  35 mm-equivalent focal length, so `pto_gen` can't work out a field of view and falls back to
  **50°**. In the GUI, entering crop factor 1.5 gives the values in every good reference project:

  ```
  sensor width = 36 mm / crop × (image width / image long side)
  HFOV = 2·atan(sensor width / (2·focal))
  landscape 6016 px wide: 2·atan(24 / 180)    = 15.19°
  portrait 4016 px wide:  2·atan(16.02 / 180) = 10.17°
  ```

- **HFOV is degenerate on a flat scene.** With two or three images of a flat subject, a change
  of HFOV looks almost exactly like a change in Z translation, so the optimiser can wander:
  - Two of the ten reference projects drifted to 3.76° and 8.39°, and those were their two worst stitches.
  - An early version of this script that optimised `v` went to 0.17° on one set and failed outright, and to 23° and 50° on others.
  - Holding HFOV at the computed value and letting `TrZ` absorb scale fixed all of them.

### Control points: parallax and things that move

At macro distances, anything that isn't in the board plane shifts between shots differently
from the board: tall capacitors, shields, connectors, labels, LEDs on leads. That is
**parallax**, and no flat-board model can fit those points. Loose objects also **move** while
you reposition the board or camera: antenna boards, coax cables, foam pads. Points on either
pull the least-squares fit away from the board.

Three cases that shaped the recipe:

- **Uncleaned outliers.** One reference pair kept a wrong control point with a 48 px error.
  It pulled the whole fit off: 9.3 px mean error, and about 6.4 px median misalignment in the
  overlap, against 1.3 px after re-stitching with outliers removed.
- **A cluster of points on a tall part.** A 3-shot router-board back gave a 5.4 px mean error
  with the default settings, and the bad points all sat on one tall labelled block. Taking more
  points (`--sieve2size 4`) didn't help on its own, and neither did a threshold based on the
  median, because so many points were bad that the median itself was inflated.
  A **robust per-pair homography** (RANSAC) was the fix: a robust similarity fit put most points
  within about 1.2 px, so the outliers are exactly the points to discard.
- **A weak link between non-adjacent frames.** In that same set the top and bottom frames
  shared 7–13 matches. Those implied a −0.95° rotation, while the two adjacent pairs implied
  +0.31° and +0.36°. They were matches on loose objects. Removing that weak, redundant pair
  brought the mean error to 1.03 px and the maximum to 2.9 px.

Residuals for the pruning step are measured in **source-image pixels**: a point is mapped from
image *n* into the panorama with `pano_trafo`, then back into image *N* with `pano_trafo -r`.
Panorama pixels are no good before the canvas is set, because `pto_gen`'s default canvas is a
tiny equirectangular one, so every error looks like about 0.1 px.

### Photometrics

Leaving out the response curve (`Ra…Re`) gave visibly darker, more contrasty output than the
references. Optimising exposure, vignetting **and** response, as the GUI does, brought overall
brightness to within 1–5 levels of the references, and in several sets matched the two layers
to each other better than the references did.

**Colour accuracy, and why vignetting is now off by default.** A later check compared each
stitch with the developed photos themselves. The anchor frame was rendered twice into the
output canvas: once with the fitted photometrics, and once neutral (geometry only, which
reproduces the source PNG to within 0.2 levels).

- **What vignetting correction did.** White balance (B−G and R−G on the white background, within
  0.5 levels) and saturation (within 1%) were preserved. But every frame got darker towards its
  edges: about 1 level overall and 2–3 at the edges on one board, and about 2.5 overall and
  4–6 in midtones on the other. The anchor's exposure equals the output exposure, so this was
  entirely Hugin's vignetting correction. RawTherapee's lens profile (`UseVignette=true`)
  already corrects the lens, so Hugin was correcting a second time and fitting uneven lighting
  instead.
- **Without it.** Fitting only exposure and response makes the anchor frame **identical** to the
  developed photo: 0.0 levels difference, white balance and background unchanged.
- **Seams.** Overlap brightness matching changed by under about 1 level on average. A
  background brightness profile along both sides of the image showed no new seam steps (front
  p99 3.1/8.2 vs 2.9/8.1 levels; back max 11.8/13.1 vs 9.2/16.7, where the large values are
  object edges). Ghosting was unchanged.

So vignetting is off by default; `--vignetting` turns it back on for photos developed without a
lens correction. Every other frame still gets an exposure (gain) adjustment so that it matches
the anchor.

### Blending: why seams are routed outside enblend

enblend's default seam finder is graph-cut, but it only searches a corridor around an initial
nearest-feature seam. On the router board the seam cut straight through a coax cable that had
moved between shots. The result was a cable that stopped and restarted, with a grey
ghost. Other seams crossed an antenna board and the top of the tall block.

The routed-seam blender:
- Works at ¼ resolution on the per-layer difference image (Gaussian-blurred max-channel |Δ|).
  It finds the minimum-cost monotone path across each overlap with dynamic programming, moving
  at most one row per column. On the router board the seams ran through pixels that differed by
  about 6 levels, against about 14 on average across the overlap.
- Gives each layer a soft weight: its seam-trimmed mask blurred with σ = band/2, multiplied by
  its coverage. The composite is the weighted mean. Feathering is safe here because the seam
  runs where the layers agree and the exposures are already matched.
- Result: ghost pixels went from about **337k with enblend** to about **1.8k**, and from 30
  regions to 2. The two left are on a tall label, where each frame shows it from a different
  angle; the result is sharp, just taken from one frame.

Two edge cases cost some time:

- **Trim only where the other layer covers.** If a layer is cut at the seam even where it is
  the only coverage, the result has holes at the canvas edges.
- **Feather instead of handing trimmed masks to enblend.** Trimming creates tiny vertical seams
  at coverage boundaries. enblend's pyramid then pulls in the black outside the mask, which
  shows as a dark line a few pixels wide. Feathering avoids that.

### Extra frames and one layer per pixel

A real run passed four frames: a three-shot strip plus a close-up of the main IC taken
**43 hours later** at a different shutter speed. The close-up overlapped the strip completely,
but the antenna boards had been moved between the two sessions. Two problems followed:

- **The seam rule leaked.** The original seam blender trimmed each layer only against its
  immediate neighbour in the strip. Where the neighbour didn't cover a pixel, the layer kept it,
  even if a third layer did. So the close-up kept pixels showing an antenna board that, in the
  other frames, wasn't there: a green fragment at the edge of the stitch (11,185 ghost pixels in
  2 regions).
- **Graph cut was not the answer.** OpenCV's general graph-cut seam finder
  (`cv2.detail_GraphCutSeamFinder`) handles every overlapping pair, but here it did worse
  (17,083 pixels in 6 regions), cutting through antenna-board edges. It was also 2–3× slower.

What fixed it:
- **Skip frames that add no area.** Here the close-up was skipped, giving 243 scattered pixels
  and 0 regions. The different shooting times also produce a warning.
- **Exactly one layer per pixel.** The strip seams give each pixel a preferred layer, with a
  fallback to the nearest layer that covers it. With `--keep-redundant`, the same four frames now
  give 1,023 pixels in 1 region, and the shin back set (with the moved cable) went from 1,966
  ghost pixels in 2 regions to 0.

### Detail frames: reading chip markings

Laser-etched chip markings often vanish under the light used for the overview shots. In one
set, the two MediaTek RF chips looked like plain black squares in all three strip photos. A
separate shot with different light, taken with the same lens and framing but at another shutter
speed two days later, showed `MEDIATEK MT7762N 2503-BJCAL AAP51738` and
`MT7761N 2508-BJCSL AAP53269` clearly. It is not a zoomed or higher-resolution shot; the
difference is purely lighting.

Treating that shot as a normal frame is wrong: it was skipped as redundant, and when kept, the
antenna boards that had moved left a fragment. So `--detail` frames are handled separately:

- **Alignment:** same as the strip (they share its control points), so they line up to about 1 px.
- **Where they're used.** At half resolution, compare fine-detail strength (a blurred high-pass)
  between the stitch and the detail frame:
  - The detail frame is first scaled to the stitch's local brightness. Otherwise a brighter
    frame wins on noise alone: in one run that gave 28 patches over bare board and grainy chip
    text.
  - Candidate pixels need more than 1.8× the stitch's detail (plus a small offset) **and** a
    coarse colour difference of at most 25 levels (σ = 12). The second condition stops a moved
    green antenna board on white table from ever qualifying.
  - Each candidate region becomes its convex hull grown by 40 px, so a whole chip top is
    replaced rather than half of its text. Regions under about 6,000 px are dropped.
- **How they're pasted.**
  `detail + blur(stitch, σ=25) − blur(detail, σ=25)`, feathered in with σ = 8. The markings come
  from the detail frame; brightness and colour come from the stitch, so no rectangle shows.

Pitfalls found while building this:

- **Output exposure.** `pto_gen` sets the panorama's output exposure `E` to the **mean EXIF
  exposure of all images**. A detail frame at 1/8 s among 1/3 s frames (Eev 9.0 vs 7.58) raised
  `E` and darkened the whole stitch by about 1.3×. That's also why the first, accidental
  four-frame run looked darker. `E` is now the strip's mean.
- **Photometric fit.** Including a differently lit frame in `vig_optimize` shifts the shared
  response curve for everything (Ra +0.48 instead of about −4). Hugin's `#-hugin … disabled`
  flag excludes it. A second pass fitting only the detail frame's exposure was tried, but it
  rendered the frame 1.85× too bright and its noise looked like detail. The detail frame
  therefore gets the strip's exposure directly; RawTherapee's auto-matched curve has already
  evened out the PNGs' brightness.
- **Autocrop.** It runs over all enabled images, and the detail frame reached 4 px past the
  strip's edge. The crop is computed with detail frames disabled.

### Edges and cropping

`nona` leaves partly covered, darkened pixels along each layer's boundary:
- **Seam mode:** layers are eroded by 2 px (full-alpha pixels only) and the crop shrinks by 4 px per side.
- **enblend mode:** the crop shrinks by 2 px per side. Without this, about 1,700 scattered
  transparent pixels were left along the edges, where Hugin's own output has none.

### Metadata

`hugin_executor` copies EXIF and ICC into the output with `exiftool`. Without exiftool
installed this silently fails (`execvp(exiftool …) failed with error 2`), and the output has no
colour profile. `pcbstitch` doesn't use exiftool. It inserts `iCCP` and `eXIf` chunks taken from
the anchor image straight into the PNG, with no re-encode, so the result keeps the source's
`RTv4_sRGB` profile and camera EXIF.

### RawTherapee

- **The sidecars are the default profile plus rotation.** The reference `.pp3` sidecars were
  RawTherapee's bundled **Auto-Matched Curve – ISO Low** profile (the `RawDefault` in
  RawTherapee's `options` file) with only a per-image *Coarse Transformation → Rotate*. The other
  fields that differ between sidecars are auto-computed: the matched tone curve, camera white
  balance and the capture-sharpening radius.
- **`rawtherapee-cli -d` reproduces the reference PNGs** to within 0.64 levels mean absolute
  difference (SSIM 0.9992). Using the saved sidecar reproduces them exactly.
- **The output carries what Hugin needs:** `-n -b8` gives 8-bit PNG with an embedded sRGB
  profile and EXIF, focal length included.

---

## Validation

How the recipe was checked, so the same checks can be run on new data:

1. **Re-render the reference projects.** Rendering the hand-made `.pto` files on the test
   machine reproduced the reference PNGs almost pixel for pixel: 0.02–0.04 px, SSIM ≥ 0.995.
   So any difference between stitches comes from project choices, not tool versions.
2. **Compare the two stitches directly:** SIFT matches plus a RANSAC homography between the new
   stitch and the reference, then residuals, scale, mean absolute difference and SSIM.
3. **Measure each stitch without a reference.** Render each image as its own layer at 50%,
   compute DIS optical flow between overlapping layers on textured pixels only, and report the
   median, p90 and p99 misalignment in full-resolution pixels. About 1.2–1.5 px median is the
   noise floor of this measurement. Large p90/p99 values point at parallax or moved objects,
   which the seams must avoid.
4. **Ghost check** (built in, see above).

Results on the 2-image reference sets (HFOV fixed, outliers cleaned):

| Set | Reference CP mean / max | pcbstitch CP mean / max | Overlap misalignment median (ref / new) |
|---|---|---|---|
| PCB2 back | 1.25 / 3.18 | 1.09 / 2.36 | 1.31 / 1.39 |
| PCB2 front norf | 0.84 / 2.67 | 0.86 / 2.68 | 1.26 / 1.24 |
| PCB2 front withrf | 3.26 / 17.05 | 0.74 / 1.52 | 1.57 / 1.63 |
| PCB3 back norf | 1.35 / 4.45 | 1.12 / 3.72 | 1.16 / 1.26 |
| PCB3 back withrf | 0.83 / 4.14 | 0.61 / 1.63 | 1.29 / 1.44 |
| PCB3 front norf | 1.65 / 4.71 | 1.51 / 4.60 | 1.38 / 1.34 |
| PCB3 front withrf | 3.09 / 6.57 | 2.65 / 6.40 | 2.81 / 3.46 |
| PCB5 back | 1.13 / 3.77 | 1.06 / 3.71 | 1.49 / 1.65 |
| PCB5 front norf | 9.32 / 48.41 | 0.91 / 2.39 | **6.44 / 1.31** |
| PCB5 front withrf | 5.67 / 41.74 | 0.96 / 2.32 | 2.05 / 1.66 |

The table comes from the earlier enblend-based version of the pipeline. The current
`pcbstitch` gives 0.68 px mean on PCB5 front norf and 1.28 px on PCB2 back.

- **Visual agreement:** seven of the ten sets agree with the reference to about 1.5 px or better
  after alignment (mostly under 1 px), with SSIM 0.93–0.99.
- **Where they disagree:** the sets that differ are the ones whose reference projects had the
  large control-point errors, and the overlap check favours the new stitch on them.
- **Parallax remains:** "withrf" sets (with RF shields fitted) keep large p99 misalignment in
  both versions, because the shields sit well above the board.

3-shot router board (black PCB, loose antennas and coax):

| Side | CP mean / max | Ghost pixels (enblend → routed seams) |
|---|---|---|
| front | 1.14 / 2.99 | 0 → 610 scattered, no regions |
| back | 1.03 / 2.89 | 337,509 in 30 regions → about 2,100 in 2 small regions on a tall label |

---

## Shooting tips

Things that made stitching harder in practice:

- **Overlap.** Overlap neighbouring frames by about a third or more, and shoot in a single row
  or column if you can. The routed-seam blender is built for that.
- **Keep the setup fixed.** Keep the camera height and focus fixed across a set, and move
  either the camera or the board, not both.
- **Tape down loose parts.** Antenna boards, coax and foam pads that shift between frames cause
  the worst artefacts. Tape them down or remove them for the stitched shot.
- **Expect parallax on tall parts.** Tall parts (shields, electrolytics, connectors, labels on
  blocks) will never align perfectly at macro distance. More overlap gives the seam room to go
  around them.
- **Pass only the strip's photos.** The script skips a frame that is completely covered by the
  others, but it's better not to pass extra shots at all. Running `pcbstitch *.ARW` in a folder
  that also holds a close-up taken another day added that close-up as a fourth frame. The antenna
  boards had moved since, which left a fragment of one in the stitch.
- **Shoot extra frames for unreadable chips.** If chip markings don't show, take one more shot
  with the light at a low angle across the chip (or the camera refocused on its top), and pass it
  with `--detail`. Only the areas where it shows more detail are used.
- **Retakes.** If you pass both a frame and its retake, the redundancy check drops one of them,
  preferring the less sharp one. In one set the retake was 3–8× less sharp (variance of
  Laplacian) than the original. To check yourself:
  ```python
  import cv2; print(cv2.Laplacian(cv2.imread("frame.png", 0), cv2.CV_64F).var())
  ```
- **Order the files.** Name or pass the frames in order along the strip. The middle one becomes
  the anchor, which spreads the error both ways.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `has no focal length in EXIF` | the input was exported without EXIF. Pass `--focal` (and `--crop-factor`) or `--fov`. |
| `images could not all be connected` | too little overlap, frames in the wrong set, or a featureless area. Check the order and overlap; try `--points 6`. |
| High mean error (> 2–3 px) | parallax or moved objects dominating. Check `<name>_stitched.log` for how many points the planar filter kept per pair. A lower `--ransac-px` is stricter. |
| Ghost regions in the summary | use `--qa-image` to see them. Often a tall part or a moved cable inside the overlap with no clean path round it; more overlap or re-shooting helps. Try `--band 12` for a tighter seam. |
| `photos were taken at different times` | the frames come from different sessions; anything loose may have moved. Prefer frames from one session. |
| `skipping X: its whole area is covered` | X added no new area, so it was left out. Usually an extra shot passed by mistake. If X was taken to show detail (e.g. chip markings), pass it with `--detail X` instead; `--keep-redundant` would blend it in everywhere. |
| `X: no area with more detail than the stitch; not used` | the `--detail` frame didn't show clearly more fine detail anywhere, or only where things had moved. Check that it really shows the markings better, and that it covers the chip. |
| Board appears rotated | raws: `--rotate 90/180/270` (applied at development; use `--redevelop` if PNGs exist). |
| `photometric optimisation failed` | too few points for vig_optimize; the stitch continues without exposure correction. |
| Frames get darker towards their edges, with visible bands | the photos weren't developed with a lens (vignetting) correction. Add `--vignetting`. |
| 2D grid of shots | `auto` falls back to enblend; check the result for ghosting. |
| Want to edit in the Hugin GUI | open `<name>_stitched.pto`. Hugin renders it with enblend, not the routed seams. |

## Limitations

- **Flat subjects only.** The model is a flat mosaic, so anything far off the board plane will
  show parallax.
- **Single row or column for routed seams.** Grids use enblend, which is untested on real grid data.
- **Uniform lens.** It assumes one lens and focal length for all frames, as `pto_gen` groups
  frames by EXIF.
- **Memory.** Full-resolution layers are kept in memory, about 1–2 GB for three 24 MP frames.
- **The `.pto` doesn't record routed seams.** It holds the alignment and photometrics only.
