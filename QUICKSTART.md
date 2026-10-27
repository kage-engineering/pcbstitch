# Quick start

[日本語版はこちら](QUICKSTART.ja.md) · For the details, see the [README](README.md).

`pcbstitch` turns several overlapping photos of a circuit board into one large, sharp image.

## 1. Install (once)

The steps below are for Linux.

**Arch / CachyOS**
```
sudo pacman -S git hugin enblend-enfuse rawtherapee uv
```

**Ubuntu / Debian**
```
sudo apt install git hugin-tools enblend rawtherapee
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then download pcbstitch and make the `pcbstitch` command available:
```
git clone https://github.com/kage-engineering/pcbstitch.git
mkdir -p ~/.local/bin
ln -s "$PWD/pcbstitch/pcbstitch" ~/.local/bin/pcbstitch
```
Open a new terminal and check that it works:
```
pcbstitch --help
```
The first real run takes a little longer, because it downloads a few Python packages.

## 2. Take the photos

- **One row or column.** Shoot one side of the board in a straight line of photos, top to
  bottom or left to right, with each photo overlapping the next by about **one third**.
- **Keep the camera fixed.** Keep the camera height and focus the same for every photo.
- **Don't touch loose parts.** Leave cables, antenna boards and pads alone between shots, or
  tape them down.
- **Name the files in order** (for example `front1`, `front2`, `front3`) and keep only one
  good photo of each position.

## 3. Stitch

Go to the folder with the photos and list them in order:
```
cd ~/Pictures/myboard
pcbstitch front1.ARW front2.ARW front3.ARW
pcbstitch back1.ARW back2.ARW back3.ARW
```
Sony `.ARW` and other raw files are converted to PNG automatically, into a `png/` folder.
You can also pass PNG, TIFF or JPEG files directly.

The result goes into a `stitched/` folder:
```
myboard/
├── front1.ARW  front2.ARW  front3.ARW ...
├── png/                    ← converted photos
└── stitched/
    ├── front_stitched.png  ← the result
    ├── front_stitched.pto  ← Hugin project
    └── front_stitched.log  ← details, if something goes wrong
```

## 4. Check the result

At the end it prints something like:
```
done: front_stitched.png 5942x8406
  control points 132, mean error 1.14px, max 2.99px
  ghost pixels 610 in 0 region(s)
```
- **mean error around 1 px, max under about 4 px:** good.
- **0 region(s):** no visible stitching mistakes.
- **If there are regions**, run again with `--qa-image` and open `stitched/front_qa.jpg`.
  Problem areas are marked in red. Usually something moved between shots: re-take the photos
  and keep loose parts still.

Always look at the image yourself too, especially where the photos overlap.

## 5. Useful options

| Option | When |
|---|---|
| `--rotate 180` | the board came out upside down (also 90 / 270). Add `--redevelop` if the PNGs already exist |
| `--name board_front` | choose the output name (`board_front_stitched.png`) |
| `--qa-image` | save a picture showing problem areas |
| `-o DIR` | put the result somewhere else |

`pcbstitch --help` lists everything.

## 6. Problems?

| Message | What to do |
|---|---|
| `missing tools: …` | install the tools from step 1 |
| `need at least two images` | give it two or more photos |
| `images could not all be connected` | the photos don't overlap enough, or they are from different sides. Check the order and the overlap |
| `has no focal length in EXIF` | the photos have no camera information. Add `--focal 90` (your lens's focal length) |

If you're still stuck, send the `.log` file from the `stitched/` folder to whoever maintains this tool.
