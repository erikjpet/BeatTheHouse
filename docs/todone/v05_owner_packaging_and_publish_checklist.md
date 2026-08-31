# Owner Checklist — Package and Publish Beat the House 0.5.0

Last reconciled: 2026-08-12
Status: GITHUB 0.5 RELEASE APPROVED AND EXECUTED

## Authority boundary

This checklist records final release actions. It does not authorize an agent
to upload itch artifacts, publish a GitHub Release, or push a tag. The owner
did explicitly authorize committing and pushing the complete 0.5 source to a
GitHub integration branch on 2026-08-12.

## Entry conditions

- [x] Final owner release approval was provided on 2026-08-12.
- [x] The complete source worktree is approved for GitHub integration.
- [x] The release commit is clean and on the intended remote.
- [x] The owner accepts the tested baseline for the playtest event.
- [x] Copy, screenshots, changelog, limitations, safety framing, platforms, and
  the collection `draft` decision are approved.

## Build and verify artifacts

- [x] Build Web and Windows from the exact approved commit.
- [ ] Record tool versions, commands, timestamps, filenames, sizes, and
  SHA-256 hashes.
- [x] Confirm version 0.5.0 and absence of debug-only, profile, secret, test,
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

- [x] Confirm approved source exactly matches published artifacts.
- [x] Create annotated `v0.5.0` at that exact commit and push it.
- [x] Publish the approved GitHub release and intended artifacts.
- [x] Verify public tag, archives, notes, and hashes.
- [ ] Itch publication remains separate and was not requested in this action.

## Close release records

- [x] Update README/CHANGELOG from development to published status.
- [ ] Record commit, tag, URLs, timestamps, hashes, approval, and limitations in
  `docs/plans/0.5_release_checklist.md`.
- [ ] Add an execution record and archive this checklist.
- [ ] Mark the 0.5 queue complete only when no active blocker remains.

## Abort rule

At any defect, identity mismatch, failed verification, or owner concern, stop.
Do not retag, overwrite artifacts, or weaken evidence. Open a new active TODO,
approve a new RC after the fix, and rebuild affected artifacts.
