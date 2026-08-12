# Heat Gain Feedback — Research and Proof of Concept

Research-only review artifact. No game code or production assets were changed for this pass.

## Recommendation

Use a three-part, non-directional "damage" response whenever the player's current-location Heat actually increases:

1. A restrained dark-crimson/coral vignette appears at the outer edges of the whole screen.
2. The existing Heat icon, value, and segmented meter receive a bright outline/glow pulse.
3. A small `+N HEAT` badge appears directly beneath the Heat meter.

The second and third parts are important. A red edge effect alone can be missed, can blend into the nighttime palette, and communicates only that something bad happened—not what changed or by how much. Heat is not directional, so shooter-style directional wedges or arrows would communicate information the game does not have.

The recommended target is shown in the day and night screenshots:

- `02_recommended_day_edge_meter_delta.png`
- `03_recommended_night_edge_meter_delta.png`

`01_edge_vignette_and_meter_pulse.png` is the simpler version without a numeric delta. It is more atmospheric, but less clear.

## Suggested Animation

- **0–80 ms:** edge opacity rises quickly; Heat meter outline switches to hot coral.
- **80–180 ms:** brief hold at peak intensity.
- **180–850 ms:** edge vignette fades smoothly to zero.
- **0–700 ms:** `+N HEAT` badge remains fully readable.
- **700–1,050 ms:** badge and meter pulse fade away.

Keep the vignette peripheral: approximately the outer 8–12% of the screen, with the center untouched. Use a dark, slightly desaturated red rather than a bright saturated-red full-screen flash. Intensity can increase modestly with the applied Heat amount, but it should be capped so large gains do not obscure play.

Repeated gains should restart or extend one animation and combine the displayed delta inside a short window. They should not create several separate flashes in rapid succession.

## Accessibility Guardrails

- Do not rely on red alone. The `+N HEAT` text and the meter's changing segments provide shape/text/value reinforcement.
- Pair the visual with one short Heat-specific audio sting during implementation. Controller haptics may be an optional third channel, never the only cue.
- Provide a reduced-effects behavior: omit the full-screen vignette and show only the static meter outline plus `+N HEAT` badge for about one second.
- Avoid high-contrast or repeated full-screen flashes. Microsoft specifically applies stricter criteria to saturated-red flashes and recommends reducing saturation, contrast, frequency, and affected screen area.

## What Implementation Would Require

The existing project already exposes most of the necessary data and presentation structure:

- `RunState.add_suspicion()` calculates the **actual applied Heat**, including caps and modifiers. This is the correct source for one centralized positive-Heat event.
- `FoundationHudViewModel` already includes `heat_delta` in the HUD model.
- `FoundationHudBar` owns the Heat value and segmented meter, so it can display the pulse and numeric badge without duplicating Heat state.
- The project already uses a full-screen `ColorRect` shader pattern for drunk distortion. A Heat overlay would be simpler: a mouse-ignoring full-rect presentation layer with one vignette intensity parameter and a short Tween.

A robust implementation would add one presentation-only Heat feedback controller at the shared application layer, connect it to actual positive local Heat changes, and ask the HUD bar to pulse. It should not be tied only to game-result panels, because Heat can come from games, conversations, travel, events, items, and other actions.

Expected production scope is small to moderate: one overlay/controller, a small HUD-bar extension, one centralized event hook, accessibility setting behavior, and regression/screenshot tests. No environment art needs to change.

## Cases to Test Before Shipping

- Heat gained from every source category triggers exactly once.
- Heat cooling or a zero/blocked gain does not trigger.
- The displayed number uses applied Heat, not requested Heat at the 100 cap or during modifiers.
- Rapid consecutive gains coalesce without repeated flashing.
- The cue remains readable in bright noon and dark neon scenes, in games, environments, conversations, and menus that can receive a result.
- Reduced effects removes the edge flash while preserving the meter and numeric cue.
- The overlay never consumes mouse/controller input and never becomes part of save data.

## Research Basis

- Microsoft Xbox Accessibility Guideline 103 uses damage indicators as an example of important on-screen feedback and recommends representing critical information through more than one sensory channel and more than color alone: https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103
- Microsoft Xbox Accessibility Guideline 118 recommends reducing the saturation, contrast, frequency, and affected area of red flashes: https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/118
- The University of Manitoba HCI study compared a red flash with more informational damage displays. Players found injury information useful, while peripheral or obstructive indicators could be missed or interfere with play: https://hci.cs.umanitoba.ca/projects-and-research/details/embodied-damage-indicators-in-fps
- Godot's documented 2D post-processing structure is a full-rect `ColorRect` on a `CanvasLayer`, and a Tween is appropriate for a short property fade: https://docs.godotengine.org/en/4.5/tutorials/shaders/custom_postprocessing.html and https://docs.godotengine.org/en/4.0/classes/class_tween.html

## Mockup Method

The three screenshots were created as non-production raster UI mockups with the built-in image-generation editor, using the existing Grand Casino day/night screenshots as edit targets. Their purpose is to judge cue composition and intensity; implementation should render the effect from the real unchanged UI rather than use these screenshots as assets.
