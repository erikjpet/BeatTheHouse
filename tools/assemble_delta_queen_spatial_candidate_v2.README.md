# Delta Queen V2 perspective assembly

CODE ONLY until the parent runs and independently reviews a fresh guarded assembly.
The V1 package and recipe remain immutable and rejected for DELTA-V1-TOP-PLANE.
This recipe changes only the left table pixels in the background. It preserves
the original right cabinet/master crop, its opaque540x184 PNG, all26 motions,
the full room JSON, separate global index, gameplay anchors and draw order.

## Source-specific geometry

All coordinates below are native1800x860 pixels; board coordinates are halves.

| Part | Native geometry |
| --- | --- |
| Far rim | x124..676, y352..358 |
| Felt band | y358..476; left outer124→64, right outer676→712 |
| Side rail | Actual traced source material fitted to eight native pixels |
| Near rim | x64..712, y476..488 |
| Quiet apron | x72..704, y488..516 |
| Left support | [200,516,56,24] |
| Right support | [620,516,36,24] |

The fully opaque original right cabinet begins at native x660,y340. The complete
logical right table edge is behind it; every destination x660 onward remains
original. This is an explicit physical occlusion. The recipe does not fabricate
the V1 two-pixel vertical right rail. The visible left edge converges by59 native
pixels across its118 felt rows, with a distinct rear rim, near rim and apron.
Each raw felt row is fitted to the converging target interval with nearest-neighbor
sampling. The outer green reflection is distinguished from the main felt: the
inner interval is the longest contiguous green run; the outer interval starts
at the first actual green/brass table texel, excluding adjacent redwood wall.
The variable-width physical source rail fits eight native target pixels; this
does not claim eight source pixels. The right rail is occluded. This is explicit
row-wise module fitting, not a single affine X map for the entire raw canvas.

Raw far-rim rows363..373 use their own traced physical intervals, excluding
the confirmed wall-only row360 and almost empty361. Inner felt uses374..437;
near contact rim438..459 uses its own traced intervals rather than a rectangle
that includes room pixels outside curved corners. The source apron conservatively
insets from123..630 at raw464 to129..626 at489. Every actual interval and donor
is recorded for independent reconstruction. Isolated source supports fit below.

The actual Blackjack generic contact rectangle is [122,396.08,184,53.76]. The
Roulette contact rectangle is [466.96,391.11994,190.08,43.2]. Exact typed surface
pigments have already been traced in all six retained scenes. Raised cards,
wheel/riser and soft highlights are distinct from their horizontal contact
surfaces; whole-prop alpha is not falsely required to lie on the felt.

For a left edge from124 at y358 to the near endpoint at476, the continuous
minimum Blackjack felt margin is15.81695 native pixels at near-left44,
9.36271 at64,6.78102 at72 and2.90847 at84. The recipe's inward pixel-edge
quantization gives minimum full-contact pixel-center margins16,9,6 and3.
Near-left68 is the least expansion that still gives an eight-native-pixel
margin;64 adds four native pixels of safety and a clearer visible taper.44
adds twenty native pixels of near-edge overhang beyond64 without a paint need.
The selected64 therefore avoids that unnecessary extension.

The right logical felt starts at least668, behind the cabinet, while the
Roulette face ends657.04. There is adequate logical felt beyond the contact
paint; the visible cabinet adjacency is explicitly left to actual art review.
The complete old panel [128,356,476,160] lies under the new physical silhouette.
There are no newly exposed wall triangles and no guessed repeating wall donor.

## Supports and deck

An independent read-only scan of all232 original typed body/adornment masks
found common alpha-zero runs [194,278) and [616,660) throughout y516..539.
The selected supports lie inside them with6/22 native pixels of left-post
clearance and4/4 native pixels around the right post. The recipe still decodes
and checks every actual mask at every selected support texel before writing;
the prior scan does not replace that assertion. The supports retain quiet dark
source timber, complete soles and contiguous apron connections.

Logical apron overhang is128 native pixels before the left post and48 after
the right post. The right cabinet hides the latter edge, leaving four visible
native pixels after the right post. These asymmetric supports and overhangs
require integrated actual-pixel/depth review; no numeric pass approves them.

Only the proven old green bottom [128,516,476,8] is restored using the pinned
R3 same-X dry-deck donor. The original1568-texel row-pair calibration and full
524/526 calibration are retained. Native rows526..527 are a global deck seam,
preserved everywhere outside actual supports. All rows540 onward stay exact.

## Custody and execution contract

Run only inside the parent's admitted E workspace and maintained capped Job.
The worker requires the prepared bth_qa_storage manifest before its first write,
revalidates declared output paths, launches no child and never chooses C storage.
It writes a fresh `delta-queen-spatial-r1-assembled-v2` package and
`delta-queen-spatial-r1-assembly-v2.json` evidence. Existing V1, raw sources,
baseline and exact sentinels are read and preserved; no overwrite or cleanup.

The original4a604 recipe, rejected V1 package/proof/closed Job and d124 static
NO-GO review are pinned and rehashed before/after. Every final written texel
records its raw donor and component; source/hash maps cover the complete
widened union. The new report retains all29 logical files, all232 mask checks,
the original R3 calibration and exact right replay proof. Only the background
payload may differ. Both input source and historical custody are rechecked.

The fifteen focused tests are pure geometry/contact/material/occlusion regressions. They do not
execute assembly, read historical images, write files or imply source-art GO.
Root may run them through its guarded worker with Python310:

```text
python.exe -B tools/test_assemble_delta_queen_spatial_candidate_v2.py
```

Static review precedes a fresh guarded assembly. Actual assembled pixels must
then pass independent art review, followed by fresh populated six-context,
selection/depth,26-motion/Reduce Motion, original no-pointer liveness and
actual-clock capture qualification. No native or TEST approval is implied here.
