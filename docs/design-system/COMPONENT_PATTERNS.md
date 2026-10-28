# Component Patterns

> An inventory of what exists and can be reused, plus the conventions each component follows.
>
> **This is implementation context, not the design authority.** Figma decides how a component should look; this file tells you what is already built, where it lives, and what its constraints are — so you reuse rather than duplicate, and so you know what you are changing when Figma disagrees with it.

## 1. Reuse decision order

1. **A shared widget** in `lib/shared/widgets/` — if it fits without widening its contract.
2. **A feature widget** in that feature's `presentation/widgets/` — if you are working inside that feature.
3. **A new widget**, but only after recording *why* the existing one did not fit.

That third step is a real convention here, not boilerplate. Several widgets exist specifically because a shared one did not fit, and each says so in its doc comment — for example `ExerciseSubmitButton` exists because `AppButton` is full-width with a flat disabled state, while the Exercise Detail reference needs 329 wide with a shadowed disabled state. **Copy that habit: when you do not reuse, say why.**

**Colour in shared components comes from the theme (Dark Mode Phase 3, Issue #258).** These read every colour from `context.palette`, never `AppColors`, a feature palette or a literal:
- `AppButton`, `AppTextField`, `AppBottomNav`;
- `AppBackButton`, `BackTitleHeader`, `TabTitleBar`, `HomeHeader`;
- `PillButton`, `TrackBadge`, `CardCapsule` (`shared/widgets`, Issue #329 — moved out of `home`, formerly `HomePillButton` / `home_badges.dart`'s `HomeCapsule`, because the Attendance scanner, Payment, Teacher and E-Contract screens draw them too; `CardCapsule` draws the colours its caller passes). `TrackBadge`'s 32 and `CardCapsule`'s 24 are minimums: a larger system text size grows each with its label instead of clipping it, and `CardCapsule` is only as wide as its label in any parent (Issue #351). A caller with a fixed-height band still caps them — `ProgramCard`'s badge row, for one. `PillButton` grows taller with large text but keeps its label on one line with an ellipsis; a pill given its full width can opt in to `wrapLabel`, which wraps a label too long for one line, centred, and grows the pill to hold it, while a label that fits draws exactly as without it — the attendance scanner's rescan and camera-retry pill does ("Дахин уншуулах" at 2.0× on a 320pt phone, Issue #532), like `TeacherPillButton.wrapLabel`;
- the `profile_parts` widgets (`ProfileAvatar`, `ProfileCaption`, `ProfileRow`, `ProfileRule`, `ProfileLanguageToggle`, `ProfileSwitch`, `ProfileLogOutButton`).

`test/shared/theme_aware_components_test.dart` proves it by pumping them under a sentinel palette. New shared widgets follow suit.
- **Monochrome SVG icons go through `AppSvgIcon`.** It tints from `AppPalette.iconInk`, **but only when the role differs from the asset's own colour** (`authoredInk`). A `srcIn` `ColorFilter` re-rasterises the SVG and moves anti-aliased edge pixels even at the same colour: up to 29/255 on the wordmark, 9/255 on the Profile icons, measured on the goldens. So light mode draws icons as authored, and only another palette tints them. The `HomeHeader` wordmark follows the same rule with `AppPalette.wordmark`.
- **Not moved yet,** because each is used by one role only: `TeacherPillButton` (Teacher), Junior Profile's private row and switch, and every sheet. They move with their feature (audit Phases 5–8). (`HomePillButton` was on this list; it is now the shared `PillButton`, Issue #329.)

**Migrating a screen onto the palette (Phase 5, Issue #262): the patterns that keep light mode identical.**
- **A colour that was a default parameter** (`this.color = HomePalette.border`) becomes nullable and resolves in `build` (`color ?? context.palette.outline`). A default value must be a constant.
- **A top-level or static `TextStyle` with a colour** drops the colour, and each use applies it: `_titleStyle.copyWith(color: context.palette.textTitle)`. The public `profile_parts` styles keep theirs until Teacher migrates.
- **An `AppTypography` style that bakes a colour** gets it supplied at use: `.copyWith(color: context.palette.textPrimary)`. Leaving it null would inherit Material's default text colour, which is not the same.
- **A `CustomPainter` has no context:** pass its colours in, and compare them in `shouldRepaint`.
- **A helper that builds a `Text` without a context** wraps it in a `Builder`. It adds no render object, so layout is unchanged.
- **Remove only the `const` a palette read invalidates.**
- **Keep a deliberate *authored* colour as the constant it is.** An example is `HomeHeader`'s wordmark check `palette.wordmark == AppColors.wordmark`. Rewriting it to the palette made it always true, and the theme test caught that.

Equally: **do not widen a shared widget's contract for one screen.** That reasoning is recorded in `_ContinueLearningButton` (Module List) — it is a local button precisely so `AppButton` stays a full-width 44pt block for everyone else.

## 2. Buttons

| Widget | Where | Shape | Notes |
|---|---|---|---|
| `AppButton` | `shared/widgets` | Full-width, 44pt | Variants `filled` (blue) / `outlined` (white + thin border). Three states: pressable, disabled (flat, no ripple), **loading** (spinner replaces label, width unchanged so layout does not jump) |
| `ExerciseSubmitButton` | `course_learning` | 329 × 44 pill (44 a minimum: it grows only when larger text needs it, Issue #541) | Blue + blue-tinted shadow when enabled; `surfaceMuted` + subtle shadow when disabled. Disabled = `onPressed == null` |
| `_ResubmitButton` | `course_learning/assignment_tab` | 329 × 44 pill | **Outlined**, with a leading refresh icon — an outlined action, deliberately not primary blue |
| `_ContinueLearningButton` | `course_learning/module_list` | 164.5 × 40 pill | Sits *beside* a progress bar; blue shadow painted on a wrapping `DecoratedBox` |
| `_CancelButton` | `course_learning/attachment_card` | 80 × 40 pill | White, bordered |
| Circular icon button | several | 40 × 40 circle | White, `outline` ring, soft shadow — back button, play, download, remove, quiz close. On the video the disc is `mediaControl`, its ring `mediaControlOutline` and its glyph `onMediaControl`, not `surface`/`outline`/`textPrimary` |

**Loading ≠ disabled.** `AppButton` keeps its active colours while loading; only a genuinely unpressable button goes flat. A request in flight should not read as a dead control.

## 3. Text fields

| Widget | Where | Height | Notes |
|---|---|---|---|
| `AppTextField` | `shared/widgets` | 56 (fixed by its content-padding math) | Single-line only. Floating label rises on focus. Supports `errorText`, `suffix`, `obscureText`, `autofillHints`, `focusNode`, and `readOnly` + `onTap` for a value picked elsewhere (the E-Contract form's date, Issue #314). Draws no message under itself |
| `ExerciseTextField` | `course_learning` | caller-supplied (53 / 104 / 118): the multiline fields' exact boxes; the single-line field's minimum (Issue #540) | Multiline-capable; label is **permanently floated** (`FloatingLabelBehavior.always`), never resting inside the box; a single-line field's placeholder may wrap (up to 3 lines) at large text instead of being cut short |
| `KeyboardRevealField` / `KeyboardRevealArea` | `shared/widgets/keyboard_reveal.dart` | — (draw nothing) | Keyboard reveal (Issue #463): a focused field shows whole above the keyboard, through its form's action when wrapped in an area whose **last child is that action**; short viewports fall back to the caret line through the action, then the caret alone. Pass the field's `scrollPadding` if not the default. No layout, hit-test or semantics change. See `SCREEN_PATTERNS.md` §4 |

**A form of many fields** (the E-Contract form, Issue #314) puts each field's reason in a `fieldError` line in `error`, 4 under the box and 16 in, since `AppTextField` draws none and Login's one-line message band cannot say which of twelve fields is at fault.

`ExerciseTextField` exists because `AppTextField` is single-line at a fixed 56 — a hard blocker for the 104/118pt textareas. It also deliberately avoids `expands: true`, which triggers a framework semantics assertion on dispose in this SDK; a generous fixed `maxLines` inside a tight `SizedBox` gives the same box through the ordinary code path. **Do not "simplify" that back to `expands`.** It is wrapped in the shared `KeyboardRevealField`, and the Note and Assignment forms in a `KeyboardRevealArea` — see the keyboard row below.


**Signature input (Issue #304).** `ContractSignaturePad` (`contracts/presentation/widgets`) is the E-Contract signing screenshot's signature section:
- the title "Гарын үсэг зурна уу · Sign here" (16/400), excluded from semantics because the pad carries it as its label;
- a 158-tall pad (`surface`, `outline` edge, `homeCardRadius`) that takes its parent's width, with strokes in `linkInk` at 3pt;
- "Цэвэрлэх / Clear" (14/600, `accentText`) right-aligned under it, in `disabledInk` and inert while empty.

Behaviour:
- A `ContractSignatureController` exposes `isEmpty`, `clear()` and `toPng()`.
- **The pad wins its touch on contact**, so a stroke never scrolls a parent scroll view. Points outside the pad are dropped, and re-entering starts a new stroke.
- `toPng()` draws in the authored `AppColors.linkInk` on transparent, whatever the theme: the backend turns near-white transparent, so a light Dark-theme ink could vanish. It renders at up to 2×, kept under 0.6 MP.
- Measured off a screenshot, not a Figma frame. The screenshot's faint circled "×" inside the pad is not drawn, because what it is remains unknown.
- Used by `ContractPreviewScreen`'s signing step (Issue #320), which owns and disposes the controller and ignores the pad's touches while a sign is in flight.


**PDF preview (Issue #310).** `ContractPdfView` (`contracts/presentation/widgets`) shows in-memory PDF bytes (`getContractPreview`'s answer) inside the signing screen export's document box: `surface`, the `outline` edge, `homeCardRadius`, with the size set by the caller. Used by `ContractPreviewScreen` (Issue #316), on that export's `surfaceSubtle` page.
- **Pages:** every page is drawn by `pdfx`, one under the other in a scroll view. Each is fitted to the box width with `fieldGap` between pages, and drawn lazily at the box width × device pixel ratio (capped at 2048 px). Before a page draws, it holds A4's proportion as a placeholder.
- **States:** a spinner while opening; the generic error line plus retry if opening fails; a per-page retry if one page fails. Every failure also goes to `onError`. The export draws text there, not pages, so page spacing, zoom and the state presentation are not designed.
- **Renderer seam:** `ContractPdfRenderer` / `ContractPdfDocument` keep the widget's tests off native rendering. `PdfxContractPdfRenderer` opens with `PdfDocument.openData` (no file), renders PNG on white, closes each page after drawing it, and queues renders one at a time (Android's `PdfRenderer` allows one open page).
- **Resources:** the document is closed on dispose and when the bytes change, and a late open is closed instead of shown.

## 4. Cards and list items

All share: `AppColors.surface` fill, 1pt border, rounded corners, and (on this app's list screens) an explicitly-painted soft shadow rather than Material elevation.

| Widget | Footprint | Notes |
|---|---|---|
| `CourseCard`, `CohortCard` | content width | Catalog/cohort rows |
| `ProgramCard` | content width | Home cohort card |
| `CourseModuleCard` | 361 × 86 min — exactly 86 at the default text size; grows with a larger one so the caption, title and date line stay whole (Issue #349) | 56 icon tile (accent-tinted); locked: the same 56 tile in flat grey with the 24 × 27 padlock; 20 completed check; 12 inset around the tile and the text; title one line with an ellipsis |
| `CourseLessonCard` | `CourseModuleCard`'s box and rules (86 min, 94 with a one-line title at the default size) | Course Detail's lesson list (Issue #437), in `course_module_card.dart` to share its constants: the lesson's module's 56 tile (padlock when the lesson or its module is locked), `01`–`N` caption, title up to two lines, duration line, 20 completed check. Current lesson: `primary` outline at 2pt, number and title in `primary`, and a `primary` pill with "Эндээс үргэлжлүүлнэ" in `onPrimary` |
| `LessonListItem` | 361 × 72 min | Figma level-detail reference (Issue #215): two-digit number, title in Manrope 14/20 ExtraBold (calibrated against the reference, Issue #217) on the number's baseline, duration line; a reserved 24 trailing status column after a 16 gap, holding Course Detail's 20 completed check or padlock flush right; radius 12, `#EAEDF0` outline with a 4pt flat band |
| `CourseMaterialCard` | 329 × 72 | 32 file icon, 40 circular download → check |
| `AssignmentAttachmentCard` | 329 × 72 / ~132 | Three states: idle row, taller downloading card (progress bar + Cancel), complete row (Remove) |
| `MentorFeedbackCard` | content width | Avatar-initials + name + role + message + timestamp |
| `QuizPreviewCard`, `QuizAnswerCard`, `QuizFeedbackCard`, `QuizResultQuestionRow` | see note below | Quiz family |

**Read the footprint column carefully — literal vs. effective width.** `329 × 72` on the material/attachment rows is a **literal `width:` on the widget**. The quiz family is different: `QuizAnswerCard` sets `height: 56` with `width: double.infinity`, so its 361 comes from the 16pt-padded content column it sits in, **not** from the widget. Same for `QuizFeedbackCard` and `QuizPreviewCard` (`double.infinity`), and `QuizResultQuestionRow` (56 tall, width from its parent).

Practical consequence: **do not hardcode 361.** A widget that fills its parent stays correct inside any padded column; one pinned to 361 breaks the moment the padding changes or it is reused elsewhere.

**Avatars are rendered as initials in a blue circle**, not images. No model carries an avatar URL; adding one is new UI, not a field swap.


**The program/cohort card family (Issue #404).** Adult Home's `ProgramCard`, the Courses tab's `CohortCard`, Teacher Schedule's `TeacherClassCard`, Teacher Programs' `TeacherProgramCard` and the E-Contract card show one concept, so they share their visual parts from `shared/widgets/track_badge.dart` — change them there, not per card. The rules are read off the Figma exports (`figma design/`: `HomePage - Adult/Home Page1.png`, `Course Catalog.png`, `e-contract1.png`, `teacher/irts burtgeh/Contract.png`, `teacher/hutulburuud/Sign in - 33.png`), measured, not taken from the app:
- **Top row — `CardBadgeRow`:** the shared `TrackBadge` (32 tall at least; 5 | 20 icon | 8 | label | 9.5; `outline` edge, radius 8) on the left, the card's status or count `CardCapsule` (24 tall at least, pill radius, `badge` type, 15 each side) on the right, **hung from the badge's top edge** — every export that draws the pair does so (the capsule's top on the badge's, its centre 4 above: Home, Course Catalog both at y 148, E-Contract, the schedule sheet at y 508). Where larger text leaves no room for both, the capsule wraps under the badge — never over it, never clipped. No track: the capsule keeps the top-right corner.
- **Inset — `programCardPadding`:** 16 at the sides, 24 at the top and bottom, from the card's outer edge (the 1pt `outline` is drawn by the card's `Container`, so the padding gives it up).
- **Edge and radius:** `outline` at 1pt, `homeCardRadius` 16.
- **Pattern — `CardPattern`:** **one artwork** (`program_card_background.svg`; `cohort_background.svg` is the same file with a 148-tall viewBox) drawn **1:1 from the top-left, at full strength, on white `surface`, clipped to the card's rounded corners** — Home, Course Catalog (a taller card included) and E-Contract are pixel-identical there. **Every card in the family draws it** — Home, Courses, E-Contract, Teacher Programs and Teacher Schedule's session card (`TeacherClassCard`: the session sheets, the day list, Teacher Home and the incoming-request sheet). On Teacher Programs and the session card it is a product decision (Issue #408): the session card's export has none, and `Sign in - 33` scales the art about 1.34× — the family's one rendering wins. A **junior track** (`isJuniorTrack`: `junior` / `kids`) draws the same shapes in `programJuniorTint`, decided inside `CardPattern` from the card's track — no Junior export exists (Issue #390). Never on buttons, fields or schedule-grid blocks.
- **Per card, by its frame:** the gap from the badge row to the caption (24 on the student cards, 16 on the teacher cards), the status colours (open/active label `successInk` on Home, `successLabel` on Courses — documented per frame), and every card's own content, actions and data.
- **Teacher Programs' content row:** the cohort over the course on the left, "Нийт сурагч" over the count on the right — side by side whatever the title's length (the title takes the room left and wraps; the label is level with the cohort, the count with the title's first line). The count goes under the title, still at the right, only when it would need more than half the row (large system text). It was a `Wrap`, which measured the title unwrapped and dropped the count under it, to the left, on a 393-wide iPhone at the default size (Issue #408).
- `test/shared/program_card_family_test.dart` holds the four to the shared row, the badge at (16, 24), the hung capsule, the inset and the shared pattern (clipped, untinted for adult, orange for junior), checks Teacher Programs' count placement at 320 / 375 / 393 / 430 wide and at 2.0–3.0× text, and that at 3.0× text on a 320-wide phone nothing is clipped and the capsule never overlaps the badge.

**Contract card (Issue #312).** `ContractCard` (`contracts/presentation/widgets`) is the Figma export `e-contract1.png`'s card, in the same family as Adult Home's `ProgramCard` summary. It reuses the family's `CardPattern`, the shared `TrackBadge` and `CardCapsule`, and caption/title styles (12 over 18/700).
- **Layout:** 16 in from the edge; the badge and pill row 24 below the top, with the pill scaled down rather than overflowing on phones narrower than the export. The action is a 44-tall white pill with an `outline` edge and a trailing download glyph or caret, 24 above the bottom. The glyph is always tinted with the label's ink, because the SVG's strokes are hard-coded black and would vanish on the dark button. The pill grows past 44 only for large accessibility text, and its label ellipsises rather than overflow (e.g. 2.0× at 320pt). Disabled, it goes flat (`disabled` edge, `disabledInk` label) and is announced as a disabled button.
- **Pill colours:** pending is the export's exact `warningFill` / `warningInk`. The signed ink (`#007BE5`) and the pill edges (`#84CAFF`, `#FFE8A3`) have no exact role, so `infoInk`, `accentSubtleOutline` and `warningOutline` at 30% stand in.
- **Export inconsistency:** the export draws the signed pill 24 tall and the pending one 32 tall; both use the 24-tall `CardCapsule` here.

## 5. Navigation chrome

- **`CertificatePreview`** and **`CourseProgressCtaRow`** / **`ContinueLearningButton`** (`course_learning/presentation/widgets`, Issue #155) — moved unchanged out of Course Module List and shared with the Certificate screen. The preview layers `certificate.png` inside `certificate_backround.png` at 329:225, `fieldRadius` corners; `inset` 6 (Module List) or 12 with `outlined` (`AppPalette.outline`, the Certificate frame). The row: an `Expanded` 8pt bar (`accent` on an `outline` track), 13, "N% complete" (14pt, `textTitle`), 31, then the `accent` pill — 40pt tall at least, taller when a larger text size wraps its label — with its 4pt `primaryDepth` band and `onPrimary` label, width passed in (148 in a 329-wide card) so it sits on x213. **When that does not fit** (Issue #347) — the bar would keep less than 16 (twice its height), as on a 320-wide phone or at a larger text size — the button moves to its own line, `fieldGap` under the bar and label, at the row's end and its design width; the label then wraps rather than take the bar's room. Every frame keeps the one row. The pill is one button to assistive tech, read once as "Continue learning".
- **`PersistentTabShell`** (`shared/widgets`, Issue #241) — a role's top-level tabs under one persistent bar: one `Scaffold` owning the bar (`barBuilder`), a lazily-built `IndexedStack` of the tab screens (`tabBuilder`, each built on first open and then kept, hidden tabs' tickers paused), and system back returning to `homeIndex`. A tab switch is a `setState`, never a route, so the bar never moves or duplicates. Used by `JuniorStudentShell` and `TeacherShell`; the earlier `AdultStudentShell` (#237) is the same behaviour in its own widget.
- **Profile parts** (`profile/presentation/widgets/profile_parts.dart`, Issue #243) — the measured pieces the Adult and Teacher Profile frames share at 1:1, moved unchanged out of `ProfileScreen` (the title band is now the shared `TabTitleBar`, Issue #368): `ProfileRule` (`HomePalette.headerRule`), `ProfileAvatar` (72pt placeholder disc — no avatar URL is confirmed), `ProfileCaption` (40pt band), `ProfileGroup` (rows with a rule after each), `ProfileRow` (55pt; 56pt for contact rows; no chevron; tappable only with `onTap`), `ProfileLanguageToggle` (MN/EN, 93 x 35) and `ProfileSwitch` (44 x 24) — both **inert** with a null `onChanged` — and `ProfileLogOutButton`, plus `ProfileMetrics` and the heading/name/caption/row styles. The Teacher hero uses the Adult hero's metrics on the 16 gutter (Issue #368; its frame drew a point further each way) and stacks name / email / phone, set in `TeacherProfileScreen`. `JuniorProfileScreen` keeps its own rows (8pt icon gap, as these) under the shared `TabTitleBar`.
- **`NotificationTile`** (`notifications/presentation`, Issue #246) — the Notification frame's row: 71pt plus a 1pt full-width `HomePalette.headerRule` rule; a 24pt glyph at x16 (`HomeIcons.notification`, `HomePalette.accent` unread / `#B2B2B2` read), 12 to the text column — title 16/24 w700 (`textPrimary` / `#B2B2B2`) over body 14/20 (`textSecondary` / `#B2B2B2`), one line each — then the age (14/20 `textSecondary`, `1d`) and, 13 after it, the 8pt unread dot, centred on the row. Every row is tappable and opens Notification Detail (Issue #248). `HomeHeader`'s bell carries the same dot while `unreadCount > 0`.
- **`AppBottomNav`** (`shared/widgets`) — the one tab bar. `AppBottomNavItem { icon, label, onTap, selectedAsset }` + `currentIndex`. Height `AppDimens.bottomNavHeight` (72) plus the device's bottom inset — a minimum: the bar grows when the system text size needs it, never capping the user's text scale, and every tab stretches to the bar's full height so it stays tappable (Issue #341). A label wraps between its words wherever each word fits its tab; a single word wider than its tab ("Профайл" at 2.0× in a 320-wide phone's 96pt tab) breaks inside the word — no word break can fit it without shrinking the text, and Flutter does no hyphenation. Each tab is one button to assistive tech, read once with its label and selected state (the visible label is excluded from semantics); tabs inset `AppDimens.screenPadding` (16); `#2970FF` selection. Adult defaults: 24pt icon box (the reference's; 26 was tried and read too dominant on a device) and 12pt labels (above the reference's 10, a product decision for readability; 13 was tried and competed with the icons, Issue #188).
  - **`AdultBottomNav`** (`home/presentation/widgets`) — the only way the adult tabs (Home, Cohort List, Profile) draw the bar. In the app it is drawn **once**, by `AdultStudentShell`, with `onSelect` switching tabs in place so the bar stays fixed (Issue #237); a tab screen drawn on its own (`showBottomNav: true`, the default) still draws it and switches through `openStudentTab`. It has one item list, the shared defaults, no overrides. Each destination has one glyph in two weights, fixed per destination rather than per screen: the gray Phosphor outline (`house`, `bookOpenText`, `user`) when inactive, and a filled version in blue when active — Phosphor's **Fill** weight for Нүүр and Профайл (`nav_home_selected.svg`, `nav_profile_selected.svg`), and for Хичээл `nav_courses_active.svg`, which is the outline `bookOpenText` glyph's own contours with its page holes filled (text lines kept as cut-outs), so its shape never changes on selection (Issue #237). Phosphor's own BookOpenText Fill is drawn differently and is not used. `AppBottomNav` scales a `selectedAsset` by `iconSize / 24` (the exports' glyph box) and tints it with `selectedColor`, so fill and outline stay the same size. The screen tests and `adult_bottom_nav_test.dart` assert this.
  - **`JuniorBottomNav`** (`junior_home/presentation/widgets`) — the same shared defaults with no overrides, so it matches the adult bar's scale exactly (24pt icons, 12pt labels, 16pt inset, `#2970FF`; Issue #190). Gray outline when inactive, the same glyph filled blue when active: Нүүр and Профайл use the Phosphor outline plus the same Fill exports as the adult bar (`nav_home_selected.svg`, `nav_profile_selected.svg`); Сурлагын явц keeps Material's `event_available` outline/filled pair, since there is no Phosphor CalendarCheck Fill export. The junior frames drew 10pt labels; 12 is a requester decision. In the app it is drawn **once**, by `JuniorStudentShell`, with `onSelect` switching tabs in place (Issue #241).
  - **`TeacherBottomNav`** (`teacher/presentation/widgets`) — the shared defaults with three tabs (Хуваарь, Хөтөлбөрүүд, Профайл — Хуваарь first and the default; the redesign dropped Нүүр, Issue #370) and one override, 10pt labels per its reference. Gray outline when inactive, the same glyph filled blue when active: Профайл uses the Phosphor Fill export the student bars use (`nav_profile_selected.svg`); Хуваарь and Хөтөлбөрүүд use `nav_schedule_active.svg` and `nav_grades_active.svg`, generated from the outline `calendar` / `exam` glyphs' own contours (page holes filled, "12" / "A+" kept as cut-outs) since their references' fills were never exported (Issue #241). In the app it is drawn **once**, by `TeacherShell`, where Профайл opens the Teacher Profile (Issue #243); on a standalone bar Профайл is inert, as it has no route.
- **`AppBackButton`** (`shared/widgets`, Issue #327; formerly `CourseLearningBackButton` under `course_learning`) — the 40pt circle (`AppDimens.backButtonSize`) on the gutter, `backButtonTop` 12 below the inset, popping the route. One glyph everywhere, the arrow (`AppIcons.arrowLeft`, the default since Issue #368), the video header's own control included. It owns its semantics label (`AppBackButton.label`, "Back"; `CourseLearningStrings.back` aliases it) so `shared/` depends on no feature.
- **`TeacherPillButton`** (Teacher, Issues #231, #372) — the Teacher references' 44-tall pill: `filled`, `outlined`, `danger`, and `disabled` — `ExerciseSubmitButton`'s muted treatment (`surfaceSubtle`, `outline`, `disabledInk`), exposed as a disabled button with no tap action, for an action that is not available yet ("Ирц бүртгэх"). `wrapLabel` lets a full-width sheet action wrap and grow at large text; a row's trailing pill keeps one line and an ellipsis. **`TeacherPillPair`** sets two side by side, 8 apart, and stacks them when enlarged text leaves a label wider than its half. `teacher_request_parts.dart` also holds `TeacherIdentity` (placeholder avatar, name, "Teacher"), `TeacherSheetHandle`, and the UI-only, unreachable `TeacherIncomingRequestSheet`, whose actions are nullable callbacks — inert without one.
- **`TeacherConfirmationCard`** (Teacher, Issues #372, #374) — the redesign's one success card: the success disc, a `title`, and a `dismissLabel` ("Ойлголоо"), each caller passing its own (Issue #547). "Амжилттай баталгаажлаа" after attendance writes (`showAttendanceSavedCard`); "Хүсэлт илгээгдлээ" once a time-change request is confirmed sent (Issue #449), both buttons "Got it" in English (Issues #547, #551). Shown only after the server confirms every write — never optimistically.
- **`AttendanceTally`** (Teacher, Issues #231, #374) — "14 / 24", its caption and the bar, from `AttendanceCounts`: the held session sheet's footer and the QR attendance screen's live count (captions "…бүртгэгдсэн" / "…бүртгэгдлээ").
- **Attendance rows** (Teacher, Issue #374) — `AttendanceStudentRow`: a 40 `StudentInitialsAvatar` (initials on `studentAvatarBlue`/`Red`/`Teal`, by `student_id`), the name, a full-width `outlineFaint` rule, and `AttendanceStatusControl`, one look per status — `present` the reference's filled accent check, `absent` its white disc, `late` a `warning` clock, `excused` a muted dash; `late`/`excused` are also named under the name, so colour is never the only sign. The control toggles present ↔ absent; a `late`/`excused` control, like a row tap, opens `AttendanceStatusPicker` (all four). A failed write is named ("Хадгалагдсангүй") with an `errorOutline` edge. A row whose server record moved since it was read (Issue #378) shows "Серверт: … · Таны сонголт: …" in `errorInk` with an `errorOutline` edge, and its control and row open `AttendanceConflictSheet` — keep the server's value (outlined) or apply the teacher's (filled); dismissed, it decides nothing.
- **Teacher Programs** (`teacher/presentation/widgets/program_widgets.dart`, Issue #390) — `TeacherProgramCard` (track badge, cohort over course, "Нийт сурагч" count, a 36-tall secondary "Дэлгэрэнгүй" `PillButton`, on the family's `CardPattern` (orange for Junior; Issue #408)); `CohortActionSheet` (two outlined `SheetActionRow` pills, Material `campaign`/`groups` glyphs — no Phosphor counterpart in `AppIcons`); `AnnouncementSheet` (hint, 100-character counter, field, Submit held off: `BACKEND GAP`); `ProgramPageHeader` (back control with a left-aligned caption over title — a documented exception, `SCREEN_PATTERNS.md` §3); `PendingBadge` (red count pill, "9+" past nine); `AssignmentPickerSheet` / `AssignmentOption` (bordered list, captions, badges, radios). The student detail's `AssignmentSelector` and `ThreadEntry` (note, reply with a Material `edit` control, composer with an outlined floating "Тайлбар" label) live in `gradebook_student_screen.dart`; avatars reuse attendance's `StudentInitialsAvatar`.
- **`BackTitleHeader`** (`shared/widgets`, Issue #327) — `AppBackButton` (arrow) with a title centred on its row: **every pushed page's header** (Issue #368) — E-Contract, Certificate, Notification and its detail, Change password, Attendance detail, Teacher Request (the Programs pages use `ProgramPageHeader` instead, Issue #390). 52 tall at one line, `headerTitle` in `textTitle`, fixed above the page's scroll. The title stays out of the button's band on both sides, wraps and grows the header, and the button is painted last (Issues #318, #325). `test/support/back_button_header.dart` checks it at 320/393 wide and 1.0–3.0× text.
- **`TabTitleBar`** (`shared/widgets`, Issue #368) — a primary tab's header: `screenTitle` left on the gutter, centred in a 63pt `surface` band behind the status bar, a 1pt `divider` rule under it, inside the 480 column; it grows when the title wraps. Courses, the Adult, Junior and Teacher Profiles and Teacher Programs (Хөтөлбөрүүд) draw it (formerly `ProfileTitleBar` and two hand copies). `titleColor` for the Teacher tabs' `teacherTitle`.
- **`ContentColumn`** (`shared/widgets`, Issue #368) — the one spelling of "cap at `maxContentWidth`, centred at the top".
- **In-video back button** (`ExerciseVideoHeader`) — a second copy of the same visual, `Positioned` over the video. **It must be offset by `MediaQuery.paddingOf(context).top`.** Without that, on a real scrolling screen iOS's status-bar touch handling claims taps before Flutter sees them and the button silently does nothing — a bug a zero-inset widget test cannot catch. There is a regression test that simulates a real notch inset; keep it.
- **Tab header** (`ExerciseTabs`) — 49 tall, bottom divider, 2pt blue underline under the active label. Wrapped in a horizontal `SingleChildScrollView` so a longer label or larger text scale cannot reintroduce overflow.

### Modals

Two exist, neither drawn by a Figma frame, so both are assembled from existing tokens and components rather than new design:

- **`SignOutConfirmationDialog`** (`auth`, #166) — a white `Dialog` at `cardRadius` and `cardPadding`: `sectionTitle` title, `body` message, then the filled `AppButton` over the outlined one.
- **`ManagerContactSheet`** (`auth`, #186, restyled #239) — a Material bottom sheet on `AppColors.surface` with `cardRadius` top corners, capped at `maxContentWidth`, inside the bottom safe area, `screenPadding` at the sides, `headingToForm` above and `cardPadding` below: a header cue — `AppIcons.chatCircleDots` (Phosphor ChatCircleDots) in `AppColors.blue` on a round `avatarSize` tile of `AppColors.blue` at 12% — then its own title ("Танд асуух зүйл байна уу?", `LoginStrings.contactSheetTitle`) in `sectionTitle` (a section heading, below Login's `screenTitle`), centred, and a `body` message in `textPrimary`, each `fieldGap` apart; `headingToForm` later, two options drawn as the Login frame's `ContactManagerCard` (at least 80pt, 1pt border, trailing caret) — each led by its Phosphor glyph in `AppColors.blue` on a round `statIconTile` tile of `AppColors.blue` at 12%, with an `itemTitle` action over a `supporting` contact, `fieldGap` apart. No cancel button: barrier tap, drag down and system back dismiss it with nothing launched. **It never cuts an option off** (Issue #343): it may take the whole safe height (`isScrollControlled`, `useSafeArea`) rather than Flutter's default 9/16; under the fixed cue, the heading, message and options scroll when even that cannot fit them, and while more is hidden below, a 24pt fade of the sheet's own `surfaceElevated` over the scroll view's foot says so — it fades out as the end is reached, takes no pointers and has no semantics, and is never drawn while nothing scrolls; a card grows past 80 with the text, and its action and contact wrap rather than ellipsize; and each option's one `Semantics` button carries its own tap action (its `excludeSemantics` drops the `InkWell`'s). A drag on the cue always dismisses it; while everything fits, a drag anywhere does. At the default size on a 393×852 phone it looks exactly as before.

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
- **`excludeSemantics: true` drops the child's tap with its semantics** — give that `Semantics` its own `onTap:`, the same callback the child runs (null while the control is off), or a screen reader announces a button or switch it cannot activate (Issues #359, #402). `test/shared/semantics_tap_test.dart` fails for any `button: true` / `toggled:` node that excludes its children without declaring `onTap:`.
- **Caveat worth knowing:** when a `Semantics(label:)` wraps a widget that *also* contains a `Text` of the same string, the labels merge and `find.bySemanticsLabel('X')` will match neither exactly. Icon-only controls are safe; for text buttons, test with `find.text(...)` instead.
- Minimum tap targets in practice: 40 × 40 for circular controls, 44 for primary buttons.
