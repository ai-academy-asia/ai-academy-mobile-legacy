# Figma → Flutter

> The working method for turning a Figma frame into Flutter code in this repository.
>
> **Figma is the source of truth. The existing Flutter UI is not.** Where they disagree, the Flutter code is what changes.

## 1. Availability: what you can and cannot use

**Figma MCP is unavailable — its monthly quota is exhausted.** Do not plan work that depends on it, and do not report a task as blocked on it.

The working visual source of truth is **Figma screenshots/exports supplied in the task**. Additional constraints already established for this project:

- The **"App UI" page is the mobile source of truth.** Never pull a mobile screen from the "- Web UI" page.
- Exported SVG/PNG assets belong in `assets/` (see [../ai/ARCHITECTURE.md](../ai/ARCHITECTURE.md) §8). **Only add an asset when no existing icon can reproduce the Figma one**, and never duplicate an existing asset.

## 2. Before writing any widget code

1. **Compare the current implementation against the frame.** The screen may already exist; the task may be correcting it. Know which.
2. **Inventory what already exists** — token, shared widget, feature widget (see [COMPONENT_PATTERNS.md](COMPONENT_PATTERNS.md) §1).
3. **Classify every value in the frame** into one of the three tiers from [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) §1: global token / screen-local constant / screen-specific exception.
4. **Note what the frame does *not* show.** A single frame rarely shows every state. Missing states are `UNKNOWN` — do not invent them (see §5).

## 3. Reading measurements

The reference artboard is **393 × 852**. The spine is `393 − 2×16 = 361`, with a common inner block of **329**.

- A measurement that lands on the spine (361, 329, 16, 44, 12) is almost certainly the token, not a coincidence — use the token.
- A measurement that does not is either a new shared token (only if multiple screens confirm it) or a screen-specific value.
- **Write the measurement and its source in a comment** when you use a literal. The house style is explicit: *"Figma measurement: the card is 361 × 86, its icon container 56 × 56"*.
- Treat **"approximately"** in a spec as permission to flex. Existing code pins exact values (a 164.5 × 40 button) and flexes approximate ones (`Expanded` for a ~164.5 progress section) precisely so a couple of pixels of padding difference does not overflow.

## 4. Typography from a frame

**Do not copy the frame's pixel sizes directly.** The shipped scale sits about **15% below the measured Figma values** by a deliberate, documented decision (`AppTypography`'s doc comment: measured heading 26 → shipped 22; body 13 → 12; small 11 → 10), while **line heights were kept at the layout's values**.

So: map the frame's role to the nearest existing style, then `.copyWith()` for a local size/weight nudge. Introduce a new top-level style only when the scale genuinely lacks the role — and say so.

## 5. Handling states the frame does not show

Real situations this project has hit:

- **A state with no frame** — e.g. Lesson List had no Figma frame until Issue #215, so `LessonListItem` mirrored `CourseModuleCard` rather than inventing a visual language; once the level-detail reference arrived, it was restyled to that. Within it, the reference draws no locked or duration treatment on a lesson card, so those reuse Course Detail's padlock and secondary ink. **Mirror the nearest sibling and say so.**
- **A state the sample data never produces** — `CourseModule` has no "available, not started" visual because the Figma sample only shows completed and locked. It is **not modelled**, rather than guessed.
- **Contradictory examples** — two Figma examples disagreed on the module schedule line's shape, so it is one pre-formatted string, not split into date/weekday/time fields.
- **An obvious typo in the frame** — the reference spells a status "Compelete"; the code ships "Complete". Match the design's *intent*; do not reproduce a spelling mistake. Note the deviation.

Default: **mirror the nearest documented sibling, or leave the state unmodelled, and record the decision.** Never invent a state and present it as designed.

## 6. Copy

UI strings go in that feature's `presentation/<feature>_strings.dart`, **verbatim from the frame** — including the mixed Mongolian/English the design uses. There is no localization framework and **none should be added** without a task that asks for it. Do not translate, normalise or "fix" copy that the design specifies.

## 7. Verifying the result

A visual change is not done because it compiles.

1. `flutter analyze` and the relevant tests.
2. **See it rendered.** Either a golden/screenshot capture or a run on the simulator.
3. Compare against the frame for geometry, spacing, type, colour, borders, radii, shadows and every state the frame shows.
4. **If you could not verify it visually, say so explicitly** rather than claiming success.

A note on golden captures in this repo: a scratch golden test renders arbitrary states without a simulator, but its output has two artefacts that are **not** app bugs — Material `Icons.*` glyphs render as tofu boxes unless that font is loaded via `FontLoader`, and a first-time golden carries a diagonal corner marker drawn by `matchesGoldenFile`. Delete scratch harnesses afterwards.

## 8. Checklist

- [ ] Frame compared against the current implementation
- [ ] Every value classified: global token / screen-local / exception
- [ ] Existing tokens and widgets reused where they fit; non-reuse justified in a comment
- [ ] No arbitrary literal without a recorded measurement and reason
- [ ] Type mapped to the scale, not copied from the frame's pixels
- [ ] States the frame omits left unmodelled or mirrored from a documented sibling — never invented
- [ ] Copy verbatim, in the feature's `*_strings.dart`
- [ ] New assets only where no existing icon works; no duplicates
- [ ] `flutter analyze` + tests pass; pre-existing failures reported separately
- [ ] Rendered and visually compared, or the gap stated explicitly
- [ ] The three protected iOS files untouched ([../ai/DEVELOPMENT_RULES.md](../ai/DEVELOPMENT_RULES.md) §3)
