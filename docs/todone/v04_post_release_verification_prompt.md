# Execution Record (2026-07-09)

- Claimed in `docs/todo/QUEUE.md` and pushed as commit `4721ff3`.
- Preconditions verified:
  - `docs/todone/v04_publish_and_tag_prompt.md` has an execution record.
  - `docs/plans/0.4_release_checklist.md` has the Published section with the
    pushed commit, tag, package hashes, and owner itch upload instructions.
- Live itch check:
  - Checked `https://beatthehouse.itch.io/beatthehouse`.
  - The live page was not serving the 0.4.0 release artifacts yet: it still
    exposed the older devlog trail through `v033`, showed an older update
    state, listed `BeatTheHouse-web.zip` around 15 MB instead of the
    17,177,826-byte 0.4.0 Web zip, and did not expose the expected Windows zip.
  - Per this prompt's fallback rule, live-page verification is pending the
    owner's manual itch upload and the exact packaged zips were verified
    locally instead.
- Web package verification:
  - `builds/itch/BeatTheHouse-web.zip` SHA256 matched
    `E364B27C765D8B82B6C525A1CDF248D013BDE69BD1643D104E48883256816F71`.
  - Extracted the hash-matched Web zip to `.tmp/post_release_live_web/web_zip`.
  - Served the extracted package with COOP/COEP headers and ran
    `tools/l02_web_perf_probe.mjs` using `bth_perf_plan=l02`, Chrome headless,
    4x CPU throttle, 45 idle frames, 60 active frames, and 20 memory seconds.
  - PASS; report `.tmp/post_release_live_web/web_zip_report.json`, ready wall
    time 15,411ms / 20,000ms, 20 scenarios captured, budget audit PASS.
- Windows package verification:
  - `builds/itch/BeatTheHouse-windows.zip` SHA256 matched
    `2D40849FF927EB47772A889D8F5735D7CAABE3D24030493A480C4729B90EA363`.
  - Scratch unzip to `.tmp/post_release_windows_zip` produced
    `BeatTheHouse.exe` and `BeatTheHouse.pck`.
  - `BeatTheHouse.exe` file/product versions both reported `0.4.0`.
  - Scratch executable launched, exposed a responding `Beat the House` window,
    and closed cleanly through the normal close request.
  - Limitation: Windows Graphics Capture failed on the Godot window with
    `SetIsBorderRequired failed: No such interface supported (0x80004002)`, so
    menu/game-surface screenshot automation could not be completed without
    blind input.
- Fresh screenshot assets:
  - Ran `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe --path .
    --script res://tools/environment_layout_screenshots.gd --
    --out=D:\Projects\Beat-The-House\.tmp\post_release_screenshots
    --meta-home-review`; PASS, `META_HOME_LAYOUT_SURVEY_DONE`.
  - Captured `branding/screenshots/11_meta_home_back_alley.png`.
  - Captured `branding/screenshots/12_dialogue_talk_dock.png` with a temporary
    `.tmp` dialogue fixture script.
- Devlog/social:
  - Updated `tools/generate_devlog_social.py` for `v0_4_0`, "DEVLOG #4", and
    "v0.4 IS OUT".
  - Generated `branding/social/beat_the_house_v0_4_0_instagram.png`,
    `branding/social/beat_the_house_v0_4_0_instagram_mobile.png`, and
    `branding/social/beat_the_house_v0_4_0_instagram_mobile.jpg`.
  - Added `docs/plans/0.4_devlog_post.md`; posting remains the owner's action.
- Closeout:
  - Appended Post-Release Verification to
    `docs/plans/0.4_release_checklist.md`.
  - Marked `docs/plans/0.4_act1_completion_plan.md` SHIPPED with tag `v0.4.0`.
  - Updated `docs/todo/QUEUE.md` to close the 0.4 queue pending the owner's
    next planning pass.
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`:
    PASS.
- Deviations: live itch verification could not be completed because the live
  page was not yet serving the 0.4.0 packages; the prompt explicitly allowed
  hash-verified local package verification in that case. No devlog posting was
  performed.

# Agent Prompt - v0.4 Post-Release Verification And Devlog #4 Assets

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). The 0.4.0 release is pushed to GitHub (see the
"Published" section of `docs/plans/0.4_release_checklist.md`) and the owner
uploads the zips to itch manually. This task verifies the release players
actually receive and produces the devlog assets. Publishing the devlog
post itself remains the owner's action.

## 1. Verify the shipped builds (what players download, not the local tree)

0. **Precondition:** check whether the itch page is serving 0.4.0 yet (the
   owner uploads manually). If not yet live, verify the exact packaged
   zips from `builds/itch/` instead (hash-match them against the checklist
   first), state clearly in your report that live-page verification is
   pending the owner's upload, and continue with everything else.
1. **Web:** drive the live itch page if 0.4.0 is being served (or the
   hash-verified web zip hosted locally with the same COI headers the web
   smoke harness uses) through headless Chrome via the
   `tools/web_perf_smoke.ps1` infrastructure: boot to menu, start a run,
   one table hand with a talk event, open the meta home room, verify audio
   starts after first input. Record frame p95 for the boot/menu scenario
   against the performance-pass report's numbers.
2. **Windows:** unzip the published `BeatTheHouse-windows.zip` to a scratch
   directory, launch the exe, reach the main menu and a game surface, exit
   cleanly. Confirm the version string shows 0.4.0.
3. Any discrepancy between shipped behavior and the release checklist is a
   release defect: report it immediately and clearly at the top of your
   summary — do not bury it. Hotfix decisions belong to the owner.

## 2. Devlog #4 assets

1. Update `tools/generate_devlog_social.py`'s DEVLOG config for 0.4.0
   (tag `v0_4_0`, kicker "DEVLOG #4", hero "v0.4 IS OUT") using the 0.4
   headline features from `docs/plans/0.4_publish_copy.md` — home &
   housing progression, collections/bags, dialogue & talk, day/night
   venue hours, world map travel pricing, stability. Choose panel
   screenshots that show the NEW systems (capture fresh ones through the
   layout-screenshot/visual-QA tooling if branding/screenshots lacks them —
   at minimum the walkable home room and a dialogue in the talk dock).
2. Generate the 1080 card + 720 mobile variants into branding/social/ with
   the established naming (`beat_the_house_v0_4_0_instagram*`).
3. Assemble the final devlog text at `docs/plans/0.4_devlog_post.md` from
   the publish copy: title, body, feature list, and the image filenames to
   attach. Match the voice of the committed style guide.

## 3. Close the loop

1. Update `docs/plans/0.4_act1_completion_plan.md` status line to SHIPPED
   with the publish date and tag.
2. Verify QUEUE.md is empty of ready entries and states that the 0.4 cycle
   is closed pending the owner's next planning pass.

## Done gate

- Live web and Windows builds verified with results recorded in a
  "Post-Release Verification" section appended to the 0.4 release
  checklist.
- Devlog card + mobile variants generated; devlog post text ready for the
  owner.
- Plan marked SHIPPED; queue clean.
- Prompt archived to docs/todone/ with an execution record. Commit locally
  and push (this task remains covered by the owner's publish
  authorization); publishing the devlog post is the owner's action.
