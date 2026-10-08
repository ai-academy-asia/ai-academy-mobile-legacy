# Component Patterns

> An inventory of what exists and can be reused, plus the conventions each component follows.
>
> **This is implementation context, not the design authority.** Figma decides how a component should look; this file tells you what is already built, where it lives, and what its constraints are — so you reuse rather than duplicate, and so you know what you are changing when Figma disagrees with it.

## 1. Reuse decision order

1. **A shared widget** in `lib/shared/widgets/` — if it fits without widening its contract.
2. **A feature widget** in that feature's `presentation/widgets/` — if you are working inside that feature.
3. **A new widget**, but only after recording *why* the existing one did not fit.

That third step is a real convention here, not boilerplate. Several widgets exist specifically because a shared one did not fit, and each says so in its doc comment — for example `ExerciseSubmitButton` exists because `AppButton` is full-width with a flat disabled state, while the Exercise Detail reference needs 329 wide with a shadowed disabled state. **Copy that habit: when you do not reuse, say why.**

Equally: **do not widen a shared widget's contract for one screen.** That reasoning is recorded in `_ContinueLearningButton` (Module List) — it is a local button precisely so `AppButton` stays a full-width 44pt block for everyone else.

## 2. Buttons

| Widget | Where | Shape | Notes |
|---|---|---|---|
| `AppButton` | `shared/widgets` | Full-width, 44pt | Variants `filled` (blue) / `outlined` (white + thin border). Three states: pressable, disabled (flat, no ripple), **loading** (spinner replaces label, width unchanged so layout does not jump) |
| `ExerciseSubmitButton` | `course_learning` | 329 × 44 pill | Blue + blue-tinted shadow when enabled; `surfaceMuted` + subtle shadow when disabled. Disabled = `onPressed == null` |
| `_ResubmitButton` | `course_learning/assignment_tab` | 329 × 44 pill | **Outlined**, with a leading refresh icon — an outlined action, deliberately not primary blue |
| `_ContinueLearningButton` | `course_learning/module_list` | 164.5 × 40 pill | Sits *beside* a progress bar; blue shadow painted on a wrapping `DecoratedBox` |
| `_CancelButton` | `course_learning/attachment_card` | 80 × 40 pill | White, bordered |
| Circular icon button | several | 40 × 40 circle | White, `exerciseBorderColor` outline, soft shadow — back button, play, download, remove, quiz close |

**Loading ≠ disabled.** `AppButton` keeps its active colours while loading; only a genuinely unpressable button goes flat. A request in flight should not read as a dead control.

## 3. Text fields

| Widget | Where | Height | Notes |
|---|---|---|---|
| `AppTextField` | `shared/widgets` | 56 (fixed by its content-padding math) | Single-line only. Floating label rises on focus. Supports `errorText`, `suffix`, `obscureText`, `autofillHints`, `focusNode` |
| `ExerciseTextField` | `course_learning` | caller-supplied (53 / 104 / 118) | Multiline-capable; label is **permanently floated** (`FloatingLabelBehavior.always`), never resting inside the box |

`ExerciseTextField` exists because `AppTextField` is single-line at a fixed 56 — a hard blocker for the 104/118pt textareas. It also deliberately avoids `expands: true`, which triggers a framework semantics assertion on dispose in this SDK; a generous fixed `maxLines` inside a tight `SizedBox` gives the same box through the ordinary code path. **Do not "simplify" that back to `expands`.**

## 4. Cards and list items

