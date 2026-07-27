# Agent Prompt — Produce a Finalized ~60s Gameplay Trailer

Copy everything below this line into the agent. This is a heavier
creative+technical task; use a capable model.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (neo-noir, neon, roadside-to-high-roller gambling). Your job is
to PRODUCE A FINISHED, POLISHED ~60-SECOND GAMEPLAY TRAILER as an actual
video file — using the game's OWN music, REAL in-engine gameplay footage,
and cut-to TITLE CARDS that name the game's pillars and sell its neo-noir
neon-futuristic-gambling theme. This is a marketing deliverable, not a
gameplay code change. Deliver a file a person can upload to itch.io /
YouTube and get players excited.

You will do original RESEARCH into what makes a great game trailer and let
it drive the edit. Do not settle for a rough draft; iterate until it is
genuinely good.

## Definition of done

- `branding/trailer/beat_the_house_trailer_1080p.mp4` — H.264, 1920×1080,
  ~55–65s, the game's music as the audio bed, real gameplay footage, and
  themed title cards, hard-cut/beat-paced, ending on a clear "play free"
  call to action. Pixel art stays crisp (no blur).
- `branding/trailer/beat_the_house_trailer_vertical.mp4` — a 9:16 social
  cut (~30–60s) derived from the same footage.
- `branding/trailer/beat_the_house_trailer_loop.webm` (or gif) — a short
  silent looping header clip for the itch page (~6–10s).
- `docs/plans/0.5_trailer_production.md` — the research-backed design
  philosophy, the final shot list, the exact regeneration steps, and the
  tooling used, so the trailer can be re-rendered after future changes.

## Preconditions (verify first)

- Confirm the build presents cleanly right now: boot the game and check
  for visible defects or engine errors that would poison footage. Note
  that the 0.5 release queue (`docs/todo/p0_*`, `p1_*`) may still be
  fixing UI regressions (a settings-starts-run bug, a boot viewport
  error). If those are unlanded and visibly hurt capture, either capture
  around them or recommend re-rendering after the p0 queue lands — say
  which in your report. The trailer must show the game's FINALIZED,
  current polished state, not broken surfaces.
- Confirm tooling: Godot 4.6 at
  `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe`; `ffmpeg`
  available (install/locate and state the version); Python+PIL (the
  existing `tools/generate_devlog_social.py` proves it). If a tool is
  missing, resolve it or report the blocker — do not fake a deliverable.

## Phase 0 — Research + design philosophy (write it down)

