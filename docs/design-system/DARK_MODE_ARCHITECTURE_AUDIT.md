# Dark Mode — architecture and design readiness audit

> Issue #250. An audit and plan only: **nothing here is implemented**, no colour has been refactored and no golden changed. Counts were taken from `main` at `5affb09` (after PR #249) with `grep` over `lib/`; re-run them before each phase, because they drift.
>
> Status labels follow `AGENTS.md` §3: `UNKNOWN`, `BACKEND GAP`, `PRODUCT DECISION`.
>
> **Revised in Issue #252** with a product requirement: Dark Mode covers **Adult, Junior and Teacher** through **one global, role-independent theme state** (§14.1). The Adult Profile's "Light mode" switch is not the source of truth; it becomes one of three UI entry points. Phase 0 + Phase 1 are implemented in Issue #252.

---

## 1. Executive summary

- **The app has no theme to switch.**
  - `MaterialApp` (`lib/app.dart:35`) sets `theme: AppTheme.light` only. There is no `darkTheme`, no `themeMode`, no `ThemeMode`/`Brightness` anywhere in `lib/`, and **zero `Theme.of(context)` calls**.
  - Every colour is a compile-time `const` read straight from a class:
    - 422 `AppColors.*` uses in 90 files;
    - 296 feature-palette uses;
    - 163 literal `Color(0x…)` in 47 files.
- **The prior estimates were close, and slightly low.**

  | Measure | Estimate | Actual |
  |---|---|---|
  | `AppColors.*` uses | ~405 | **422** |
  | Literal `Color(0x…)` | ~157 in ~43 files | **163 in 47 files** |
  | `SystemUiOverlayStyle.dark` | ~20 screens | **23 screens** (+2 `.light`) |

  "Light mode switch is local state only" is **confirmed**.
- **No dark design exists.** The repository has no dark Figma frame, no dark token, no dark screenshot and no semantic colour definition beyond the light constants. Implementing dark *values* is blocked on design; this audit does not invent any.
- **Most of the work can still start now, with zero light-mode change.** Introduce a semantic palette whose light values are exactly today's constants, and move widgets onto it behind the existing 55 goldens, which must stay byte-identical. Dark values plug in later.
- **Highest-risk areas:**
  - Course Learning: 63 literals, 15 SVGs, the largest file count;
  - Adult Home and Payments: 88 palette uses, 12 payment goldens, PNG bank logos;
  - Junior Home: a daytime illustrated world;
  - 17 monochrome SVG icons hard-coded `stroke="black"`, painted without a `colorFilter`.
- **All three experiences, one theme.** Adult, Junior and Teacher are all in scope, and none is optional. They share one app-level theme state; each role's Profile is only a way to change it (§14.1).
- **Recommended first implementation task:** Phase 1 (§15). Add an `AppPalette` `ThemeExtension` (light only, identical values) plus a `context.palette` accessor, and pilot it on **Notifications**: small, recent, golden-covered and already `colorFilter`-driven.

---

## 2. Current theme architecture

| Piece | Where | State |
|---|---|---|
| App root | `lib/app.dart` — `AiAcademyApp.build` → `MaterialApp(theme: AppTheme.light, …)` | No `darkTheme`, `themeMode`, `builder`, or inherited theme state |
| Theme | `lib/core/theme/app_theme.dart` — `AppTheme.light` | `useMaterial3`, `fontFamily: 'Manrope'`, `scaffoldBackgroundColor: AppColors.background`, `ColorScheme.fromSeed(seedColor/primary: AppColors.blue, error, surface: AppColors.background)`, `textSelectionTheme`. Its own doc: *"Deliberately thin … the design is not a Material design."* |
| Startup | `lib/main.dart` | Restores the auth session (`AuthSessionStore.attach(SecureSessionPersistence())`) before `runApp`; no theme initialisation or persistence |
| Theme lookups | — | `Theme.of`: **0**. `DefaultTextStyle`: **0**. `MediaQuery` used only for `paddingOf` (17). `platformBrightnessOf`: **0** |
| App-level state | singletons: `AuthSessionStore.instance`, `NotificationCenter.instance`, `SessionRefresher.instance` | The established pattern for app-wide state is a `ChangeNotifier` singleton, not a provider package (there is none in `pubspec.yaml`) |
| Tests | 83 `theme: AppTheme.light` in tests; 94 `MaterialApp(` | Tests wrap screens in their own `MaterialApp` — a dark variant is one parameter away |

**What *does* follow the theme today** is only the few stock Material widgets:
- `CircularProgressIndicator` (23)
- `LinearProgressIndicator` (8)
- `RefreshIndicator` (13)
- `SnackBar` (7)
- `TextButton` (2)
- `showDatePicker` (1)
- `Switch` (6 matches)

They take `colorScheme.primary`/`surface` from `fromSeed`. Everything custom paints from constants.

---

## 3. Colour architecture inventory

### 3.1 Sources

| Source | Count | Notes |
|---|---|---|
| `AppColors` (`lib/core/theme/app_colors.dart`) | 19 tokens; **422 uses in 90 files** | Most used: `surface` 110, `textPrimary` 68, `textSecondary` 52, `blue` 48, `border` 27, `onPrimary` 25, `surfaceSubtle` 23, `background` 13, `error` 11, `success` 9, `surfaceMuted` 8, `borderFocused` 7, `primaryDepth` 6, `disabled` 6, `mutedDepth` 4, `navy` 3, `warning` 2 (`blueDeep`, `violet` unused outside the file) |
| Feature palettes (§4) | 7 classes; **296 uses** | `HomePalette` alone: 152 uses in 36 files across *every* feature |
| Literal `Color(0x…)` | **163 in 47 files**, **79 distinct values** | 51 are the token files' own definitions; **112** sit in feature files |
| File-private `const Color _x` / `static const Color` | **79** | e.g. `certificate_screen.dart` `_cardFill`, `_primaryInk`; `course_module_list_screen.dart` `_page`, `_heroTint`, `_border`, `_primaryInk`, `_secondaryInk` |
| `Colors.*` | 50 | `transparent` 32, `white` 11, `black` 7 |
| Opacity-derived | 16 `withValues`/`withOpacity`/`withAlpha` | e.g. `ManagerContactSheet` `_IconTile.fill = AppColors.blue.withValues(alpha: 0.12)`, back-button shadow `Colors.black.withValues(alpha: 0.08)` |
| `Color.fromARGB/RGBO` | 0 | — |
| Data-layer colours | `course_learning/data/course_module_visuals.dart` | Five module accent colours (`#408CFF`, `#FFC640`, `#BF40FF`, `#FF409C`, `#40FFA3`) live in **data**, not presentation |

### 3.2 The same value under many names

The biggest structural problem is not the count but the duplication. One visual role is spelled many ways:

