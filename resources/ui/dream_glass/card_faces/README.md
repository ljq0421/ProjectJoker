# Dream Glass Card Faces

These deterministic SVGs are complete technique-card faces. Each `300 x 200`
file contains the identity, card name, rarity track, main effect composition,
effect summary, decision-critical detail, target icon, and target copy.

Visible copy is converted to SVG paths because Godot's ThorVG importer does not
rasterize `<text>` elements. Godot remains responsible for interaction states,
tooltips/full rules, and runtime-only commerce data such as shop prices.

## Completed sets

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `starter_nudge_down_1` | before / after | die value decreases by one |
| `shop_precision_map` | rule instrument | table coefficient increases |
| `starter_link` | topology | resolved output crosses a gap |
| `starter_reverse` | topology | global resolution order reverses |
| `faceless_copy_value` | before / after | a second die copies the first |
| `faceless_lock_bonus` | contract state | a locked die rewards every successful table resolution |

First confirmed expansion batch:

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `starter_nudge_up_1` | before / after | die value increases by one |
| `starter_nudge_down_2` | before / after | die value decreases by two |
| `starter_nudge_up_2` | before / after | die value increases by two |
| `starter_map_1` | coefficient transfer | table coefficient increases by one |
| `starter_map_2` | coefficient transfer | table coefficient increases by two |
| `starter_repeat_1` | loop / echo | table resolves one additional time |

Second expansion review batch:

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `starter_repeat_2` | loop / two echoes | table resolves two additional times |
| `starter_stable_repeat` | coefficient tradeoff / loop | coefficient decreases, then table repeats |
| `starter_amplified_repeat` | coefficient gain / loop | coefficient increases, then table repeats |
| `shop_triple_repeat` | loop / three echoes | table resolves three additional times |
| `shop_long_push` | before / after | die value increases by three |
| `shop_deep_drop` | before / after | die value decreases by three |

Third expansion review batch (Mirror Hall):

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `mirror_folded_map` | split reflection / coefficient bars | direct +2, reflected +1 |
| `mirror_soft_echo` | split reflection / echo count | direct repeats twice, reflected once |
| `mirror_hinged_bridge` | hinged bridge / ghost bridge | direct links and gains coefficient, reflection only links |
| `mirror_double_exposure` | split reflection / layered table | direct coefficient and repeat, reflected coefficient |
| `mirror_deep_echo` | split reflection / layered echoes | direct coefficient and two repeats, reflected repeat |
| `mirror_silver_bridge` | hinged bridge / echo layer | direct link and repeat, reflection only links |

Fourth expansion review batch:

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `shop_amplified_chain` | coefficient gain / loop | coefficient increases by two, then table repeats |
| `shop_reverse_backup` | opposing global arcs | global resolution order reverses |
| `faceless_swap_values` | opposing transfer arcs | two dice exchange effective values and empower their unique final tables |
| `faceless_flip_value` | half-turn / before-after | die becomes seven minus its current value |
| `faceless_refund_calibration` | returning charge | one spent calibration point is restored |
| `faceless_exact_tolerance` | target with accepted neighbors | exact condition accepts plus or minus one |

Fifth expansion review batch:

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `faceless_even_tolerance` | even row / highlighted exception | one odd die is accepted |
| `faceless_sequence_tolerance` | ordered nodes / bridged gap | one difference-of-two gap is accepted |
| `faceless_table_receipt` | checked table / one-stamp receipt | target table pass grants one intel |
| `faceless_full_allocation` | six assigned dice / two-stamp receipt | allocating all dice grants two intel |
| `faceless_three_seats` | three occupied tables / two-stamp receipt | occupying all tables grants two intel |
| `faceless_complete_dossier` | three checked tables / three-stamp dossier | passing all tables grants three intel |

Final expansion review batch:

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `faceless_strict_mapping` | added slot / rising coefficient | costs one more die slot and gains two coefficient |
| `faceless_reverse_replay` | opposing global arcs / echo | reverses order and repeats the target table |
| `faceless_compressed_repeat` | descending coefficient / two echoes | loses one coefficient and repeats twice |
| `faceless_closed_circuit` | closed table loop / echo | links both ends and repeats the target table |

Phase-three extreme-technique batch:

| Card ID | Composition grammar | Meaning |
|---|---|---|
| `stage7_fault_die` | fractured die / coefficient rail | fixes one die at 1 and raises its table coefficient |
| `stage7_all_in` | emptied calibration ledger / intel seal | spends all calibration and conditionally copies card intel |
| `stage7_insurance_draft` | discarded page / split undo stamps | discards one card for separate calibration and card undos |
| `stage7_burned_rewrite` | two burned pages / weakened replay | discards two cards to replay a passed table at reduced coefficient |

The approved runtime set now covers all 46 cards in `CardCatalog`, including
the two directed-search index cards introduced before phase three.

## Visual contract

- No `<text>` elements; visible copy is stored as deterministic glyph paths.
- Dark glass `#0E0B26`, cyan structure `#59E6DB`, violet mutation `#D27BE5`,
  ivory stable objects `#F4F0FF`.
- The central diagram owns the face between a compact identity header and a
  bottom effect band.
- Rarity always uses an explicit three-slot track: `◆◇◇`, `◆◆◇`, `◆◆◆`.
- Expansion proceeds in six-card review batches; each accepted batch becomes
  part of the runtime card-face set.

## Regeneration

Card `.tres` resources remain the copy source of truth. Regenerate the manifest
and all approved runtime SVGs from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/generate_card_face_assets.ps1
```

The pipeline is:

1. `tools/export_card_face_data.gd` reads `CardCatalog` and
   `CardDisplayFormatter` into `card_face_manifest.json`.
2. `tools/generate_card_face_svgs.py` uses TrueType metrics to write editable
   `.svg.txt` sources with fitted text.
3. `tools/pathify_card_face_text.ps1` converts the installed Noto Sans SC
   glyphs into SVG paths through `System.Drawing` and writes runtime SVGs.
4. Godot imports each SVG as a complete card texture. Cards outside the
   approved batches retain the scene-owned fallback layout.
