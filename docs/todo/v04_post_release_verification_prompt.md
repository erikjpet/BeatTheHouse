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
