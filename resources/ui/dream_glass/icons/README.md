# Dream Glass Semantic Icons

This folder contains deterministic SVG icons for the game's rule-instrument UI.
They are structural symbols, not generated illustrations.

## Visual contract

- Canvas: `64 x 64`, transparent.
- Stable objects: ivory `#F4F0FF`.
- Interactive structure: cyan `#59E6DB`.
- Rule mutation: violet `#D27BE5`.
- The upper-left and lower-right broken corners are the shared contract mark.
- Default rendered size is `28-32 px`; do not render below `24 px`.

## Dice faces

- `dice/die_1.svg` through `dice/die_6.svg` represent exact values 1–6.
- The standard pip matrix fills the token; a precise tooltip remains the text fallback.
- All six faces share one frame; only the pip matrix changes.

## Effect mapping

| `EffectSpec.Operation` | SVG |
|---|---|
| `ADJUST_DIE` | `effects/adjust_die.svg` |
| `MODIFY_COEFFICIENT` | `effects/modify_coefficient.svg` |
| `REPEAT_TABLE` | `effects/repeat_table.svg` |
| `REVERSE_RESOLUTION` | `effects/reverse_resolution.svg` |
| `LINK_NEIGHBORS` | `effects/link_neighbors.svg` |
| `SWAP_DICE` | `effects/swap_dice.svg` |
| `COPY_DIE` | `effects/copy_die.svg` |
| `FLIP_DIE` | `effects/flip_die.svg` |
| `LOCK_DIE_WITH_BONUS` | `effects/lock_die_with_bonus.svg` |
| `REFUND_CALIBRATION` | `effects/refund_calibration.svg` |
| `MODIFY_CONDITION` | `effects/modify_condition.svg` |
| `GRANT_INTEL_ON_CONDITION` | `effects/grant_intel_on_condition.svg` |

## Target mapping

| `CardDefinition.TargetType` | SVG |
|---|---|
| `DIE` | `targets/die.svg` |
| `TABLE` | `targets/table.svg` |
| `GAP` | `targets/gap.svg` |
| `GLOBAL` | `targets/global.svg` |
| `DICE_PAIR` | `targets/dice_pair.svg` |

## Engraving families

- `engravings/echo.svg`
- `engravings/anchor.svg`
- `engravings/bridge.svg`
- `engravings/prism.svg`

Regional engraving variants reuse the family glyph and remain distinct through
their visible short name and area accent. Do not create twelve unrelated glyphs.

## Readability rule

Icons accelerate scanning but never replace decision-critical copy. Pair an
effect icon with an explicit action line such as `骰子 +1（上限 6）`; pair a
target icon with a noun such as `目标：1 颗骰子`. Conditions, costs, and limits
must remain visible before the player confirms an action. Hover text is only
supplementary.
