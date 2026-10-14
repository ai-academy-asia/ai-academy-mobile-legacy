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
| **Global token** | `lib/core/theme/` | `AppColors.blue`, `AppDimens.screenPadding`, `AppTypography.cardTitle` |
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

The app-wide theme mode is `AppThemeController.instance`, one state for Adult, Junior and Teacher. It is **Light by default, or Dark by the user's choice** (Issue #282). `AppTheme.dark` (with `AppPalette.dark`, Phase 9, Issue #276) is wired as `MaterialApp.darkTheme`, with each role labelled PROPOSED, DERIVED or UNRESOLVED (`DARK_MODE_DESIGN_PROPOSAL.md` §18). Every role's Profile has a "Dark mode" switch (Adult since Issue #282; Junior and Teacher since Issue #284; renamed from "Light mode" in Issue #288). All three set the one `ThemePreference`, through `AppThemeController.darkModeOn` and `setDarkMode`: on is Dark, off is Light. The change applies to the whole app at once, every role, route, dialog and sheet included.

The preference belongs to the **signed-in account**, not the device (Issue #286). It is saved under `aia.theme.preference.<id>`, where `<id>` is `GET /auth/me`'s `id` (`DATA_AND_API.md`). `followAccountTheme` keeps `AppThemeController` on the session's account:
- signed out, or signed in but not yet identified → Light;
- identified → that account's own choice, or Light.

A persisted session carries its account, so the choice is restored before the first Flutter frame. Sign-out deletes no account's choice. The device-wide `aia.theme.preference` key of #278–#285 is deleted unread on launch, since it can't be attributed to an account. System is not offered yet (§16.1), and a stored `system` reads as Light. Every widget reads colour from `context.palette`. A monochrome black SVG goes through `AppSvgIcon`, so it follows `iconInk` in dark and stays untinted in light.

The debug-only `AIA_DARK_PREVIEW` define (Issue #280) has been removed; the Profile switch replaces it.

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
| Junior | `juniorCard` `#EFF4FF` · `juniorCardBorder` `#D1D3F5` · `juniorMapSky` `#BFD9F8` · `calendarNeutral` `#F2F2F3` · `calendarLesson` `#E5F4FF` · `calendarMissed` `#FFE7E7` · `juniorMutedFill` `#EAEDF0` (a map element not yet reached: a locked node; and the white certificate card's 3pt edge, Issue #410) · `juniorMutedGlyph` `#A4A6A8` (the padlock sprite's own ink; tints the attendance-completed node's tick, Issue #415) · `juniorHeaderRule` `#E4E6EF` (Junior Home's header rule) · `onJuniorMapSky` white (a glyph on the sky: the map's spinner) |
| Teacher | `scheduleBand` `#2970FF` (the Schedule band, under light status-bar glyphs) · `scheduleHeld` `#EFF4FF` · `scheduleHeldInk` `#787A80` · `teacherTitle` `#0B1230` (Home/Gradebook/class titles) · `teacherNameInk` `#0C226E` / `teacherRoleInk` `#6371A2` (a teacher's name and role) · `teacherDetailInk` `#9CA3AF` (Profile email/phone, the sheet's "/ total") · `teacherCaptionInk` `#4B5563` · `teacherSheetRule` `#D6DBE1` (the session sheet's rule) · `dangerOutline` `#DC3412` (a destructive pill's edge) · `avatarPlaceholder` `#EAEDF0` / `avatarPlaceholderInk` `#AEAFB0` (a placeholder avatar and its glyph) · `studentAvatarBlue` `#3B79B7` / `studentAvatarRed` `#B74C3B` / `studentAvatarTeal` `#00BCA3` with `onStudentAvatar` `#FFFFFF` (a student's initials avatar, manual attendance — Issue #374) · `qrInk` `#000000` / `qrBackground` `#FFFFFF` (the attendance QR, the same in either theme) · `programJuniorTint` `#E16D31` (the Junior program card's pattern, Issue #390) |

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

Manrope, five weights, bundled (`assets/fonts/`), full Cyrillic coverage for the Mongolian copy. It is the app's only typeface (`ThemeData.fontFamily`). The two "AI academy Asia" wordmarks — splash and header — are SVG exports (`splash_wordmark.svg`), not text, so no type style touches them.

**One role, one style, every screen** (Issue #366). `AppTypography` is a semantic scale: pick the role a piece of text plays, not a size. The same role draws the same on every screen — a course's name is `cardTitle` on Home, the Courses tab, the module list, certificates, contracts and teacher cards alike. The sizes are Figma's own, a modest step up from the earlier scale (which had been set ~15% below the measured Figma values; that rule is retired).

| Role | Size / line / weight | Used for |
|---|---|---|
| `display` | 32 / 40 / 700 | A figure that is the point of its screen — a quiz score |
| `screenTitle` | 26 / 34 / 700 | A top-level screen's heading: tabs (Courses, Profile, Programs), Login, Reset Password |
| `headerTitle` | 20 / 28 / 700 | The centred title of a pushed screen's back header |
| `cardTitle` | 20 / 28 / 700 | **A course's name**, wherever drawn; a profile's name |
| `sectionTitle` | 18 / 26 / 700 | A heading inside a screen: module / exercise title, quiz question, sheet and dialog titles |
| `itemTitle` | 16 / 22 / 700 | A list row's primary line: module, lesson, notification, gradebook rows, names; summary-card and banner titles |
| `itemLabel` | 16 / 22 / 500 | A row's lighter primary line, where the row is content: a material's file name, a settings row, a quiz answer, a checkbox |
| `body` | 16 / 24 / 400 | Running text: descriptions, messages, notification bodies |
| `bodyStrong` | 16 / 24 / 700 | A label leading a value ("Дараагийн хичээл:"), a statistic's or status's value |
| `supporting` | 14 / 20 / 500 | Secondary lines: "35% complete", a stat's caption, durations, file sizes, empty and error messages |
| `caption` | 13 / 18 / 500 | A small line over or under a title: the cohort over a course's name, "Modules 5", section captions, card metadata |
| `dateTime` | 15 / 22 / 500, tabular figures | Dates and times: a lesson's time, a notification's age, a month |
| `buttonLabel` | 16 / 24 / 600 | Primary and pill buttons |
| `buttonSmall` | 14 / 20 / 600 | Compact controls: retry links, filter and small pills, the fixed-width "Continue learning" CTA, "Read more" |
| `tabLabel` | 16 / 22 / 500, `w700` selected | Tabs |
| `navLabel` | 12 / 16 / 600 | Bottom navigation |
| `badge` | 13 / 16 / 700 | Status capsules, the MN/EN segment, avatar initials |
| `fieldText` | 16 / 24 / 500 | What is typed into a field, and its resting label / placeholder |
| `fieldLabel` | 12 / 16 / 500 | A field's floated label (`AppTextField` hands Material 16 so its 75% float lands on 12) |
| `fieldHelper` | 13 / 18 / 500 | The line under a field: its error or hint; inline error lines |

All carry `leadingDistribution: TextLeadingDistribution.even` and **no colour**: every use supplies one from `context.palette`, so light and dark both apply. `AppTheme` maps Material's `bodyMedium` (snack bars) to `body` and `labelLarge` (`TextButton`) to `buttonSmall`.

**Rules.**
- A local `copyWith` sets the colour, and at most a role's documented variant (`tabLabel` in `w700`). **No local size, weight or line height** — that is a different role, or an exception below.
- A screen-local style is an alias of a role (`const TextStyle _titleStyle = AppTypography.cardTitle;`), named for what it draws.
- Fixed heights around text are minimums (`BoxConstraints(minHeight: …)`), so system text scaling grows them; text that must stay one line ellipsizes only where a deliberate decision says so (notification rows, #359; module titles, #349). Where two items share a row, a `Wrap` lets the second drop under the first rather than overflow.
- System text scaling is never capped.

**Documented exceptions** (each says so where it is made):

| Where | Why |
|---|---|
| Attendance calendar's weekday letters and day numbers (13) | Dense grid — seven columns share the width |
| Teacher week grid's hour labels (12) and session blocks (11); the week strip (12 / 14) | Dense grid, with its own large-text fallback (#357) |
| Teacher bottom bar's labels (10, `AppBottomNav.labelSize`) | The reference sets them at 10 (the label is "Хөтөлбөрүүд" since Issue #390) — its former "Дүнгийн хуудас" measured 77 wide, 10pt's own width (93 at 12); kept when the redesign dropped Нүүр for three tabs (Issue #370) |
| Junior map cards (course card, certificate card) | Scale with the map's width from the role sizes; the certificate card's gap under the name absorbs its growth so the card stays the frame's |
| The incoming-request sheet's room and date/time (`bodyStrong` at 15, letter spacing 0, `TeacherClassCard.compactDetails`) | The reference sets them on one line, untracked; Manrope at 16 with the theme's inherited 0.25 tracking measures 353 of the card's 329, at 15 untracked 328 (Issue #372). They still wrap where they do not fit |
| `trackLabel` 16 / 1 / 600 ("Adult" / "Junior"), `AttendanceTally`'s 36 / 800 count (the held sheet and the QR attendance screen), the Junior ring's % | Sized to their container |

**Legacy.** The old screen-named tokens (`heading`, `cardSupporting`, `cardHeading`, `catalog…`, `statLabel`, `fieldError`, …) remain in `AppTypography`'s *Legacy* section only for code deliberately left unmigrated — the Assignment-only widgets, the unreachable Course catalog / detail and E-Contract signing screens, and the debug-only payment preview. Do not use them in new code; migrate a screen to the roles when it is next touched.

## 4. Spacing, sizing and radii

`lib/core/theme/app_dimens.dart`. Measured from the Figma Login frame (a 393 × 852 artboard), then extended per screen.

**The layout spine — memorise these three:**

| Token | Value | Meaning |
|---|---|---|
| `designWidth` | 393 | Reference device width |
| `screenPadding` | 16 | Left/right gutter |
| `contentWidth` | 361 | `393 − 2×16`. Every block is this wide |

Also global: `maxContentWidth` 480 (the column stops and centres on tablet/desktop rather than stretching), `fieldHeight` 56, `fieldGap` 12, `buttonHeight` 44, `buttonGap` 12, `cardPadding` 16, `caretSize` 18, `avatarSize` 44, `avatarEditSize` 36, `settingsRowHeight` 40, `settingsRowIconSize` 20, `bottomNavHeight` 72, `statIconTile` 36, `headerLogoHeight` 40 (the frame draws 32; scaled up per Issue #188) beside `headerActionSize` 44 (the frame's own, so the Home header keeps the frame's height), `progressBarHeight` 6, `strengthBarHeight` 8.

**Page layout (Issue #368)** — every page of a kind shares these; the full standard is [SCREEN_PATTERNS.md](SCREEN_PATTERNS.md) §1:

| Token | Value | Rule |
|---|---|---|
| `tabHeaderHeight` | 63 (+ 1pt rule) | A primary tab's title band (`TabTitleBar`) |
| `backHeaderHeight` | 52 = `backButtonTop` 12 + `backButtonSize` 40 | A pushed page's header (`BackTitleHeader`) |
| `tabContentTop` | 16 | A tab's header rule → first content |
| `pageContentTop` | 24 | A pushed page's header → first content |
| `cardGap` | 16 | Between list cards and sections of cards |
| `tileGap` | 8 | Between two tiles sharing a line |
| `pageBottom` | 24 (+ the bottom inset) | After a page's last content |

The Home header's "AI academy" / "Asia" wordmark is not a text style. It is the Figma export of outlined paths (`splash_wordmark.svg`, the splash screen's own), drawn at the lockup's height. The design does not set it in Manrope, so live text could only approximate it (Issue #188).

**Radii:** `fieldRadius` 12 · `cardRadius` 12 (fields' neighbours: the Login contact card) · `homeCardRadius` 16 (**every content card**, Issue #368 — the cohort card and lesson items included) · `checkboxRadius` 4 · `buttonRadius` = `buttonHeight / 2` (a pill).

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
- **No motion/animation tokens.** Durations are local to their widget: the splash (7000 ms, its transition 400 ms), the Junior map's scenery (`JuniorSceneryMotion`) and its check-in node's pulse (`JuniorMapNodeTile.pulseScale` 1.06, `pulsePeriod` 1400 ms; Issue #410). Both Junior map animations still under the platform's reduced motion (`MediaQuery.disableAnimationsOf`).
- **No dark theme.** `AppTheme` defines `light` only, and no dark palette exists in Figma or the repository. The audit and phased plan are in [DARK_MODE_ARCHITECTURE_AUDIT.md](DARK_MODE_ARCHITECTURE_AUDIT.md) (Issue #250). A **proposed, unapproved** dark palette and component treatment for design review is in [DARK_MODE_DESIGN_PROPOSAL.md](DARK_MODE_DESIGN_PROPOSAL.md) (Issue #254). None of its values is in code.
- **No breakpoint system** beyond `maxContentWidth` 480.
- **No documented empty/error/loading visual specs** — see [COMPONENT_PATTERNS.md](COMPONENT_PATTERNS.md) §6 for what the code currently does.
- **Figma MCP is unavailable** (quota exhausted). Reconstruction proceeds from screenshots/exports supplied in the task.