| Value | Times | Names it goes by |
|---|---|---|
| `#EAEDF0` | 16 | `HomePalette.headerRule`, `.mutedOutline`, `JuniorPalette.mutedFill`, `_ruleColor`, `_border`, `_cardBorder`, `_connectorColor`, `_rowDivider`, `_dividerColor`, `_mutedBorder`, `_progressTrack`, inline `Divider(color: Color(0xFFEAEDF0))` |
| `#F9FAFB` | 10 | `AppColors.surfaceSubtle`, `HomePalette.iconTileFill`, `.mutedFill`, `JuniorPalette.pillFill`, `_page`, `_cardFill`, `_certificationFill`, `_mutedFill` |
| `#D6DBE1` | 9 | `HomePalette.border`, `JuniorPalette.muted`, `exerciseBorderColor`, `_cardBorder`, `_progressTrack`, `CourseLearningBackButton._borderColor` |
| `#2970FF` | 8 (+5 SVGs) | `HomePalette.accent`, `JuniorPalette.accent`, `exercisePrimaryColor`, `_selectedColor`, `_fill`, `_progressFill` — **distinct from `AppColors.blue` `#296CFF`** |
| `#191919` | 8 | `_primaryInk`, `_titleInk`, `_counterInk`, `NotificationHeader` title |
| `#1A1A1A`, `#7D7D7E`, `#808080`, `#B2B2B2`, `#B5B5B5` | 2–4 each | per-screen "ink" greys |

Light-mode text uses **two systems at once**:
- **Alpha-black:** `AppColors.textPrimary` `#E6000000`, `textSecondary` `#80000000`. An alpha-black ink **disappears on a dark surface**: it needs a white-alpha counterpart, not a lighter grey.
- **Opaque greys:** `#191919`, `#1A1A1A`, `#7D7D7E`, `#808080` from later Figma frames.

### 3.3 Semantic groups (what a palette must name)

| Group | Today's representatives |
|---|---|
| Page background | `AppColors.background` `#F4F5F7`, `surfaceSubtle` `#F9FAFB`, white pages (`AppColors.surface`, `_page`) |
| Surface / card | `AppColors.surface`, `_cardFill` `#F9FAFB`/`#F8FAFF`, `JuniorPalette.cardFill` `#EFF4FF` |
| Text | `textPrimary`/`textSecondary` (alpha), `#191919`/`#1A1A1A`/`#7D7D7E`/`#808080`, `HomePalette.statLabel` `#726D6D` |
| Disabled / muted | `AppColors.disabled` `#C9CBDA`, `HomePalette.mutedInk` `#AEAFB0`, notification `_readInk` `#B2B2B2`, `_lockedInk` `#B5B5B5` |
| Divider / border | `#EAEDF0`, `#D6DBE1`, `AppColors.border` `#E4E6EF`, `teacher barTrack` `#E5E7EB` |
| Brand / accent | `AppColors.blue` `#296CFF` (Login), `#2970FF` (everything later), `navy` `#14053D` (splash wordmark), `primaryDepth` |
| Status | success `#22A06B`/`#14AE5C`/`#009951`; error `#E5484D`/`#EF4444`/`#DC3412`; warning `#F0A22E`/`#EBA611`/`#DD940E`; info `#0D99FF`/`#E5F4FF` |
| Overlays | barrier `#99000000` (×2), scanner scrim `#94000000`, shadows `#14000000`/`#1A000000`/`#1F000000`, `secondaryDepth` `#0A000000` |

---

## 4. Feature palette inventory

The **Kind** column groups each palette's values:

| Code | Meaning |
|---|---|
| S | semantic/status |
| V | purely visual |
| Br | brand |
| Bg | background |
| Su | surface |
| T | text |
| Bd | border/divider |

