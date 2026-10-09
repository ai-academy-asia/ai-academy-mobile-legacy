# Design System

> **Figma is the source of truth for visual design. This document is not.**
>
> What follows is an inventory of the tokens the Flutter code currently defines, plus the rules for working with them. It is *implementation context*. Where the code and a Figma frame disagree, **Figma wins and the code changes** — see [COMPONENT_PATTERNS.md](COMPONENT_PATTERNS.md) and [FIGMA_TO_FLUTTER.md](FIGMA_TO_FLUTTER.md).
>
> The official design system is to be **reconstructed from Figma**, not reverse-engineered from these widgets. Treat every value below as "what is implemented", never as "what is correct".

### Reconciling this with `AGENTS.md`

The root [AGENTS.md](../../AGENTS.md) §1 says new screens stay visually consistent with the established (Login-derived) design system by default. That rule still holds and is not in conflict with Figma-first — they operate at different levels:

- **Default:** a new screen stays visually consistent with the established Login-derived system (these tokens). Do not invent a parallel visual language.
- **Override:** where a Figma frame disagrees with what is implemented, **Figma wins and the code changes.**

In short: consistency is the default; Figma is the authority. Consistency is never a reason to reproduce a mismatch that Figma contradicts.

## 1. Three tiers — keep them apart

The most important rule in this document. Every visual value belongs to exactly one tier:

| Tier | Lives in | Example |
|---|---|---|
| **Global token** | `lib/core/theme/` | `AppColors.blue`, `AppDimens.screenPadding`, `AppTypography.heading` |
| **Screen/feature-local token** | a `const` at the top of that feature's file | `_tileTintOpacity` (0.24) in `CourseModuleCard` |
| **Screen-specific exception** | inline, with a comment saying why | the 164.5 × 40 "Continue learning" button on Module List |

**A value is only promoted to a global token when more than one screen genuinely shares it** *and* Figma confirms it is one value, not a coincidence. Two colours that were once screen-local tokens show why (both are roles now):