All share: `AppColors.surface` fill, 1pt border, rounded corners, and (on this app's list screens) an explicitly-painted soft shadow rather than Material elevation.

| Widget | Footprint | Notes |
|---|---|---|
| `CourseCard`, `CohortCard` | content width | Catalog/cohort rows |
| `ProgramCard` | content width | Home cohort card |
| `CourseModuleCard` | 361 × 86 min | 56 icon tile (accent-tinted) / 32 lock tile; 24 completed check |
| `LessonListItem` | 361 × 72 min | Figma level-detail reference (Issue #215): two-digit number, title in Manrope 14/20 ExtraBold (calibrated against the reference, Issue #217) on the number's baseline, duration line; a reserved 24 trailing status column after a 16 gap, holding Course Detail's 20 completed check or padlock flush right; radius 12, `#EAEDF0` outline with a 4pt flat band |
| `CourseMaterialCard` | 329 × 72 | 32 file icon, 40 circular download → check |
| `AssignmentAttachmentCard` | 329 × 72 / ~132 | Three states: idle row, taller downloading card (progress bar + Cancel), complete row (Remove) |
| `MentorFeedbackCard` | content width | Avatar-initials + name + role + message + timestamp |
| `QuizPreviewCard`, `QuizAnswerCard`, `QuizFeedbackCard`, `QuizResultQuestionRow` | see note below | Quiz family |

**Read the footprint column carefully — literal vs. effective width.** `329 × 72` on the material/attachment rows is a **literal `width:` on the widget**. The quiz family is different: `QuizAnswerCard` sets `height: 56` with `width: double.infinity`, so its 361 comes from the 16pt-padded content column it sits in, **not** from the widget. Same for `QuizFeedbackCard` and `QuizPreviewCard` (`double.infinity`), and `QuizResultQuestionRow` (56 tall, width from its parent).

Practical consequence: **do not hardcode 361.** A widget that fills its parent stays correct inside any padded column; one pinned to 361 breaks the moment the padding changes or it is reused elsewhere.

**Avatars are rendered as initials in a blue circle**, not images. No model carries an avatar URL; adding one is new UI, not a field swap.

## 5. Navigation chrome

- **`AppBottomNav`** (`shared/widgets`) — the one tab bar. `AppBottomNavItem { icon, label, onTap, selectedAsset }` + `currentIndex`. Height `AppDimens.bottomNavHeight` (72) plus the device's bottom inset; tabs inset `AppDimens.screenPadding` (16); `#2970FF` selection. Adult defaults: 24pt icon box (the reference's; 26 was tried and read too dominant on a device) and 12pt labels (above the reference's 10, a product decision for readability; 13 was tried and competed with the icons, Issue #188).
  - **`AdultBottomNav`** (`home/presentation/widgets`) — the only way the adult tabs (Home, Cohort List, Profile) draw the bar. In the app it is drawn **once**, by `AdultStudentShell`, with `onSelect` switching tabs in place so the bar stays fixed (Issue #237); a tab screen drawn on its own (`showBottomNav: true`, the default) still draws it and switches through `openStudentTab`. It has one item list, the shared defaults, no overrides. Each destination has one glyph in two weights, fixed per destination rather than per screen: the gray Phosphor outline (`house`, `bookOpenText`, `user`) when inactive, and a filled version in blue when active — Phosphor's **Fill** weight for Нүүр and Профайл (`nav_home_selected.svg`, `nav_profile_selected.svg`), and for Хичээл `nav_courses_active.svg`, which is the outline `bookOpenText` glyph's own contours with its page holes filled (text lines kept as cut-outs), so its shape never changes on selection (Issue #237). Phosphor's own BookOpenText Fill is drawn differently and is not used. `AppBottomNav` scales a `selectedAsset` by `iconSize / 24` (the exports' glyph box) and tints it with `selectedColor`, so fill and outline stay the same size. The screen tests and `adult_bottom_nav_test.dart` assert this.
  - **`JuniorBottomNav`** (`junior_home/presentation/widgets`) — the same shared defaults with no overrides, so it matches the adult bar's scale exactly (24pt icons, 12pt labels, 16pt inset, `#2970FF`; Issue #190). Gray outline when inactive, the same glyph filled blue when active: Нүүр and Профайл use the Phosphor outline plus the same Fill exports as the adult bar (`nav_home_selected.svg`, `nav_profile_selected.svg`); Сурлагын явц keeps Material's `event_available` outline/filled pair, since there is no Phosphor CalendarCheck Fill export. The junior frames drew 10pt labels; 12 is a requester decision.
- **`CourseLearningBackButton`** — a standalone row above the page.
- **In-video back button** (`ExerciseVideoHeader`) — a second copy of the same visual, `Positioned` over the video. **It must be offset by `MediaQuery.paddingOf(context).top`.** Without that, on a real scrolling screen iOS's status-bar touch handling claims taps before Flutter sees them and the button silently does nothing — a bug a zero-inset widget test cannot catch. There is a regression test that simulates a real notch inset; keep it.
- **Tab header** (`ExerciseTabs`) — 49 tall, bottom divider, 2pt blue underline under the active label. Wrapped in a horizontal `SingleChildScrollView` so a longer label or larger text scale cannot reintroduce overflow.

### Modals

Two exist, neither drawn by a Figma frame, so both are assembled from existing tokens and components rather than new design:

- **`SignOutConfirmationDialog`** (`auth`, #166) — a white `Dialog` at `cardRadius` and `cardPadding`: `cardHeading` title, `statLabel` message, then the filled `AppButton` over the outlined one.
- **`ManagerContactSheet`** (`auth`, #186) — a Material bottom sheet on `AppColors.surface` with `cardRadius` top corners, capped at `maxContentWidth`, inside the bottom safe area: `cardHeading` heading, two options drawn as the Login frame's `ContactManagerCard` (80pt, 1pt border, trailing caret; a leading Phosphor glyph, `cardTitle` action over `cardSupporting` contact), and the outlined `AppButton` to cancel.

Both guard against a second tap popping the screen underneath, and every way out other than the action (cancel, barrier, system back) completes as "nothing chosen". Mirror them for any new modal.

## 6. Loading, empty and error states

The established trio (canonical implementation: `cohort_list_screen.dart`):

```dart
// Loading — 28×28 centred spinner, strokeWidth 2.5, AppColors.blue
Center(child: SizedBox(width: 28, height: 28,
  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.blue)))

// Empty — centred message, AppTypography.cardSupporting, screenPadding gutter
// Error — same, plus a retry action below it
```

Conventions:

- **Loading shows only on first load.** Controllers expose `hasLoadedOnce` so a refresh does not blank out content already on screen.
- **Empty is a distinct state**, not an error — controllers expose `isEmpty`.
- **Error copy comes from the controller** (`errorMessage`), mapped from a typed failure using that feature's `*_strings.dart`. Widgets never inspect failure types.
- Error views carry a **retry** that re-invokes the controller's load.

`course_learning` screens now load from the real API and render error states with retry; Lesson List also renders the empty state (`LessonListController.isEmpty`, Issue #156), mirroring `CohortListScreen._EmptyView`.

## 7. Progress indicators

- **Linear** — `ClipRRect(borderRadius: circular(…))` around a `LinearProgressIndicator`. Track `AppColors.border`, fill `AppColors.blue`. Heights: 6 (`progressBarHeight`, course progress), 8 (quiz header, download).
- **Circular** — 28 × 28 @ 2.5 stroke for page loading; 32 × 32 for the in-card download spinner.

## 8. Badges and pills

`CourseBadge` (`courses`) plus inline pills. Pattern: small label (`badgeLabel` / `catalogStatusLabel`), `999` radius, colour at low alpha behind it (`color.withValues(alpha: 0.12)` is the house tint), never a flat saturated fill.

## 9. Accessibility conventions already in place

Follow these when adding controls — several tests depend on them:

- **Wrap non-standard tappables in `Semantics(button: true, label: …)`.** Every custom circular control and pill does this.
- **Selected state** on tab/option rows uses `Semantics(selected: …)`.
- **Caveat worth knowing:** when a `Semantics(label:)` wraps a widget that *also* contains a `Text` of the same string, the labels merge and `find.bySemanticsLabel('X')` will match neither exactly. Icon-only controls are safe; for text buttons, test with `find.text(...)` instead.
- Minimum tap targets in practice: 40 × 40 for circular controls, 44 for primary buttons.