Research what makes game trailers effective and distill a philosophy you
will actually follow. Cover at least: the first-3-seconds hook; show-don't-
tell (footage over text); escalating pace and cut rhythm; syncing cuts to
music beats/hits; the role and brevity of title cards (name the pillars,
don't explain them); readability at small sizes; the ~60s structure
(hook → what it is → range → tension → climax → CTA); ending on where to
play. Write the philosophy and the resulting edit rules into
`docs/plans/0.5_trailer_production.md`. This research drives every later
choice; cite the principles you apply.

## Phase 1 — Deterministic gameplay footage (Godot Movie Maker)

Capture real footage from the actual game, deterministically, with the
game's music baked in.

- Build a scripted **trailer-autoplay driver** (a Godot tool script, e.g.
  `tools/trailer_capture.gd`, modeled on the drive-the-real-app pattern in
  `tools/promo_screenshots_0_4.gd`) that plays the game through the trailer
  beats on a FIXED seed: it starts runs, enters rooms, plays hands/spins/
  scratches, travels the map, reaches the Grand Casino, the Cage, a Players
  Card claim, and the Rourke back-room duel — showing the FINALIZED
  features. Each beat is its own captured segment so you can time and
  order them in the edit.
- Render with Godot's **Movie Maker mode** (`--write-movie <file>` with a
  fixed fps, e.g. 60) so output is smooth regardless of real-time speed
  AND the AudioServer output (the game's procedural music + SFX) is
  captured into the render. Run WINDOWED at a clean multiple of the game's
  native resolution so pixel art scales without blur; if you must upscale
  later, use nearest-neighbor in ffmpeg, never bilinear.
- Choose beats/environments whose music energy supports an escalating
  trailer arc (the score is per-environment and reacts to heat/drink — use
  that: calmer roadside rooms early, tense high-heat casino later). If the
  in-engine music cannot carry a clean trailer arc, you may instead render
  a clean gameplay pass and lay a selected in-game music capture under it —
  but prefer authentic captured audio; document the choice.
- Keep all raw renders under `.tmp/trailer/`; never commit multi-GB
  intermediates.

## Phase 2 — Title cards + theme branding

Generate title cards as PNGs in the game's neo-noir neon pixel style
(reuse/extend the PIL pipeline behind `tools/generate_devlog_social.py`:
neon palette, scanlines, glow, the game's logo/identity). Cards, kept
short and punchy:

- Opening title / logo sting.
- 3–4 pillar cards naming the fundamentals (e.g. "EIGHT CASINO GAMES",
  "DODGE THE HEAT", "CHEAT IF YOU DARE", "BEAT THE HOUSE") — words that
  state the pillar, not sentences that explain it.
- Closing CTA card: title + "PLAY FREE IN YOUR BROWSER" + itch.io.

Cards must read the neo-noir neon-futuristic gambling theme instantly and
match the game's visual identity. Store card assets under
`branding/trailer/cards/`.

## Phase 3 — Assembly and edit (ffmpeg)

Cut the finished trailer with ffmpeg from the footage + cards + audio.

- Follow your Phase-0 edit rules and this refined starting beat sheet
  (tighten it against the research and the footage you actually get):

  | ~t | Beat | Content |
  | -- | ---- | ------- |
  | 0–4s | Hook | a tense high-stakes moment (all-in / pit boss watching) → title sting |
  | 4–11s | What it is | roadside neon start, "one bad night on the wrong side of town" energy |
  | 11–24s | The range | fast montage of the eight games (blackjack, roulette, slots, scratch, bar dice, baccarat, video poker, pull tabs) |
  | 24–34s | The tension | heat rising, a lender/debt beat, a skill-cheat, the drunk distortion |
  | 34–46s | The climb | world-map travel, day→night, up to the Grand Casino; the Cage; a Players Card |
  | 46–55s | The boss | Rourke, the back room, the heads-up duel |
  | 55–60s | Title + CTA | logo + "play free in your browser — itch.io" |

- Sync major cuts to the music's beats/hits where possible. Use mostly
  hard cuts with a few tasteful neon/glitch transitions — no cheesy
  crossfade soup. Hold each shot only as long as it reads.
- Grade for consistency with the neon theme (subtle; do not wreck the
  pixel look or crush readability). Optional light scanline/vignette if it
  strengthens the theme.
- Audio: the game's music is the bed. Keep levels consistent; a bass hit
  on the title/CTA is welcome. No copyrighted external music.
- Encode the 1080p H.264 mp4; then derive the 9:16 vertical cut (reframe/
  crop to the action, re-time to ~30–60s) and the short silent loop.

## Phase 4 — QA, iterate, deliver

- Grade the result against a trailer-quality checklist you define in the
  design doc: does it hook in 3s? does pace escalate? are cuts on beat? is
  every title card readable and brief? is the game's identity unmistakable?
  is it ~60s and does it end on a clear CTA? Watch it as a new player
  would. If it is not genuinely exciting, iterate — re-capture or re-cut.
- Verify technical quality: resolution, framerate, no dropped/black
  frames, audio in sync, pixel art crisp, file sizes sane.
- Write the final shot list, the exact commands to regenerate every
  artifact, and the tooling versions into
  `docs/plans/0.5_trailer_production.md`.

## Hard rules

- Real in-engine footage and the game's own audio only; no external/
  copyrighted music; do not fabricate features that do not exist in the
  current build.
- Preserve the pixel art — nearest-neighbor scaling only; never blur.
- Deterministic capture (fixed seed) so the trailer is reproducible.
- Tooling/data changes stay minimal and additive (the capture script, the
  card generator); do NOT alter gameplay to stage footage in a way that
  misrepresents the game. If you add a capture-only helper, gate it so it
  cannot affect normal play.
- Final deliverables under `branding/trailer/`; heavy intermediates under
  `.tmp/trailer/` (never committed). Style: tabs/typed GDScript for any
  script; PS 5.1-compatible for any `.ps1`.
- `tools/validate_project.ps1` must still pass after any tooling changes.

## On completion

Only after the trailer is finished AND you have confirmed it plays
correctly (watch it; verify video+audio+length+quality):

1. Commit the tooling, cards, docs, and the final deliverable video files
   in logical units (state where the mp4s live and their sizes; if the
   owner may not want large binaries committed, stage them under
   `branding/trailer/` but call it out so they can decide).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, tool
   versions, deliverable paths, render commands), and stage the move.
3. PUSH to the remote.
4. Report: the design philosophy in brief, the final shot list with
   timings, the tooling/commands to regenerate, the deliverable paths and
   sizes, any feature you avoided because it was mid-polish, and your own
   honest assessment of whether it is upload-ready or needs another pass.

On a blocker you cannot resolve (missing tool, unusable footage, build not
presentable), stop, do NOT push, and report exactly what is needed.

---

## Execution record — 2026-07-26

Completed and verified.

- Pipeline/cards/design commit: `dc4d2978`
- Final media commit: `fd7d4500`
- Godot: `4.6.stable.official.89cea1439`
- FFmpeg/FFprobe: `8.1.2-full_build-www.gyan.dev`
- Python: `3.12.10`
- Pillow: `10.3.0`
- Windows PowerShell: `5.1.19041.6456`
- Final validation: `tools/validate_project.ps1` PASS; capture-driver smoke
  PASS; PowerShell parse PASS; Python compile PASS; all final videos decoded
  without error.

Deliverables:

- `branding/trailer/beat_the_house_trailer_1080p.mp4` — 39,748,748 bytes,
  H.264 1920×1080 60 FPS, AAC 48 kHz stereo, 60.0 seconds.
- `branding/trailer/beat_the_house_trailer_vertical.mp4` — 26,729,548 bytes,
  H.264 1080×1920 60 FPS, AAC 48 kHz stereo, 45.0 seconds.
- `branding/trailer/beat_the_house_trailer_loop.webm` — 3,166,529 bytes,
  VP9 1920×1080 30 FPS, silent, 8.0 seconds.
- Title-card sources: `branding/trailer/cards/`.
- Full production/QA record: `docs/plans/0.5_trailer_production.md`.

Regeneration:

```powershell
Set-Location D:\Projects\Beat-The-House
.\tools\validate_project.ps1
.\tools\render_trailer.ps1
```

Edit-only rebuild using existing raw Movie Maker captures:

```powershell
.\tools\render_trailer.ps1 -SkipCapture -Force
```

Production decisions/deviations:

- The game-generated Jazz Club 120 BPM arrangement is the continuous music
  bed, captured in-engine through Movie Maker. This prevents environment-score
  resets from clashing between deterministic visual segments.
- Gameplay SFX were not overlaid because each segment's captured audio also
  contains a different environment score. No external audio was substituted.
- Pull-tab peel and baccarat squeeze actions were phase-gated in the short
  deterministic captures; the edit shows their real machine/table states and
  does not force or fabricate outcomes.
- The queued release-identity task still leaves 0.4.0 on the start screen.
  The trailer avoids the start screen and makes no version-number claim.
- The queued boot viewport prompt remained unarchived during production, but
  the capture boot did not reproduce its historical `is_inside_tree` error.
- Heavy intermediates remain under `.tmp/trailer/` and were not committed.