- Exercise Detail's blue, `#2970FF`, vs `AppColors.blue = #296CFF` — close but **not identical**, evidently sampled from two different Figma captures. Kept separate rather than silently treated as the same colour: it is `AppPalette.accent` / `accentText`, not `primary` (Phase 6b, Issue #268, retired its old local alias `exercisePrimaryColor`).
- `#D6DBE1` vs `AppColors.border = #E4E6EF` — a cooler, darker grey, which is `AppPalette.outline`. Its old local alias `exerciseBorderColor` was retired in Phase 6c (Issue #270), once Quiz read the role too.

**Do not "clean these up" by merging them into `AppColors`** without Figma confirming they are the same token.

## 2. Colour

`lib/core/theme/app_colors.dart`. Brand colours were sampled from the logo export; neutrals are the design's.

**Reading colours: `context.palette` (Issue #252).** `AppPalette` (`lib/core/theme/app_palette.dart`) names colours by role (`surface`, `textPrimary`, `divider`, `accent`, …). It is a `ThemeExtension` on `AppTheme.light`, and its light values *are* the constants below and in `HomePalette` (held equal by `test/core/theme/app_palette_test.dart`).
- **Every screen** reads `context.palette`, not `AppColors` / `HomePalette` / a literal. That covers Adult, Junior, Teacher, the Learning Flow, Login and Splash (Phases 1–9). Per-feature guards in `test/core/theme/*_palette_scope_test.dart` keep it that way.
- **New widgets** do the same.

The app-wide theme mode is `AppThemeController.instance`, one state for Adult, Junior and Teacher. It is **light**: `AppTheme.dark` (with `AppPalette.dark`) exists since Phase 9 (Issue #276) as a **candidate**, built from the proposal's unapproved values and labelled role by role (PROPOSED / DERIVED / UNRESOLVED, `DARK_MODE_DESIGN_PROPOSAL.md` §18). It is wired as `MaterialApp.darkTheme`, but nothing sets a mode that reaches it until Phase 10.

**Roles (Phase 2, Issue #256; `iconInk` and `wordmark` in Phase 3, #258; the Adult roles in Phase 5, #262; the Learning Flow roles in Phase 6a, #266; the Exercise Detail roles in Phase 6b, #268; the Quiz roles in Phase 6c, #270; the Junior roles in Phase 7, #272; the Teacher roles in Phase 8, #274).** `AppPalette` has 94 roles. Each role's light value is written **once**, as a role-named constant in `AppColors`.
- The feature palettes (`HomePalette`, `PaymentFlowPalette`) and the private constants that used to repeat a literal now **alias** those constants. `JuniorPalette` was retired in Phase 7 (Issue #272) and the Teacher palettes (`TeacherScheduleColors`, `GradebookColors`, `TeacherPillColors`, `TeacherHomeColors`) in Phase 8 (Issue #274), once each role read the roles.
- `color_literal_consolidation_test.dart` fails if a role's value reappears as a literal anywhere else in `lib/`.
- New code reads `context.palette`; the aliases exist only until Phases 3–8 move their call sites.

| Group | Roles (light value) |
|---|---|
| Grounds | `pageBackground` `#F4F5F7` · `surfaceSubtle` `#F9FAFB` · `surface` / `surfaceElevated` `#FFFFFF` · `surfaceMuted` `#EFF0F3` · `surfaceTile` `#F5F5F5` |
| Text | `textPrimary` black 90 % · `textSecondary` black 50 % · `textTitle` `#191919` · `textStrong` `#1A1A1A` · `textSupporting` `#7D7D7E` · `textMuted` `#808080` · `textInactive` `#B2B2B2` · `textLocked` `#B5B5B5` |
| Lines | `border` `#E4E6EF` (fields, outlined buttons, the bottom card, Course and Cohort card edges) · `borderFocused` black 90 % · `divider` `#EAEDF0` · `outline` `#D6DBE1` (cards, pills) · `outlineSubtle` `#E5E7EB` |
| Brand | `primary` `#296CFF` · `onPrimary` · `primaryDepth` `#004FED` · `accent` / `accentText` `#2970FF` · `accentSubtle` `#E5F4FF` · `accentSubtleOutline` `#BDE3FF` (the outline of an `accentSubtle` pill — the attendance summary badge) · `linkInk` `#1501A6` · `wordmark` `#14053D` (navy) |
| Icons | `iconInk` `#000000`: the monochrome SVGs' own ink, applied by `AppSvgIcon` only when it differs from the asset's |
| Controls | `disabled` `#C9CBDA` · `disabledInk` `#AEAFB0` · `neutralDepth` `#E0E0E0` · `subtleDepth` black 4 % |
| Status | `error` `#E5484D` · `errorInk` `#DC3412` · `errorFill` `#FFF5F5` · `errorOutline` `#EF4444` · `success` `#22A06B` · `successInk` `#009951` · `successFill` `#EBFFEE` · `successOutline` `#14AE5C` · `successLabel` `#14AE5C` (a status pill's label drawn in its outline green; text, so its own role) · `successFillStrong` `#CCEBDC` · `warning` `#F0A22E` · `warningFill` `#FFFAE5` · `warningOutline` `#EBA611` · `warningInk` `#DD940E` (amber as text — the quiz result's score) · `infoInk` `#0D99FF` · `infoFill` `#E5F4FF` |
| Overlays | `barrier` black 60 % · `sheetHandle` `#DBDBDC` · `shadow` black 10 % · `shadowSubtle` black 8 % |
| Adult | `accentOutline` `#155EEF` (Payment's next installment) · `timelineConnector` `#BAC5FF` · `textFaint` black 30 % · `textDeep` `#101828` (bank names) · `textStatLabel` `#726D6D` · `attendanceGradientStart` `#175FEF` / `attendanceGradientEnd` `#518BFF` · `surfaceTinted` `#F8FAFF` (cohort card) · `scrim` black 58 % (scanner) |
| Learning Flow | `learningHeroTint` `#E8F3FF` (Course Module List's header wash) · `surfaceLocked` `#EFEFEF` (a locked module's tile) · `cardDepth` `#EAEDF0` (the flat band under a lifted card, an unanswered quiz option included) · `outlineFaint` `#EAEDF0` (that card's edge, the certification panel's, Exercise Detail's tab card and the quiz feedback card) · `textAnswerLetter` `#8A8A8A` (a quiz option's A/B/C/D) |
| Exercise Detail | `videoSurface` `#080F35` (the video header, dark in every theme) · `mediaControl` white (its back and play discs) · `onMediaControl` black 90 % (the glyph on a disc) · `mediaControlOutline` `#D6DBE1` (the back disc's ring) · `onMedia` white (text and its pill on the video) · `progressTrack` `#E4E6EF` (an upload/download ring's and bar's track) |
| Junior | `juniorCard` `#EFF4FF` · `juniorCardBorder` `#D1D3F5` · `juniorMapSky` `#BFD9F8` · `calendarNeutral` `#F2F2F3` · `calendarLesson` `#E5F4FF` · `calendarMissed` `#FFE7E7` · `juniorMutedFill` `#EAEDF0` (a map element not yet reached: a locked node, the certificate panel) · `juniorHeaderRule` `#E4E6EF` (Junior Home's header rule) · `onJuniorMapSky` white (a glyph on the sky: the map's spinner) |
| Teacher | `scheduleBand` `#2970FF` (the Schedule band, under light status-bar glyphs) · `scheduleHeld` `#EFF4FF` · `scheduleHeldInk` `#787A80` · `teacherTitle` `#0B1230` (Home/Gradebook/class titles) · `teacherNameInk` `#0C226E` / `teacherRoleInk` `#6371A2` (a teacher's name and role) · `teacherDetailInk` `#9CA3AF` (Profile email/phone, the sheet's "/ total") · `teacherCaptionInk` `#4B5563` · `teacherSheetRule` `#D6DBE1` (the session sheet's rule) · `dangerOutline` `#DC3412` (a destructive pill's edge) · `avatarPlaceholder` `#EAEDF0` / `avatarPlaceholderInk` `#AEAFB0` (a placeholder avatar and its glyph) |

Some roles share a light value but stay separate roles, because their meaning (and proposed dark value) differs:
- `accentSubtle` / `infoFill` / `calendarLesson`;
- `juniorCard` / `scheduleHeld`;
- `accent` / `accentText` / `scheduleBand`;
- `surface` / `surfaceElevated`;
- `divider` / `cardDepth` / `outlineFaint` — a rule, a band and an edge;
- `surface` / `mediaControl` / `onMedia` / `onPrimary` (white) and `textPrimary` / `onMediaControl` — the video's controls and text stay as they are on the always-dark video, whatever the page does;
- `border` / `progressTrack` — a field's edge and a transfer's track;
- `outline` / `mediaControlOutline` — a page outline and the ring of a control on the always-dark video;
- `divider` / `juniorMutedFill`, `border` / `juniorHeaderRule`, `surface` / `onJuniorMapSky` — a rule and a fill, an edge and a rule, a surface and a glyph on the sky;
- `accentSubtle` / `calendarLesson` — the summary pill's fill and a calendar day's tint;
- `outline` / `teacherSheetRule`, `errorInk` / `dangerOutline`, `divider` / `avatarPlaceholder`, `disabledInk` / `avatarPlaceholderInk` — an edge and a rule, a label and an edge, a rule and a fill, a disabled label and a placeholder glyph.

Different light values are never merged.

Single-use colours stay local until their screen migrates, then become roles: the attendance gradient and `statLabel` `#726D6D` in Phase 5, the quiz result score `#DD940E` (`warningInk`) in Phase 6c.

| Token | Value | Role |
|---|---|---|
| `blue` | `#296CFF` | Primary action, focused border, cursor |
| `blueDeep` | `#0262F8` | Logo mark only — not interaction |
| `violet` | `#4316FF` | Logo gradient terminal |
| `navy` | `#14053D` | Wordmark. **Belongs to the logo, not to body text** |
| `background` | `#F4F5F7` | The page |
| `surface` | `#FFFFFF` | Cards, fields, buttons |
| `surfaceMuted` | `#EFF0F3` | Fill of a control not accepting input |
| `surfaceSubtle` | `#F9FAFB` | A ground barely off-white, behind lists of white rows |
| `border` | `#E4E6EF` | Resting border |
| `borderFocused` | `0xE6000000` — black @ 90% | Focused field border/label/cursor — **dark, not blue** |
| `textPrimary` | `0xE6000000` — black @ 90% | Headings, values, card titles |
| `textSecondary` | `0x80000000` — black @ 50% | Placeholders, supporting lines, chevrons |
| `error` | `#E5484D` | Error border/label/message |
| `success` | `#22A06B` | Completed, correct |
| `warning` | `#F0A22E` | Partial state; the quiz preview card's score |
| `disabled` | `#C9CBDA` | Unpressable control fill |
| `onPrimary` | `#FFFFFF` | Foreground on filled buttons |

Two deliberate rules encoded here: **body text is black at two opacities, never the brand navy** (tinting it navy made early passes read heavy and purple), and **focus is dark, not blue** — a blue focus ring is a Material habit this design does not use.

**`textPrimary` and `borderFocused` are the same underlying value, `0xE6000000`.** Two names, one colour, kept separate because they carry different roles: one is body-text colour, the other is a focus affordance. Do not collapse them into a single token — a future Figma frame could move focus off black without touching body text.

## 3. Typography

Manrope, five weights, bundled (`assets/fonts/`), full Cyrillic coverage for the Mongolian copy.

**Read this before changing any size:** `AppTypography`'s own doc comment records that the scale was set **by eye against the Figma render and then taken ~15% below the measured values** (measured: heading 26, body 13, small 11 → shipped: 22, 12, 10), while **line heights were kept at the layout's values** so boxes and gaps did not move. That is a deliberate, documented decision. Changing it is a design decision requiring Figma confirmation — not a bug fix.

| Style | Size / line-height / weight | Used for |
|---|---|---|
| `heading` | 22 / 34 / 700 | Screen heading |
| `programTitle` | 24 / 30 / 700 | Home cohort name — the dashboard's anchor |
| `catalogPrice` | 20 / 26 / 700 | Catalog card price |
| `splashWordmark` | 20 / 24 / 800 | Splash brand mark |
| `catalogTitle` | 17 / 22 / 700 | Catalog card title |
| `profileName` | 16 / 22 / 700 | Profile header name |
| `cardHeading` | 15 / 20 / 600 | Repeating list-item title |
| `statValue` | 15 / 20 / 700 | Statistic value |
| `settingsRowLabel` | 14 / 20 / 500 | Settings row label |
| `catalogSectionValue` | 13 / 18 / 600 | Value under a card caption |
| `statLabel` | 13 / 18 / 500 | Statistic caption |
| `fieldValue` · `fieldPlaceholder` | 12 / 20 / 500 | Field text / placeholder |
| `buttonLabel` | 12 / 20 / 600 | Button label |
| `cardTitle` | 12 / 20 / 600 | Bottom-card title |
| `checkboxLabel` | 12 / 20 / 500 | Checkbox label |
| `profileJoinedDate` | 12 / 16 / 500 | Join date |
| `segmentLabel` | 12 / 16 / 700 | MN/EN segment |
| `catalogSectionLabel` | 11 / 16 / 500 | Card section caption |
| `catalogTrackLabel` | 11 / 14 / 600 | Track badge label |
| `catalogStatusLabel` | 11 / 14 / 700 | Open/Full pill |
| `cardSupporting` | 10 / 16 / 500 | Supporting line |
| `fieldFloatingLabel` | 10 / 16 / 500 | Floated field label |
| `badgeLabel` | 10 / 14 / 600 | Pill label |
| `fieldError` | 10 / 16 / 500 | Field error text |

All carry `leadingDistribution: TextLeadingDistribution.even`. Local `.copyWith(fontSize: …, fontWeight: …)` off the nearest base style is an accepted idiom and is used widely; **inventing a new top-level style is not** unless a Figma frame needs one the scale genuinely lacks.

## 4. Spacing, sizing and radii

`lib/core/theme/app_dimens.dart`. Measured from the Figma Login frame (a 393 × 852 artboard), then extended per screen.

**The layout spine — memorise these three:**

| Token | Value | Meaning |
|---|---|---|
| `designWidth` | 393 | Reference device width |
| `screenPadding` | 16 | Left/right gutter |
| `contentWidth` | 361 | `393 − 2×16`. Every block is this wide |

Also global: `maxContentWidth` 480 (the column stops and centres on tablet/desktop rather than stretching), `fieldHeight` 56, `fieldGap` 12, `buttonHeight` 44, `buttonGap` 12, `cardPadding` 16, `caretSize` 18, `avatarSize` 44, `avatarEditSize` 36, `settingsRowHeight` 40, `settingsRowIconSize` 20, `bottomNavHeight` 72, `statIconTile` 36, `headerLogoHeight` 40 (the frame draws 32; scaled up per Issue #188) beside `headerActionSize` 44 (the frame's own, so the Home header keeps the frame's height), `progressBarHeight` 6, `strengthBarHeight` 6.

The Home header's "AI academy" / "Asia" wordmark is not a text style. It is the Figma export of outlined paths (`splash_wordmark.svg`, the splash screen's own), drawn at the lockup's height. The design does not set it in Manrope, so live text could only approximate it (Issue #188).

**Radii:** `fieldRadius` 12 · `cardRadius` 12 · `homeCardRadius` 16 (Home/Course-Learning cards are visibly rounder) · `checkboxRadius` 4 · `buttonRadius` = `buttonHeight / 2` (a pill).

**Borders:** `borderWidth` 1 · `borderWidthEmphasis` 1.5 (focused/errored field).

A recurring inner width in `course_learning` is **329** — a form/action block inset 16 either side of the 361 content width. It is not in `AppDimens`; it appears as a literal in that feature's widgets.

### The no-arbitrary-value rule

Reach for a token first, a documented screen-local constant second, and a bare literal only when a Figma frame gives a one-off measurement — in which case **write the measurement and its reasoning in a comment**. The existing code does this consistently (e.g. "Figma measurement: the card is 361 × 86, its icon container 56 × 56"). A literal with no provenance is the thing to avoid.

## 5. Icons

Two sources, in priority order:

1. **Phosphor font** (`AppIcons`, `assets/fonts/Phosphor.ttf`) — the design's own set; Figma layers use Phosphor names. Currently declared: `caretRight`, `caretLeft`, `arrowLeft`, `check`, `eye`, `eyeClosed`, `checkCircle`, `xCircle`, `house`, `bookOpenText`, `user`, `money`, `calendarCheck`, `qrCode`, `phone`, `envelope`, `chatCircleDots`.
   **Codepoints must be confirmed against the bundled font's cmap, never guessed.** Existing entries document how they were confirmed.
2. **Material `Icons.*`** — the documented fallback when no confirmed Phosphor codepoint exists. **Always leave a comment saying why**, matching the precedent set in `exercise_info_section.dart`.

   All 11 Material glyphs currently in `lib/`, so a new one is a deliberate addition rather than an accident:

   | Icon | Where | Role |
   |---|---|---|
   | `keyboard_arrow_down` / `keyboard_arrow_up` | `exercise_info_section.dart` | Read more / Read less chevron |
   | `close` | `assignment_attachment_card.dart`, `quiz_progress_header.dart` | Remove attachment; close quiz |
   | `refresh` | `assignment_tab.dart` | Resubmit button leading icon |
   | `check` | `assignment_attachment_card.dart` | Completed-download tile |
   | `person` | `profile_screen.dart` | Profile avatar fallback |
   | `payments_outlined` | `home/widgets/payment_card.dart` | Payment card |
   | `event_available_outlined` | `home/widgets/attendance_card.dart` | Attendance card |
   | `qr_code_scanner` | `home/widgets/program_card.dart` | Attendance check-in affordance |

   Note the split: the `course_learning` fallbacks are small UI affordances with no Phosphor equivalent confirmed, while the four Home/Profile glyphs (`person`, `payments_outlined`, `event_available_outlined`, `qr_code_scanner`) carry more visual weight. **Whether those four should be Phosphor or bespoke SVGs is `UNKNOWN` — it needs a Figma frame to settle.** Phosphor-first still stands: reach for a confirmed Phosphor codepoint before adding a twelfth Material glyph.
3. **SVG assets** (`flutter_svg`) — for artwork rather than glyphs: track logos, module icons, exercise chrome. **Only add a new SVG when no existing icon can reproduce the Figma icon**, and never duplicate one that already exists.

Common icon sizes: 14 (inside a small badge), 18–20 (row/field), 20 (settings row), 24 (state icon), 28 (tile glyph), 32 (file/leading tile).

## 6. Elevation and shadow

There is **no global elevation scale**, and the app deliberately does not use Material's default elevation shadows — they read as hard drop shadows where the design is soft. Shadows are painted explicitly on a `Container`/`DecoratedBox`, tuned per context:

- **Card "lift"** — `black @ 8%`, blur 6, offset (0, 3): module/lesson cards.
- **Large quiet panel** — `black @ 5%`, blur 16, offset (0, 4): the certification section.
- **Primary button depth** — `AppColors.blue @ 35%`, blur 10, offset (0, 4): a *blue-tinted* shadow, not grey.
- **Disabled/subtle** — `black @ 6%`, blur 6, offset (0, 2).

`Material(elevation: …)` is used only for small circular controls where its shape handling is wanted.

## 7. What is NOT yet a system

Honest gaps, to be resolved from Figma rather than invented:

- **No spacing scale.** Gaps are literals (4, 8, 12, 16, 20, 24) chosen per frame. Whether Figma defines a formal scale is `UNKNOWN`.
- **No motion/animation tokens.** Only two durations exist in the app (splash 7000 ms, its transition 400 ms).
- **No dark theme.** `AppTheme` defines `light` only, and no dark palette exists in Figma or the repository. The audit and phased plan are in [DARK_MODE_ARCHITECTURE_AUDIT.md](DARK_MODE_ARCHITECTURE_AUDIT.md) (Issue #250). A **proposed, unapproved** dark palette and component treatment for design review is in [DARK_MODE_DESIGN_PROPOSAL.md](DARK_MODE_DESIGN_PROPOSAL.md) (Issue #254). None of its values is in code.
- **No breakpoint system** beyond `maxContentWidth` 480.
- **No documented empty/error/loading visual specs** — see [COMPONENT_PATTERNS.md](COMPONENT_PATTERNS.md) §6 for what the code currently does.
- **Figma MCP is unavailable** (quota exhausted). Reconstruction proceeds from screenshots/exports supplied in the task.
