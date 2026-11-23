# Artist package: developer notes

The outside artist receives a generated folder, not the repository. Everything
artist-facing is plain language; the technical contract stays in
[environment_art_packs.md](../environment_art_packs.md).

## Sources (edit these, then rebuild)

- `START_HERE.txt`: the one-page instructions at the top of the package.
- `rooms/NN_<room id>.txt`: one brief per room. The file name sets the folder
  number and the art room id; the first line is the room name shown to the artist.
- `doorways.txt`: instructions for the 12 travel doorways.

## Build the package

```text
pip install pillow
python tools/build_artist_package.py build --out <new empty folder> --zip
```

Each room folder gets the current background at 900 x 430 (the art is drawn at
2x pixel scale, so this is lossless), a transparent guide layer, a labelled
"what goes where" preview, the building exterior as color reference, its
animation PNGs, and `brief.txt` with an animation list generated from the
manifest. Guides come from `data/environments/placement_surfaces.json` with
`developer_placement_overrides.json` applied, so rebuild after placement changes.
Guide rectangles are hit/contact rectangles, not exact silhouettes.

## Bring a delivery back

```text
python tools/build_artist_package.py import --from <delivered folder> --dry-run
python tools/build_artist_package.py import --from <delivered folder>
python -B tools/check_environment_art_pack.py --all
```

`import` reads `Rooms/NN */background.png` (900 x 430, scaled 2x with nearest
neighbor; 1800 x 860 is accepted as is), writes
`assets/art/environments/<id>/background.png`, and re-crops every counter front
from the new background at its placement rectangle plus manifest bleed (current
fronts are exact opaque crops). Changed animation PNGs and doorways are copied
only when their file name and pixel size match the existing file. It rejects
transparency and wrong sizes, and never edits manifests, placements or code.
After importing, review each room in Settings > Environment Library and follow
the liveness and QA rules in `AGENTS.md`.
