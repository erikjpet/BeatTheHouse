# Owner Checklist — Package and Publish Beat the House 0.5.0

Last reconciled: 2026-08-05
Status: NOT STARTED / OWNER-CONTROLLED EXTERNAL ACTIONS

## Authority boundary

This checklist records final release actions. It does not authorize an agent
to upload artifacts, publish pages/releases, or push a tag. Each external
action requires the owner's explicit request or direct execution.

## Entry conditions

- [ ] `v05_final_release_candidate_approval_prompt.md` is archived complete.
- [ ] The approved RC commit is recorded, clean, and on the intended remote.
- [ ] Every final gate and owner playtest is green.
- [ ] Copy, screenshots, changelog, limitations, safety framing, platforms, and
  the collection `draft` decision are approved.

## Build and verify artifacts

- [ ] Build Web and Windows from the exact approved commit.
- [ ] Record tool versions, commands, timestamps, filenames, sizes, and
  SHA-256 hashes.
- [ ] Confirm version 0.5.0 and absence of debug-only, profile, secret, test,
  and unrelated files.
- [ ] Test Web with production headers, 1280x720 embed,
  fullscreen, audio, save, and reload.
- [ ] Test the packaged Windows build on a clean profile.
- [ ] Repeat critical fresh-profile tutorial, both routes, Replay Lessons,
  normal-run handoff, all-game smoke, Grand Casino, Scratch Tickets, save/load,
  and run-end flows from packaged artifacts.
- [ ] Stop and open a new defect TODO if any crash, hang, stutter, frozen idle,
  missing asset, dead click, stale overlay, clipped text, or mismatch appears.

## Publish to itch.io — explicit owner authorization required

- [ ] Upload Web to `html` with user version `0.5.0`.
- [ ] Upload Windows to `windows` with user version `0.5.0`.
- [ ] Configure browser play, 1280x720, and fullscreen. SharedArrayBuffer is optional.
- [ ] Publish approved copy, screenshots, safety framing, and platforms.
- [ ] Test the live page and downloaded Windows artifact.
- [ ] Record URLs, channel/build IDs, timestamps, and artifact hashes.

## Publish GitHub release/tag — explicit owner authorization required

- [ ] Confirm approved source exactly matches published artifacts.
- [ ] Create annotated `v0.5.0` at that exact commit and push it.
- [ ] Publish the approved GitHub release and intended artifacts.
- [ ] Verify public tag, archives, notes, and hashes.
- [ ] Confirm itch and GitHub share version/source identity.

## Close release records

- [ ] Update README/CHANGELOG from development to published status.
- [ ] Record commit, tag, URLs, timestamps, hashes, approval, and limitations in
  `docs/plans/0.5_release_checklist.md`.
- [ ] Add an execution record and archive this checklist.
- [ ] Mark the 0.5 queue complete only when no active blocker remains.

## Abort rule

At any defect, identity mismatch, failed verification, or owner concern, stop.
Do not retag, overwrite artifacts, or weaken evidence. Open a new active TODO,
approve a new RC after the fix, and rebuild affected artifacts.