| Palette | Location | Used by | Kind | Theme-ready? | Recommendation |
|---|---|---|---|---|---|
| `AppColors` (19) | `lib/core/theme/app_colors.dart` | 90 files, every feature | Bg, Su, T, Bd, Br, S | No: `const` statics | Keep as the **light reference values**; becomes the source for `AppPalette.light`. Do not delete during migration |
| `HomePalette` (21) | `home/presentation/widgets/home_palette.dart` | **36 files**: Home, Payments, Profile, Certificate, Notifications, Junior, Teacher | Bd (`border`, `headerRule`, `mutedOutline`), Br (`accent`), S (`active*`, `live*`, `overdue*`, `contract*`), T (`statLabel`, `mutedInk`), Su (`iconTileFill`, `mutedFill`), V (`attendanceStart/End`, `secondaryDepth`) | No | It has become the de-facto app palette. Fold its roles into `AppPalette`; keep the class as a deprecated alias layer until callers move |
| `JuniorPalette` (11) | `junior_home/presentation/widgets/junior_home_palette.dart` | 12 Junior files + `attendance_detail_screen.dart` | V (`mapField`), Br (`accent`), Su (`cardFill`), Bd (`cardBorder`, `muted`), S (`dayLesson`, `dayMissed`, `dayNeutral`) | No | Junior-specific semantic roles in a Junior `ThemeExtension`, or a sub-group of `AppPalette`. `mapField` is illustration (see §13) |
| `PaymentFlowPalette` (4) | `home/presentation/payment_flow/payment_flow_widgets.dart:22` | 3 payment-flow files | V (`barrier`, `handle`), T (`bankName`), S (`successFill`) | No | `barrier`/`handle` → shared overlay roles (Teacher's sheet repeats both values) |
| `TeacherScheduleColors` (10) | `teacher/presentation/widgets/teacher_week_grid.dart:335` | 5 Teacher files | Bd (`gridLine`, `barTrack`), Su (`heldFill`), T (`heldInk`, `weekday`, `totalInk`, `captionInk`, `teacherName`, `teacherRole`), V (`handle`) | No | Teacher roles; most collapse into shared text/divider roles |
| `GradebookColors` (2) | `teacher/presentation/widgets/gradebook_widgets.dart:334` | 2 files | T (`name`), Br (`link` `#1501A6`) | No | `link` matches Profile's `_segmentInk` (×3): a shared "link/segment ink" role |
| `TeacherPillColors` (1) | `teacher/presentation/widgets/teacher_pill_button.dart:127` | 6 files | T (`ink` `#1A1A1A`) | No | → primary text role |
| `TeacherHomeColors` (1) | `teacher/presentation/widgets/teacher_class_card.dart:174` | 3 files | T (`ink` `#0B1230`) | No | → primary text, or a named "deep ink" |
| `CourseModuleVisuals` | `course_learning/data/course_module_visuals.dart` | module cards | V/Br (5 accents) | No, and in the data layer | Illustration colours; likely unchanged in dark (`PRODUCT DECISION`). Move to presentation when touched |
| Private per-file constants | 79 across Course Learning, Cohorts, Certificate, Notifications, Payments, Profile | — | all kinds | No | Replace with palette roles file by file. Not every one should become a token: one-off illustration tints stay local but must be dark-aware |

**Not every colour should become a `ThemeData`/`ColorScheme` value.** `ColorScheme` has about 30 Material roles, and this design is not Material (`AppTheme` doc). The app's roles belong in a custom `ThemeExtension`. `ColorScheme` should only be kept consistent, so the stock widgets in §2 look right.

---

## 5. Shared component impact

| Component | File | Colour source today | Theme-ready? | Reach | Recommendation |
|---|---|---|---|---|---|
| `AppButton` (filled/outlined) | `lib/shared/widgets/app_button.dart` | `AppColors.blue/disabled/onPrimary/surface/textPrimary/border`, `Colors.white24/10` splash | No | 24 files (Login, Reset password, Catalog, sheets) | Phase 3, first. Map to `palette.primary`, `onPrimary`, `disabled`, `surface`, `border` |
| `AppTextField` | `lib/shared/widgets/app_text_field.dart` | `AppColors.surface/surfaceMuted/border/borderFocused/error/textSecondary`; `cursorColor` | No | 4 files (Login, Reset password) | Phase 3. Input fill, border, focus and error roles need dark values (Figma) |
| `AppBottomNav` | `lib/shared/widgets/app_bottom_nav.dart` | private `_dividerColor` `#EAEDF0`, `_selectedColor` `#2970FF`, `AppColors.surface`, `textSecondary`; `colorFilter` on SVGs | **Partly**: icons already tinted by `colorFilter` | All three shells (`AdultStudentShell`, `JuniorStudentShell`, `TeacherShell`, via `PersistentTabShell`) | Phase 3. Its `nav_*_active.svg` icons bake `#2970FF` but are tinted anyway: confirm in the dark golden |
| `CourseLearningBackButton` | `course_learning/presentation/widgets/course_learning_back_button.dart` | `AppColors.surface`, `_borderColor` `#D6DBE1`, `Colors.black` 8% shadow, icon `AppColors.textPrimary` | No | **16 files**, including Certificate, Notification List and Detail | Phase 3. White disc with grey ring: needs dark surface/border values. Shadow should go to 0 in dark |
| `NotificationHeader` | `notifications/presentation/notification_header.dart` | title `Color(0xFF191919)` | No | Notification List + Detail | Pilot (Phase 1b) |
| `NotificationTile` | `notifications/presentation/notification_screen.dart` | `HomePalette.accent`, `_readInk` `#B2B2B2`, `AppColors.textPrimary/Secondary`, `HomePalette.headerRule`; bell via `colorFilter` | **Closest to ready**: the glyph is already tinted | List | Pilot |
| `HomeHeader` (bell + logo) | `home/presentation/widgets/home_header.dart` | `AppColors`, `HomePalette`; bell `notification.svg` **without `colorFilter`** (renders the file's black); logo `Image.asset` PNG | No | Adult Home, Junior Home and Progress, Teacher Home | Phase 3. The bell must be tinted; the logo PNG needs a dark-ground variant or check (Figma) |
| Profile parts (`ProfileRow`, `ProfileSwitch`, `ProfileTitleBar`, `ProfileCaption`, `ProfileLanguageToggle`) | `profile/presentation/widgets/profile_parts.dart` | `AppColors`, `HomePalette`, `_segmentInk` `#1501A6`, inline `#1A000000` shadow; row SVGs **without `colorFilter`** | No | Adult, Junior and Teacher Profile | Phase 3. Row icons (12 black-stroke SVGs) must take a tint |
| Pill buttons (`HomePillButton`, `TeacherPillButton`) | `home/…/home_pill_button.dart`, `teacher/…/teacher_pill_button.dart` | `AppColors.blue/primaryDepth/surface/mutedDepth`, `HomePalette.muted*`, `TeacherPillColors.ink`, inline `#14000000` | No | 8 + 5 files | Phase 3. The "depth" bottom edge (a 3D pill) needs dark depth values |
| `ExerciseSubmitButton`, `ExerciseTabs`, `exercise_text_field` | `course_learning/presentation/widgets/` | private `_fill` `#2970FF`, `_muted*`, `exercisePrimaryColor`, `exerciseBorderColor`, inline `Divider(color: #EAEDF0)` | No | 9 files | With Course Learning (Phase 6) |
| Cards: `ProgramCard`, `CohortCard`, `CourseCard`, `HomeStatCard`, `PaymentCard`, `AttendanceCard`, `ContractBanner` | `home/…/widgets/`, `cohorts/…/widgets/`, `courses/…/widgets/` | `HomePalette`, private `_cardFill`/`_cardBorder`, `program_card_background.svg`/`cohort_background.svg` (baked `#3478FF`/`#94AAFF`), `AttendanceCard` `LinearGradient` | No | Home, Cohorts, Catalog | Phase 5. Blue decorated cards may stay as-is in dark (`PRODUCT DECISION`) |
| `CertificatePreview` (`inset`, `outlined`) | `course_learning/presentation/widgets/certificate_preview.dart` | `Image.asset` certificate PNG (`certificate.png`, `certificate_backround.png`), `HomePalette` | Image: n/a | Certificate screen, Course module list, Junior certificate card | The certificate is a **document**: keep it light in dark mode (`PRODUCT DECISION`); only its frame/border follows the theme |
| Sheets and dialogs: `ManagerContactSheet`, `TeacherSessionSheet`, payment sheets, `PaymentSuccessDialog` | various | `AppColors.surface`, barrier `#99000000`, handle `#DBDBDC`, `_IconTile.fill` (blue @12%) | No | 3× `showModalBottomSheet`, 2× `showDialog` | Shared overlay roles (barrier, sheet surface, handle) |
| Loading / empty / error states | per screen (`_Message` in Notifications, Certificate, Profile, …): spinner + `AppTypography.statLabel` + retry `TextButton` | spinner from `ColorScheme`; text from constants | Spinner yes; text no | ~all data screens | Follow text roles; spinner colour follows `ColorScheme.primary` already |
| `SnackBar` | 7 call sites | Material default (dark grey on light) | Yes (Material) | Mark-read, certificate download, refresh errors | Check in dark golden; no work expected |

---

## 6. Typography impact

- `AppTypography` (`lib/core/theme/app_typography.dart`) defines **25 `static const TextStyle`s; 20 bake a colour** (`AppColors.textPrimary`/`textSecondary`/`error`). They're used **200 times**.
- Elsewhere:
  - **80** `TextStyle(` constructions in 23 files;
  - **42** private `const TextStyle _x`;
  - **17** `.copyWith(color: …)`;
  - **251** `Text(` widgets, almost all with an explicit `style:`.
- **Nothing inherits:** there is no `TextTheme` use and no `DefaultTextStyle`. Text colour is always a constant inside a `const` style.
- **The obstacle is `const`.** A colour read from `context` cannot sit in a `const TextStyle`, so each migrated call site loses `const`. The type scale itself (sizes, weights, line heights) is theme-independent and must not change.
- **Recommendation:**
  - Keep `AppTypography`'s geometry.
  - Resolve colour at the call site from the palette: `AppTypography.cardTitle.copyWith(color: context.palette.textPrimary)`, or a small `AppTypography.of(context)` that returns the same styles with palette colours.
  - Do it per component, not in one sweep.
  - **Do not** move the scale into Material `TextTheme`. Its 15 Material roles don't map to the 25 named Figma styles, and a mapping would be guesswork.

---

## 7. SVG / icon impact

### 7.1 Assets

- 45 SVGs:
  - 27 in `assets/icons`;
  - 17 in `assets/images/course_learning`;
  - 1 in `assets/images`.
- 27 raster images (PNG):
  - 15 bank logos in `assets/images/payments`;
  - 5 Junior map images;
  - the certificate images;
  - the splash mark;
  - the app icons.
- **No SVG uses `currentColor`.**

| Class | Files | Colour | Dark-mode behaviour |
|---|---|---|---|
| **Monochrome, black** | 17: `certificate`, `change_password`, `e_contract`, `help_center`, `language`, `light_mode`, `notification`, `payment_receipt`, `privacy_policy`, `profile_edit`, `term_of_service`, `transaction_history`; `course_detail_lock`, `exercise_download`, `exercise_file`, `exercise_resubmit`, `exercise_upload` | `stroke="black"`/`fill="black"` | **Break** (black on dark) wherever drawn without a `colorFilter` |
| Monochrome, coloured | `nav_*_active` ×5 (`#2970FF`), `certificate_badge` (`#2970FF`), `course_detail_completed_check` (`#14AE5C`), `quiz_correct` (`#009951`), `quiz_incorrect` (`#EF4444`), `exercise_play` (`#0B1230`), `contract_warning` (`#B86200`), `adult` (`#86C3FF`), `junior` (`#E16D31`), `module_*` ×6 | one baked hue | Status and brand hues usually survive. `exercise_play` (`#0B1230`, near-black) does not |
| Multi-colour illustration | `grass` (23 colours), `coin` (4), `cloud`, `junior_lesson_day/missed`, `how_ai_works`, `cohort_background`, `program_card_background`, `splash_wordmark` (`#14053D` navy) | many | Not tintable. Each needs a design decision; the navy wordmark on a dark splash is unreadable |

### 7.2 How they are painted

- `SvgPicture.asset` is called **35 times in 28 files**. **Only 4 files apply a `colorFilter`:**
  - `notification_screen.dart`
  - `notification_detail_screen.dart`
  - `teacher_schedule_screen.dart`
  - `app_bottom_nav.dart`
- **The rest paint the file's own colour.** That includes the Home bell (`home_header.dart`, which draws `notification.svg` black) and every Profile row icon (`profile_parts.dart`).
- `Icon(` (Phosphor glyph font via `AppIcons`) appears 33 times, about 32 with an explicit `color:`. Glyph icons are tintable, so they only need their colour argument moved to a palette role.
- **`AppIcons` holds Phosphor `IconData` only.** SVG paths live in per-feature holders (`HomeIcons`, `ProfileIcons`, `PaymentFlowAssets`, `SplashAssets`, …), so there is no central SVG point today.

**Recommendation:**
- Add one small widget, for example `AppSvgIcon(asset, size, color)`, that always applies `ColorFilter.mode(color, BlendMode.srcIn)`, defaulting the colour to `palette.textPrimary`.
- Use it for the 17 black monochrome icons; the 4 already-filtered call sites move to it too.
- Leave illustrations untinted, and list each one for design (§12).
- Converting assets to `currentColor` is not needed.

---

## 8. System UI impact

> **Phase 4 done (Issue #260).** All 25 regions go through `AppSystemUi`.
> - `page(context, navigationBar:)` reads the active theme's brightness, so system UI follows `AppThemeController` → `ThemeMode` → `Theme`, the same path as the colours.
> - `overDarkContent(...)` keeps the scanner and Teacher Schedule light-iconed in every theme.
> - In light mode every style equals the legacy expression, field for field (tested). A theme-mode change updates the regions (tested).
>
> **Flagged, preserved, not changed:** Flutter's `SystemUiOverlayStyle.dark` sets `systemNavigationBarIconBrightness: Brightness.light`. So on every light page Android is asked for light navigation-bar icons over a white or near-white bar. That's existing light-mode behaviour; fixing it (dark icons on light pages) is a small, visible Android change for a separate decision. Native launch windows remain Phase 11.

- **25 screens** wrap themselves in `AnnotatedRegion<SystemUiOverlayStyle>`:
  - **23 use `SystemUiOverlayStyle.dark`** (dark icons on a light page);
  - **2 use `.light`**: `attendance_scanner_screen.dart` (camera with a dark scrim) and `teacher_schedule_screen.dart` (its `_Header` is a `HomePalette.accent` blue band under the status bar).
- All 25 set `statusBarColor: Colors.transparent`. `systemNavigationBarColor` is mostly `AppColors.surface` (16), `background` (3), `surfaceSubtle` (3) or a private `_page` (2).
- **No `SystemChrome.setSystemUIOverlayStyle`, no `setEnabledSystemUIMode`, no edge-to-edge call** in `lib/`.
- **Native:**
  - **Android:** `values/styles.xml` uses `Theme.Light.NoTitleBar`, and `values-night/styles.xml` (the Flutter template default) uses `Theme.Black.NoTitleBar`. A **dark-mode device already shows a black launch window today** before the light Flutter splash. That's a pre-existing flash, worth fixing in the device-validation phase.
  - **iOS:** `LaunchScreen.storyboard` background is white; `Info.plist` sets no `UIUserInterfaceStyle`.

**Recommendation:**
- One helper (for example `AppSystemUi.of(context, navigationBar: …)`) derives icon brightness from the active theme's brightness and the nav-bar colour from the palette.
- Replace the 23 `.dark` call sites with it.
- The 2 `.light` screens draw over dark content in both themes (camera scrim, blue header), so they stay `.light` explicitly.

---

## 9. Profile "Light mode" behaviour

| Fact | Evidence |
|---|---|
| Where | **Adult only.** `lib/features/profile/presentation/profile_screen.dart`: `bool _lightMode = false;` (line ~112), a `ProfileRow` with `ProfileIcons.lightMode` (`assets/icons/light_mode.svg`), label `ProfileStrings.lightMode = 'Light mode'`, a `ProfileSwitch` → `setState(() => _lightMode = value)` |
| Behaviour (before Issue #252) | Flipped local state; **nothing read it**; not persisted. The value lives in the `State`, so it survives tab switches in the persistent `AdultStudentShell` and is lost on sign-out or app restart. The class doc says so: *"light-mode and notification controls hold local state that nothing else reads — there is no … dark palette"* |
| Junior | No row: `junior_profile_screen.dart` doc says *"no light-mode row"*; `junior_profile_screen_test.dart:79` asserts its absence |
| Teacher | No row: `teacher_profile_screen.dart` doc says *"no Light mode row"*; `teacher_profile_screen_test.dart:160` asserts its absence |
| Tests (before Issue #252) | `profile_screen_test.dart`: *"light mode and notification switches start off and flip on tap"* |
| Docs | `PROJECT_CONTEXT.md` ("Profile rows … language and theme controls have no destination yet") |
| **Wording conflict** | The app *is* light, yet the switch labelled **"Light mode" starts OFF**. Read literally, "off" means dark mode is on. The current UI contradicts itself |

**Interim treatment, until approved dark values exist (Issue #252, after a device test).** A switch that flips but changes nothing reads as broken, and "Light mode" *off* in a light app is false. So the Adult row now:
- keeps its place, since Figma draws it;
- **shows the app's real theme:** `Theme.of(context).brightness == Brightness.light`, which is *on* today. That value comes from the global `AppThemeController` through `MaterialApp`, so the private `_lightMode` copy is gone;
- is **inert:** `ProfileSwitch(onChanged: null)` ignores taps and is announced as disabled. This is the treatment Teacher's Notification and MN/EN controls already use for settings with nothing behind them.

The only visible change is that switch: `profile.png`'s diff is a 46 × 25 px box, off → on. Hiding the row was rejected because the frame draws it and Phase 10 would only bring it back. A disabled switch left *off* was rejected because it keeps the false statement. Junior and Teacher still have no row until Phase 10.

**Product requirement (Issue #252): every role gets a control, all writing one global state.**
- The Adult switch is **not** the source of truth. Its local `_lightMode` field is already gone (interim above); in Phase 10 the row becomes interactive and writes `AppThemeController.instance`.
- **Junior Profile gets a new theme row** in its existing "App settings" section (`junior_profile_screen.dart`, after `_Caption(JuniorProfileStrings.appSettingsSection)`), built with Junior's own `_Row`.
- **Teacher Profile gets a new theme row** in its existing "App settings" `ProfileGroup` (`teacher_profile_screen.dart`, after `ProfileCaption(ProfileStrings.appSettingsSection)`), beside Language and Change password.
- All three rows show the same value, because they read the same state. Changing it in one is visible in the others with no extra code.
- Neither the Junior nor the Teacher Figma frame draws this row, so its exact look in those two frames is a `PRODUCT DECISION`. Until design draws it, each row reuses that screen's own existing row and switch parts.

**Product decision still needed** (§13): what the control means:
- "Light mode" on/off (today's label, which contradicts its default);
- "Dark mode" on/off;
- a System / Light / Dark choice, which a switch can't express.

---

## 10. Persistence findings

- **Dependencies** (`pubspec.yaml`): `http`, `flutter_svg`, `url_launcher`, `file_selector`, **`flutter_secure_storage ^11.2.0`**, `cupertino_icons`. No `shared_preferences`, no state-management package.
- **Existing storage:** `SecureSessionPersistence` (`auth/data/secure_session_persistence.dart`) wraps `FlutterSecureStorage` with **key-scoped** `read`/`write`/`delete`. Sign-out deletes the session key only, so a separate preference key would survive sign-out.
- **Options, none added in this audit:**

| Option | For | Against |
|---|---|---|
| A. `flutter_secure_storage`, a separate key (for example `app.theme_mode`) | **No new dependency**; same restore-before-`runApp` pattern as the session (`main.dart`) | Keychain/Keystore for a non-secret; iOS Keychain survives uninstall, so a reinstall keeps the old preference |
| B. `shared_preferences` | The idiomatic store for settings | A new dependency, which needs a task that asks for it (`AGENTS.md` §5) |
| C. No persistence: follow the system (`ThemeMode.system`) | Zero storage; matches platform expectations | Only if the product chooses "follow system" with no in-app override |

**Decision (Issue #252): option A.** Reuse `flutter_secure_storage`, with no `shared_preferences`. Nothing about a theme preference outweighs the cost of a new dependency, and the session already proves the restore-before-`runApp` path. Option A sits behind a small `ThemePreferenceStore` interface, so moving to B later touches one class. The preference is **device-side**: there is no backend requirement, and none should be invented.

| Question | Answer |
|---|---|
| Where it lives | `lib/core/theme/theme_preference_store.dart` (interface) + `SecureThemePreferenceStore` over `FlutterSecureStorage`, key `app.theme_mode`, values `system` / `light` / `dark` |
| Who owns it | `AppThemeController` (§14.1), the only reader or writer. No screen touches storage |
| Startup | `main()` → `await AppThemeController.instance.restore(store)` next to the session restore, **before** `runApp`, so the first frame is already in the right theme (no light flash). A missing or unreadable value falls back to the default (§13.1) |
| Writing | `AppThemeController.setMode(mode)` updates memory and notifies first (instant UI), then writes. A failed write keeps the in-memory choice for this run |
| Sign-out | **Not** cleared. It is a device preference, like the OS setting, and `signOutToLogin` deletes only the session key. Whether a theme should follow the *account* instead is a `PRODUCT DECISION`; account-level would need a backend field (`BACKEND GAP`) |
| Roles | Adult, Junior and Teacher rows all call the same `setMode` and read the same `mode`. There is no per-role key |

**Not in Phase 0 + 1.** Phase 1 ships the controller in memory only (light); persistence lands in Phase 10.

---

## 11. Golden / screenshot test impact

- **55 goldens** (`test/goldens/*.png`), from 24 `matchesGoldenFile` calls in 18 test files. The harness is `test/support/screenshot.dart`:
  - `loadAppFonts`;
  - `useLogicalViewport` at 1× (393 × 875 by default);
  - `iPhonePadding`;
  - `precacheImages`.
- **Covered:**
  - Attendance detail and scanner;
  - Certificate;
  - Course module list, Lesson list, Exercise (11 states), Quiz (4);
  - Adult Home (4), Payment (3), Payment flow (9);
  - Junior Home (4), Junior Profile, Junior Progress;
  - Profile;
  - Notification, Notification Detail;
  - Teacher Home, Profile, Schedule (+2 sheets), Gradebook (4 screens), Request rows.
- **Not covered:**
  - Splash;
  - Login and Reset password (the `AppButton`/`AppTextField` home);
  - Course catalog, Course detail, Cohort list;
  - the Manager contact sheet.

  These are exactly the screens that Phase 3 (shared components) changes, so they should get **light goldens before** migration.
- **Can the harness render dark?** Yes, with no structural change: each test builds its own `MaterialApp(theme: AppTheme.light, …)`. Add `darkTheme`/`themeMode`, or pass a dark `ThemeData`, plus a brightness parameter.
- **Dark goldens go in separate files** (`notification_dark.png`, …). Light files never change name or content.
- **Highest risk:**
  - Payment flow (9 goldens, bank PNGs);
  - Exercise (11);
  - Junior Home (illustrated world);
  - Home (4, gradient attendance card, blue SVG card backgrounds).
- **Notification, Notification Detail and Certificate goldens:** yes, each needs a dark variant once dark values exist. Until then their **light** goldens are the regression gate for the pilot.

---

## 12. Figma / design gaps

### A. Confirmed from the repository or design
- The light palette in full: `AppColors`, the 7 feature palettes and 79 private constants, documented in `DESIGN_SYSTEM.md`.
- Light Figma frames ("App UI" page) for the implemented screens.
- `DESIGN_SYSTEM.md:167`: *"No dark theme. `AppTheme` defines `light` only."*
- **No dark frames, no dark tokens, no dark screenshots, no semantic colour spec** exist in the repository.

### B. Missing, and requires Figma (minimum set before dark *values* are written)
| Role | Why it can't be derived |
|---|---|
| Page background, surface/card, raised surface (sheet/dialog) | Three light greys (`#F4F5F7`, `#F9FAFB`, `#FFFFFF`) carry hierarchy; their dark ordering is a design choice |
| Primary / secondary / disabled text | Light uses alpha-black *and* opaque greys; dark needs one decided system |
| Divider / border (`#EAEDF0`, `#D6DBE1`, `#E4E6EF`) | Contrast on dark is a design call |
| Primary blue (`#296CFF` vs `#2970FF`) and its pressed/"depth" edge | Brand blue on dark often needs a lighter tone |
| Button states: filled, outlined, disabled, pressed depth | `AppButton`, pill buttons |
| Input background, border, focus, error | `AppTextField` (focus is deliberately *dark*, not blue, in light: `DESIGN_SYSTEM.md`) |
| Error / success / warning / info fills and inks | Light fills (`#FFF5F5`, `#EBFFEE`, `#FFFAE5`, `#E5F4FF`) become glaring on dark |
| Bottom navigation | Bar, rule, selected and unselected |
| Modal / bottom sheet, barrier, handle | — |
| Shadows / elevation | Light uses soft black shadows and depth edges; dark usually replaces them with surface tone |
| Status bar / navigation bar | Follows the backgrounds above |
| Feature colours | Junior map world, Course module accents, Home blue cards, Payment fills, Teacher grid, quiz states |
| Assets | Splash wordmark (navy), Home logo PNG, `exercise_play` (`#0B1230`), bank logos on dark, certificate image |

### C. Product decisions required
See §13.

### D. Engineering decisions we can make independently
- `ThemeExtension`-based semantic palette; `context.palette` accessor.
- Light values = current constants, byte-identical.
- `AppSvgIcon` tinting; `AppSystemUi` helper.
- `ThemeMode` controller as a `ChangeNotifier` singleton (repository pattern).
- Dark-golden naming; test harness parameter.
- Order of migration; consolidation of duplicate literals into roles.
- Persistence interface (storage choice is gated by §10/§13).

---

## 13. Product decisions required (`PRODUCT DECISION`)

1. **Default:** follow the system setting, or light until the user opts in? Also: is the preference per device (assumed, §10) or per account?
2. **The control:**
   - a "Light mode" switch (today, and contradictory: §9);
   - a "Dark mode" switch;
   - a System / Light / Dark selector.
3. ~~**Scope by role.**~~ **Decided (Issue #252):** Adult, Junior and Teacher, one global state. Still open: the Junior and Teacher row's look, since no frame draws it (§9).
4. **Junior world:** does the illustrated daytime map (sky, clouds, grass, coins) stay as-is, get a night variant, or get dimmed?
5. **Documents and brand media:**
   - does the certificate stay light?
   - do bank logos get dark-ground variants?
   - do the splash wordmark and Home logo get them?
6. **Blue decorated cards** (Program card, Cohort card, Attendance gradient): unchanged in dark?
7. **Rollout:** ship dark mode only when *every* screen is migrated (recommended), or screen by screen behind a flag?

---

## 14. Recommended architecture

Built for: no light regression, incremental migration, and reuse of what exists.

1. **`AppPalette extends ThemeExtension<AppPalette>`** (`lib/core/theme/app_palette.dart`).
   - **Contents:** about 30–40 semantic roles named by *use*, not hue:
     - `pageBackground`, `surface`, `surfaceSubtle`, `surfaceMuted`;
     - `textPrimary`, `textSecondary`, `textDisabled`;
     - `divider`, `border`, `borderFocused`;
     - `primary`, `onPrimary`, `primaryDepth`;
     - `success*`, `error*`, `warning*`, `info*`;
     - `barrier`, `sheetHandle`, `shadow`;
     - plus a small Junior/Teacher group.
   - **Light values:** `AppPalette.light` is built **from today's constants** (`AppColors.*`, `HomePalette.*`, …), so it is identical by construction.
   - **Dark values:** `AppPalette.dark` waits for Figma.
2. **`AppTheme.light` / `AppTheme.dark`**: each registers its `AppPalette` in `extensions:` and keeps `ColorScheme` consistent for stock widgets. `AppTheme.dark` is not wired to `MaterialApp` until values exist.
3. **Accessor:** `extension on BuildContext { AppPalette get palette => Theme.of(context).extension<AppPalette>()!; }`. That one lookup replaces `AppColors.x` at migrated call sites.
4. **Text:** `AppTypography` geometry unchanged; colour from the palette at use (§6).
5. **Icons:** `AppSvgIcon` for monochrome SVGs (§7); illustrations listed for design.
6. **System UI:** `AppSystemUi` derives the overlay from the theme (§8).
7. **Theme state:** `AppThemeController` (`ChangeNotifier`, `ThemeMode`), read by `AiAcademyApp` via `ListenableBuilder`; see §14.1. It starts at `ThemeMode.light` until the product decision and dark values land, so the plumbing ships with no visible change (Phase 1). It is restored in `main()` before `runApp` from Phase 10.
8. **Persistence:** a `ThemePreferenceStore` interface; storage per §10.

### 14.1 Global theme state — one for every role

```
ThemePreferenceStore (flutter_secure_storage, key app.theme_mode)   ← Phase 10
        │ restore() in main(), before runApp      ▲ write on setMode()
        ▼                                         │
AppThemeController.instance  (ChangeNotifier, ThemeMode)            ← Phase 1
        │ ListenableBuilder in AiAcademyApp
        ▼
MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark*, themeMode: controller.mode)
        │ Theme / AppPalette via context.palette
        ▼
Adult shell · Junior shell · Teacher shell · Login · Splash · every pushed route

Writers (Phase 10): Adult Profile row · Junior Profile row · Teacher Profile row
                    → AppThemeController.instance.setMode(…)
*AppTheme.dark exists only from Phase 9, when approved values do.
```

- **One state, above the role split.** The controller sits above `MaterialApp`, so it is set before Splash runs and before `homeRouteFor` picks a role's shell. No shell, screen or role owns theme state, and no role can drift from another.
- **It follows the repository's existing singleton pattern** (`AuthSessionStore.instance`, `NotificationCenter.instance`): a `static final instance` for the app, and an injectable instance for tests. No state-management package.
- **Screens never hold a copy.** A Profile row reads `controller.mode` inside a `ListenableBuilder` and writes `setMode`. The retired Adult `_lightMode` field is exactly the kind of copy this forbids.
- **System UI follows it too** (Phase 4): `AppSystemUi` reads the resolved brightness from `Theme.of(context)`, not a role or a screen flag.

**Deliberately not proposed:**
- a state-management package;
- mapping the design onto Material `ColorScheme`/`TextTheme` roles;
- deleting `AppColors`/`HomePalette` in one pass (they become the light reference, then aliases, then go when unused);
- converting SVGs to `currentColor`.

---

## 15. Migration phases

In each phase, **"Light goldens: unchanged"** means the existing PNGs must pass **without** `--update-goldens`.

| # | Phase | Scope | Major files | Depends on | Risk | Tests | Figma? |
|---|---|---|---|---|---|---|---|
| 0 | **Coverage first** | Light goldens for uncovered screens: Splash, Login, Reset password, Course catalog/detail, Cohort list, Manager contact sheet | new `*_screenshot_test.dart` | — | Low | New goldens only | No |
| 1 | **Foundation + pilot** | `AppPalette` (light), `context.palette`, register on `AppTheme.light`; a test that `AppPalette.light` equals the constants; **global `AppThemeController`** (in memory, `ThemeMode.light`, no UI, no persistence) wired into `MaterialApp` above every role's shell; migrate **Notifications** (`NotificationHeader`, `NotificationTile`, Detail; shared by all three roles) as the pilot | `core/theme/*`, `app.dart`, `notifications/presentation/*` | 0 | Low | Light goldens unchanged; palette-equality test; controller test | No |
| 2 | **Token consolidation** | Map the duplicated literals (§3.2) to roles; no value changes | palettes, private constants | 1 | Low–Med (naming) | Light goldens unchanged | No |
| 3 | **Shared components** | `AppButton`, `AppTextField`, `AppBottomNav`, `CourseLearningBackButton`, `HomeHeader` (and tint its bell), Profile parts (tint row icons), pill buttons, sheets/barrier; `AppSvgIcon` | `lib/shared/widgets/*`, `profile_parts.dart`, `home_header.dart`, … | 1–2 | **Med–High** (wide reach) | All 55 + Phase-0 goldens unchanged | No |
| 4 | **System UI** | `AppSystemUi`, driven by the global theme's brightness; replace 23 `.dark` sites in all three roles | 25 screens | 1 | Low | Widget test of overlay per brightness | No |
| 5 | **Adult** (required) | Home, Payments + payment flow, Certificate, Profile, Attendance, Catalog/Cohorts | `home/`, `certificates/`, `profile/`, `cohorts/`, `courses/`, `attendance/` | 3–4 | High (12 payment goldens) | Light goldens unchanged | No |
| 6 | **Course Learning** | Module list, Lesson list, Exercise, Assignment, Quiz; move `CourseModuleVisuals` colours to presentation | `course_learning/` (47 files, 63 literals) | 3 | **High** | Light goldens unchanged (Exercise ×11, Quiz ×4) | No |
| 7 | **Junior** (required) | Home, Progress, Profile, map, calendar, certificate card | `junior_home/` | 3 | High (illustration) | Light goldens unchanged | No (until §13.4) |
| 8 | **Teacher** (required) | Home, Schedule (+ sheets), Gradebook, Request, Profile | `teacher/` | 3 | Med | Light goldens unchanged | No |
| 9 | **Dark values** | `AppPalette.dark`, `AppTheme.dark` from the **approved** version of [DARK_MODE_DESIGN_PROPOSAL.md](DARK_MODE_DESIGN_PROPOSAL.md) (Issue #254), dark asset variants; harness brightness parameter; dark goldens for every golden screen | `core/theme/*`, assets, tests | 1–8 + **Figma** | Med | New `*_dark.png` goldens | **Yes** |
| 10 | **Preference + controls, all roles** | `ThemePreferenceStore` + `SecureThemePreferenceStore` (existing `flutter_secure_storage`); `AppThemeController.restore` in `main()` before `runApp` (startup initialisation); `setMode` persists. **Three entry points to the one state:** Adult row made interactive (it already reads the global theme), **new Junior row** in App settings, **new Teacher row** in App settings. Theme survives sign-out (§10) | `core/theme/*`, `main.dart`, `profile/profile_screen.dart`, `junior_home/…/junior_profile_screen.dart`, `teacher/…/teacher_profile_screen.dart` | 1, 9 + §13 decisions | Med | Restore-on-start test; write/fallback tests; each Profile row changes the global mode; **a change from one role is seen by the others**; sign-out keeps the mode; Profile goldens updated for the new rows only | Decision (control type; Junior/Teacher row look) |
| 11 | **Device validation + native** | Physical iOS and Android in both modes; Android `values-night` launch window and iOS launch screen | `android/app/src/main/res/values*/styles.xml` (not the protected iOS files) | 9–10 | Low | Device checklist | Maybe |

**Every role is in scope, and none is optional.** Phases 4–8 and 10 each name Adult, Junior and Teacher work, and Dark Mode is not released until all three are migrated (§13.7). Propagation across screens needs no per-screen work beyond reading `context.palette`: one `MaterialApp` theme reaches every route of every role.

Phases 2–8 are purely mechanical "same colour, new address" changes. They can be split per feature folder into PRs small enough to review, and they don't wait on design.

---

## 16. Regression strategy — "Light mode looks exactly the same"

1. **Goldens are the gate.**
   - Every migration PR runs the full suite with the existing 55 goldens (plus the Phase-0 ones) and **must not** use `--update-goldens` for any light file.
   - A light golden diff is a bug, never a re-baseline.
2. **Identity by construction.**
   - `AppPalette.light` is built from the existing constants, not retyped.
   - A unit test asserts each light role equals its legacy constant. A wrong mapping fails a test before it reaches a screen.
3. **Coverage before change.** Phase 0 adds goldens for screens that have none before their components move.
4. **Widget tests stay.**
   - The existing colour assertions (for example `notification_screen_test.dart` checks `AppColors.textPrimary`/`#B2B2B2`, `notification_detail_screen_test.dart` checks `HomePalette.liveFill`) keep passing unchanged.
   - A test that needs editing to pass is a red flag.
5. **Theme-specific tests (from Phase 9):**
   - the same screen pumped under both themes;
   - dark goldens in separate files;
   - an `AppSystemUi` brightness test;
   - controller and persistence tests.
6. **Device checks:** at each feature phase, a light-mode pass on a physical iPhone. The golden harness doesn't render iOS text shaping exactly; the Notification Detail wrap showed this.

---

## 17. Risk assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Light regression from a mis-mapped role | Med | High | Palette-equality test; goldens unchanged |
| Losing `const` causes rebuild/perf churn | Low | Low | Only colour-bearing widgets lose `const`; measured screens are small |
| Black monochrome SVGs invisible in dark | **Certain** if missed | High | `AppSvgIcon`; a grep check (`SvgPicture.asset` without a tint) in review |
| Alpha-black text invisible on dark | **Certain** if missed | High | Text roles only from the palette |
| Uncovered screens regress unseen (Login, Splash, Catalog) | Med | High | Phase 0 |
| Dark palette invented ad hoc | Med | High | Phase 9 blocked on Figma; no dark value without a source |
| Junior illustrations look wrong in dark | High | Med | §13.4 before Phase 7 ships dark |
| Long-running parallel features conflict with migration PRs | Med | Med | Small per-folder PRs; migrate a feature when it's quiet |
| Dark-device launch flash (existing) | Certain on Android dark devices today | Low | Phase 11 |

---

## 18. Estimated scope

- **Code reach:** ~110 distinct files under `lib/`:
  - 90 that use `AppColors`;
  - 47 with literals (overlapping);
  - the palette users.
- **Volume:** ~720 colour references (422 + 296); 25 overlay regions; 35 SVG draws; 33 glyph icons; 200 `AppTypography` uses.
- **Tests:** ~111 test files run unchanged. Dark goldens: about 55 new PNGs at Phase 9, if every light golden gets a dark twin.
- **Rough PR count:** 10–14. Phase 0: 1; Phase 1: 1; Phase 2: 1; Phase 3: 2; Phase 4: 1; Phase 5: 2; Phase 6: 2; Phase 7: 1; Phase 8: 1; Phases 9–11: 2–3.
- **Design time (Phase 9) is the critical path, not engineering.**

---

## 19. Explicitly out of scope (this task)

- Implementing Dark Mode, `darkTheme` or `ThemeMode`.
- Any colour, palette, typography or SVG change.
- Changing the Profile switch or its tests.
- Adding a dependency.
- Modifying or regenerating any golden.
- Native launch-screen changes. The protected iOS files (`project.pbxproj`, `Runner.xcscheme`, `AppDelegate.swift`) are never touched.
- Backend work: dark mode needs none.

---

## 20. Recommended next implementation task

> **Done in Issue #252 (Phase 0 + 1).**
> - **Phase 0:** light goldens added for Splash, Login, Reset password, Manager contact sheet, Course catalog, Course detail and Cohort list (`test/goldens/`, 7 new).
> - **Palette:** `lib/core/theme/app_palette.dart` (light only, `context.palette`), registered on `AppTheme.light`.
> - **Global theme state:** `lib/core/theme/app_theme_controller.dart`, wired into `AiAcademyApp` above every role's shell. Light only, no UI, no persistence (§14.1).
> - **Pilot:** Notifications (`NotificationHeader`, `NotificationTile`, `NotificationDetailScreen`) reads only `context.palette`.
> - **Proof:** every pre-existing golden passed unchanged.
>
> Not migrated yet: the header's `CourseLearningBackButton` and the screens' `SystemUiOverlayStyle.dark`, which are Phase 3 and Phase 4. **Next: Phase 2 (token consolidation).**
>
> **Phase 2 done (Issue #256).**
> - `AppPalette` has 57 roles with exactly the shipped light values. Each value is written once in `AppColors`.
> - The feature palettes and the duplicated private constants (115 sites) now alias those roles, guarded by `color_literal_consolidation_test.dart`.
> - Every golden is unchanged.
>
> **Phase 3 done (Issue #258).** The shared components that are actually reused across roles read only `context.palette`, proven under a sentinel palette:
> - `AppButton`, `AppTextField`, `AppBottomNav`;
> - `CourseLearningBackButton`, `HomeHeader`;
> - `profile_parts`.
>
> Monochrome SVGs go through `AppSvgIcon` (new roles `iconInk` and `wordmark`), tinted only when the role differs from the asset's colour, because a same-colour tint still moves edge pixels. All goldens are unchanged. Single-role widgets (`HomePillButton`, `TeacherPillButton`, Junior Profile parts, sheets) move with their feature phases.
>
> **Next: Phase 4 (system UI).**
>
> **Phase 5 done (Issue #262).** The Adult experience reads colours only through `context.palette`.
> - **Scope:** `home` (incl. Payment and the payment flow), `cohorts`, `courses`, `profile`, `payments`, `enrollments`, plus Certificate and the attendance scanner, which Junior also opens. That's 29 files, about 218 direct reads and 36 baked-colour typography uses.
> - **Nine Adult roles** hold the remaining single-use values (68 roles).
> - **Guard:** `adult_palette_scope_test.dart` keeps the scope clean, with a documented allowlist.
> - **Goldens:** all unchanged.
> - **`course_learning`** is shared by Adult and Junior and is Phase 6.
>
> **Design definition (Issue #254):** [DARK_MODE_DESIGN_PROPOSAL.md](DARK_MODE_DESIGN_PROPOSAL.md) proposes the dark semantic palette, the new roles Phase 2 should add, and per-role (Adult/Junior/Teacher) treatment. Every value is PROPOSED and awaits design approval, which gates Phase 9 only.


**"chore: theme foundation — AppPalette (light) and Notifications pilot"**, i.e. Phase 0 + Phase 1:
1. Add light goldens for Splash, Login, Reset password, Course catalog, Course detail, Cohort list, Manager contact sheet.
2. Add `lib/core/theme/app_palette.dart` (`ThemeExtension`, light values from existing constants), register it on `AppTheme.light`, add `context.palette`, plus a unit test that every light role equals its legacy constant.
3. Migrate `NotificationHeader`, `NotificationTile` and `NotificationDetailScreen` to `context.palette`.
4. **Acceptance:** every existing golden, including `notification.png`, `notification_detail.png` and `certificate.png`, passes unchanged; analyze is clean; no dark values; no visible change.

In parallel, ask design for the §12.B minimum set, and ask product for the §13 decisions. Both gate Phase 9 and Phase 10, not Phases 0–8.
