# Beat the House 0.6 itch.io theme

## Upload these files

| itch.io field | File |
| --- | --- |
| Cover image | `01_cover_logo.png` |
| Banner | `00_itch_banner.png` |
| Background | `00_itch_page_background.png` |
| Embed BG | `00_itch_embed_background.png` |
| Screenshots, in order | `02_environment_blue_note.png`, `03_environment_grand_casino.png`, `04_blackjack_in_action.png`, `05_roulette_live_spin.png`, `06_logo_background.png` |

## Theme values

### Color

| Field | Value |
| --- | --- |
| BG | `#05060A` |
| BG 2 | `#0B0B18` |
| Text | `#D8E8EA` |
| Link | `#00F5FF` |
| More options: Buttons | `#FF2D78` |
| More options: Headers | `#FF2D78` |
| More options: BG 2 Alpha | `96%` |

### Text

| Field | Value |
| --- | --- |
| Font | `Lato` |
| Size | `Large` |
| Header font | `Press Start 2P` |

### Layout

| Field | Value |
| --- | --- |
| Screenshots | `Sidebar` |

### Images

| Field | Value |
| --- | --- |
| Banner | Upload `00_itch_banner.png` |
| Banner align | `Center` |
| Background | Upload `00_itch_page_background.png` (3840x2160) |
| Background repeat | `No repeat` |
| Background align | `Center` |
| Background fixed | `On` |

### Embed BG

| Field | Value |
| --- | --- |
| Image | Upload `00_itch_embed_background.png` |
| Color 1 | `#05060A` |
| Color 1 Alpha | `42%` |
| Color 2 | `#101427` |
| Color 2 Alpha | `58%` |

If itch.io exposes only one Alpha control for the embed gradient, use `50%`.

## Rationale

- The banner, cover, and embed use the exact transparent logo displayed by the 0.6 main menu at `assets/art/ui/beat_the_house_logo.png`.
- The colors are the live 0.6 visual tokens: near-black and navy surfaces, cyan interaction, magenta pressure, and soft blue-white text.
- The 4K page background reserves a feathered 1840-pixel center corridor for the live 1600-pixel itch.io game frame. Its full-canvas room art and edge fades prevent visible cutoff or empty strips without requiring unsupported background scaling.
- The 1600x900 embed image exactly matches the game's current itch.io frame and leaves a dark center for the Play button.
- Text, cyan links, and magenta headings all exceed a 4.5:1 contrast ratio against `#0B0B18`.
