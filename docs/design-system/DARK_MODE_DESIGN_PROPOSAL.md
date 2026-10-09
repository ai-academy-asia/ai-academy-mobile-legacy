# Dark Mode — design proposal

> **Status: PROPOSAL, not approved design.** Issue #254. There is **no approved Dark Mode Figma**. Every dark value here is **PROPOSED**: a reasoned starting point for design and product review, derived from this repository's real light-mode code and goldens.
>
> **Phase 9 (Issue #276) put these values into code as a gated candidate**, by the product owner's decision. `AppPalette.dark` and `AppTheme.dark` exist and are wired into `MaterialApp`, but they are **unreachable**: `AppThemeController` stays `ThemeMode.light` and nothing sets another mode until Phase 10. Every role is marked PROPOSED, DERIVED or UNRESOLVED (§18). **Nothing is approved by being in code.** Approval (§17) still gates shipping.
>
> Builds on the Phase 1 architecture (PR #253): one `AppPalette` `ThemeExtension`, one global `AppThemeController` for Adult, Junior and Teacher. See [DARK_MODE_ARCHITECTURE_AUDIT.md](DARK_MODE_ARCHITECTURE_AUDIT.md) for the inventory and phased plan.
>
> **Supporting images**, generated from the values in this document:
> - [`dark-mode-proposal/palette.png`](dark-mode-proposal/palette.png): every role, light (shipped) next to dark (proposed), with contrast;
> - [`dark-mode-proposal/mock_light_vs_dark.png`](dark-mode-proposal/mock_light_vs_dark.png): an illustrative card, notification rows, a button and the bottom bar in both modes. It's a drawing, not a Flutter render.
>
> **Contrast figures** are WCAG 2.x ratios (relative luminance). Translucent colours are first composited over the ground they sit on.

---

## 1. Current Light Mode — what the code actually does

Sources:
- the goldens (`test/goldens/*.png`, 62 screens across all three roles);
- `AppColors`, `HomePalette`, `JuniorPalette` and the Teacher palettes;
- the 79 private colour constants listed in the audit §3–4.

**What holds across the whole app:**
1. **Three cool near-white grounds carry the hierarchy.**
   - `#F4F5F7` (`AppColors.background`): the page, and Profile's caption bands;
   - `#F9FAFB` (`surfaceSubtle`, also `HomePalette.iconTileFill`/`mutedFill` and a dozen private constants): a quieter ground;
   - `#FFFFFF`: cards, rows, sheets and bars.

   Depth comes from white on grey, not from shadows: shadows are faint (4–8 % black) and decorative.
2. **One brand blue in two near-identical values.**
   - `#296CFF` (`AppColors.blue`): Login, `AppButton`.
   - `#2970FF` (`HomePalette.accent`, `JuniorPalette.accent`, five SVGs, eight literals): every frame after Login.

   The same blue is used **both as a fill** (buttons, progress, selected chips, Teacher's Schedule band and session blocks) **and as text** ("3 хоног дутуу", "08/04 • 09:00", links, the selected tab). The text use is only 4.32:1 on white.
3. **Text is two systems at once.**
   - **Alpha-black:** `textPrimary` black @ 90 %, `textSecondary` black @ 50 %.
   - **Opaque greys** from later frames: `#191919` ×8, `#1A1A1A` ×4, `#7D7D7E` ×4, `#808080` ×3, `#726D6D`, `#B2B2B2` (read/inactive).

   Supporting text is **4.00:1**, below AA for small text, so light mode is already borderline there.
4. **Hairlines do the structure.** `#EAEDF0` (×16, under about 12 names) divides rows and bars; `#D6DBE1` (×9) outlines cards, pills and the back-button ring.
5. **Status is a three-part recipe:** pale fill + saturated outline + darker ink.
   - Green: `#EBFFEE` / `#14AE5C` / `#009951` ("Active").
   - Blue: `#E5F4FF` / `#0D99FF` ("Finished" / live).
   - Red: `#FFF5F5` / `#EF4444` / `#DC3412` (overdue).
   - Amber: `#FFFAE5` / `#EBA611` (contract).
6. **"Depth" edges on pills.** `HomePillButton`/`TeacherPillButton` draw a 3D bottom edge: `primaryDepth` `#004FED` under blue, `mutedDepth` `#E0E0E0` / `secondaryDepth` black @ 4 % under white.

**Exceptions found** (they matter for dark):
- **Already-dark element:** the Exercise video header is `#080F35`, a near-black navy.
- **Saturated blocks with white text:**
  - Teacher Schedule's header band (`HomePalette.accent`, under a `SystemUiOverlayStyle.light` status bar);
  - the Attendance card gradient `#175FEF → #518BFF`;
  - session blocks.
- **Light-on-light decoration:** `program_card_background.svg` / `cohort_background.svg` (`#3478FF`/`#94AAFF` shapes) sit on white cards.
- **Raster artefacts designed for white:**
  - the certificate images;
  - 15 bank logos;
  - the Junior map backdrop/islands/nodes (PNG);
  - multi-colour SVGs (`grass` ×23 colours, `coin`, `cloud`).
- **Monochrome icons that are simply black** (17 SVGs, `stroke="black"`). Most are drawn without a tint, including the Home bell and every Profile row icon.
- **The wordmark.** `splash_wordmark.svg` (`#14053D` navy) is drawn on both Splash and the Home header. It is **single-colour**, so it can be tinted rather than re-exported.
- **Role identity is narrow:**
  - **Track glyphs:** `adult.svg` `#86C3FF` blue, `junior.svg` `#E16D31` orange.
  - **Junior:** the illustrated sky world (`mapField` `#BFD9F8`), pale-blue cards (`cardFill` `#EFF4FF`, `cardBorder` `#D1D3F5`) and calendar day tints.
  - **Teacher:** the blue Schedule band and grid.
  - Everything else is shared.

---

## 2. Dark Mode design principles (proposed)

1. **Same product, dark room.**
   - Keep the brand blue, type scale, spacing, radii, component shapes and every role's identity.
   - Change grounds, inks and lines; nothing moves or resizes.
2. **Hierarchy by lightness, not by shadow.** Light mode stacks white on grey. Dark mode stacks **lighter on darker**: page < subtle < surface < elevated. Drop shadows, which don't read on dark, become tone steps plus the existing hairlines.
3. **Cool, blue-leaning near-black, not pure black.** The light greys are cool (`#F4F5F7`, `#EAEDF0`), and so is the brand. A slightly blue neutral (`#0F1217` …) keeps that temperature, avoids OLED smear on scroll, and leaves room below surfaces for depth.
4. **Opaque inks in dark.** Alpha-black text cannot simply become alpha-white, because its effective colour would drift with every ground. Proposed text roles are opaque and checked against each ground they sit on.
5. **Meet AA where light mode didn't.** Body and supporting text ≥ 4.5:1, titles ≥ 7:1. "Faint by design" states (read rows, disabled) stay visibly quieter, but at ≥ 3:1.
6. **Fills keep the brand; text gets a lifted brand.** A blue *fill* with white text is unchanged between modes, so the button looks identical. Blue *text* on a dark ground needs a lighter blue, a new `accentText` role (§3).
7. **Status keeps its recipe, inverted in weight.** Dark tinted fill + lighter ink + mid outline: same hue, same meaning.
8. **Artwork is decided per asset, never auto-inverted.** Monochrome glyphs are tinted by role. Illustrations, logos and documents keep their colours, and get a frame or plate where needed (§8).
9. **One semantic palette for all three roles.** Adult, Junior and Teacher read the same `AppPalette` through the same `AppThemeController`. Role-specific colours exist only where §1 found real role identity, and they are roles in that same palette, not separate palettes.

---

## 3. Proposed semantic roles

The 19 roles in `AppPalette` today (PR #253) stay. This proposal **adds** the roles marked *new*. These are needed because a single light value currently plays two parts that dark mode must separate.

| Group | Role | Used for (from the code) |
|---|---|---|
| Grounds | `pageBackground` | the page; Profile caption bands; Notification Detail body ground |
| | `surfaceSubtle` | quiet grounds: lesson pages (`_page` `#F9FAFB`), icon tiles, muted pills |
| | `surface` | cards, rows, list screens, the bottom bar |
| | `surfaceElevated` *(new)* | sheets, dialogs, the session sheet, Manager contact sheet. In light mode it equals `surface`; in dark mode it must sit above cards |
| | `surfaceMuted` | a field or control not accepting input |
| Text | `textPrimary` | headings, values, body |
| | `textTitle` | the opaque near-black titles of later frames (`#191919` ×8) |
| | `textSecondary` | captions, supporting lines, ages, chevrons; folds `#7D7D7E`, `#808080`, `statLabel` `#726D6D` |
| | `textInactive` | read notification rows, the Teacher weekday, locked lesson ink |
| Lines | `divider` | row and bar rules (`#EAEDF0` and its 12 aliases) |
| | `border` | card, pill and back-button outlines (`#D6DBE1`, `#E4E6EF`) |
| | `borderFocused` | focused field: **neutral high-contrast, not blue** (a light-mode rule kept) |
| Brand | `primary` | Login/`AppButton` blue fill |
| | `accent` | the later frames' blue fill: progress, selected chips, unread dot, Teacher band and blocks |
| | `accentText` *(new)* | blue used **as text or thin ink**: links, dates, "3 хоног дутуу", the selected tab label/icon. Light: same as `accent` |
| | `accentSubtle` | pale-blue fill behind blue ink (`liveFill`, Notification disc, held sessions, Junior day-with-lesson) |
| | `onPrimary` | text and icons on blue fills |
| | `primaryDepth` *(new as role)* | the 3D bottom edge under blue pills |
| | `neutralDepth` *(new)* | the 3D edge under white/muted pills (`mutedDepth`, `secondaryDepth`) |
| Status | `success`/`successFill`/`successOutline` | "Active", correct answers, completed checks |
| | `error`/`errorFill`/`errorOutline` | overdue, wrong answers, field errors |
| | `warning`/`warningFill`/`warningOutline` | contract banner, the quiz score |
| | `info`/`infoFill`/`infoOutline` | "Finished"/live pill |
| | `disabled` / `disabledInk` *(new)* | unusable control fill and its label |
| Overlay | `barrier` *(new)* | behind sheets and dialogs (`#99000000` ×2) |
| | `scrim` *(new)* | the scanner's camera scrim (`#94000000`) |
| | `shadow` *(new)* | the faint card lift (black 5–8 %) |
| | `sheetHandle` *(new)* | grab handle (`#DBDBDC` ×2) |
| Role identity | `trackAdult`, `trackJunior` *(new)* | the Adult/Junior track glyph tints (`#86C3FF`, `#E16D31`) |
| | `juniorCard`, `juniorCardBorder` *(new)* | Junior's pale-blue course and progress cards |
| | `juniorMapSky` *(new)* | the map's sky field behind the illustration |
| | `calendarLesson`, `calendarMissed`, `calendarNeutral` *(new)* | Junior attendance calendar day tints |
| | `scheduleBand` *(new)* | Teacher Schedule's header band |
| | `scheduleHeld`, `scheduleHeldInk` *(new)* | Teacher grid's held-session fill and ink |

Folded, not new: `#1A1A1A`/`#0B1230`/`#0C226E`/`#101828` inks → `textPrimary`. `#1501A6` (segment and link ink) → `accentText` (pending §16.5).

---

## 4. Proposed Light → Dark mapping (all dark values PROPOSED)

Light values are what ships today, and they stay exactly as they are. Ratios are measured on the role's usual ground.

### 4.1 Grounds

| Role | Light (shipped) | **Dark (PROPOSED)** | Why |
|---|---|---|---|
| `pageBackground` | `#F4F5F7` | `#0F1217` | Darkest step; cool, blue-leaning (principle 3). Not `#000`: leaves room for depth and avoids OLED smear |
| `surfaceSubtle` | `#F9FAFB` | `#14181E` | Between page and surface, as in light |
| `surface` | `#FFFFFF` | `#1A1F27` | Cards one step above the page (1.13:1, a visible step without a shadow) |
| `surfaceElevated` | `#FFFFFF` | `#232934` | Sheets and dialogs one step above cards (1.13:1). Light can't express this: it uses shadow |
| `surfaceMuted` | `#EFF0F3` | `#20252E` | A disabled field reads "set back"; distinct from `surface` by tone, not brightness |

### 4.2 Text

| Role | Light | **Dark (PROPOSED)** | Light → dark contrast | Why |
|---|---|---|---|---|
| `textPrimary` | black @ 90 % | `#ECEFF3` | 17.6 → **14.4** (surface), 12.7 (elevated) | Opaque off-white; pure white glares on near-black |
| `textTitle` | `#191919` | `#F5F7FA` | 17.6 → **15.4** | A hair brighter than body, mirroring light's opaque title |
| `textSecondary` | black @ 50 % | `#A3ACB9` | **4.00 → 7.22** (surface), 6.37 (elevated) | Not "white @ 50 %" (5.11 on surface, but it drifts per ground). Lifts supporting text to AA |
| `textInactive` | `#B2B2B2` | `#6E7682` | 2.12 → **3.61** | Read rows must still look *done*, but stay legible |
| `disabledInk` | (part of `disabled` today) | `#6E7682` | → 2.81 on `disabled` fill | Disabled is meant to be quiet; ≥ 2.5 keeps it legible |

### 4.3 Lines

| Role | Light | **Dark (PROPOSED)** | vs surface | Why |
|---|---|---|---|---|
| `divider` | `#EAEDF0` | `#2A303A` | 1.25 | As quiet as light's 1.18 |
| `border` | `#D6DBE1` / `#E4E6EF` | `#3A424E` | 1.63 | In light, the outline is a little stronger than the rule; kept |
| `borderFocused` | black @ 90 % | `#ECEFF3` | 14.4 | Light deliberately focuses in neutral, not blue; kept |

### 4.4 Brand

| Role | Light | **Dark (PROPOSED)** | Contrast | Why |
|---|---|---|---|---|
| `primary` | `#296CFF` | `#296CFF` (unchanged) | white on it: 4.48 (same as light) | Brand fill. The same pixels in both modes are the strongest "same product" signal |
| `accent` | `#2970FF` | `#2970FF` (unchanged) | fill vs surface 3.83 (≥ 3 for non-text) | Progress, selection and Teacher blocks stay on-brand |
| `accentText` | `#2970FF` | `#6E9BFF` | 4.32 → **6.14** (surface), 6.97 (page), 5.32 (on `accentSubtle`) | `#2970FF` text on `#1A1F27` is only 3.83. A lifted tint of the same hue reads as the same blue |
| `accentSubtle` | `#E5F4FF` | `#1A2A47` | `accentText` on it: 5.32 | A blue-tinted surface, not a light patch |
| `onPrimary` | `#FFFFFF` | `#FFFFFF` | — | Unchanged |
| `primaryDepth` | `#004FED` | `#1D4FC4` | — | The 3D edge must still be darker than the blue, and visible against `#1A1F27` |
| `neutralDepth` | `#E0E0E0` / black @ 4 % | `#0B0E12` | — | Under a dark pill, depth is darker than the page |

### 4.5 Status (ink / fill / outline)

| Status | Light ink / fill / outline | **Dark ink / fill / outline (PROPOSED)** | Ink on fill: light → dark |
|---|---|---|---|
| success | `#009951` / `#EBFFEE` / `#14AE5C` | `#45D18C` / `#0F2E20` / `#2E8F5E` | 3.54 → **7.51** |
| error | `#DC3412` / `#FFF5F5` / `#EF4444` | `#FF7A70` / `#341A1C` / `#C2453F` | 4.32 → **6.31** |
| warning | `#EBA611`·`#DD940E` / `#FFFAE5` / `#EBA611` | `#F5B547` / `#33280F` / `#A87A1E` | → **7.98** |
| info | `#0D99FF` / `#E5F4FF` / `#0D99FF` | `#5CB8FF` / `#132A42` / `#2A78B8` | → **6.79** |
| `error` as field text | `#E5484D` | `#FF7A70` | on surface 6.52 |

Same hue family in each case. Pale fills become deep tinted fills, and inks get lighter. Pure saturated hues on dark vibrate, so outlines drop to mid-tone.

### 4.6 Overlays and elevation

| Role | Light | **Dark (PROPOSED)** | Why |
|---|---|---|---|
| `barrier` | black @ 60 % | black @ 70 % | Over an already-dark page, the sheet needs a stronger dim to read as "on top" |
| `scrim` (scanner) | black @ 58 % | black @ 58 % (unchanged) | Over camera video, not over UI |
| `shadow` | black @ 5–8 % | transparent (no shadow) | Shadows vanish on dark. Depth comes from the surface step plus the existing `divider`/`border` hairline |
| `sheetHandle` | `#DBDBDC` | `#4A525E` | Visible on `surfaceElevated` without glare |

---

## 5. Typography and text treatment

- **No change to the type scale.** `AppTypography` sizes, weights, line heights and `Manrope` are identical in both modes.
- **Colour comes out of the styles.** 20 of 25 `AppTypography` styles and 42 private `const TextStyle`s bake a colour. When migrated, they keep geometry and take colour from `context.palette` at the call site (audit §6). This is mechanical and per component.
- **Map every ink to a role.** The opaque greys fold into `textPrimary`, `textTitle`, `textSecondary` and `textInactive` (§3). No screen keeps its own grey.
- **Weight on dark.** Light text on dark looks heavier. The proposal does **not** change weights, which would be a type change. Instead it uses off-white (`#ECEFF3`), not `#FFFFFF`, to soften it. Design may still choose a weight step for 12–13 pt captions (§16.6).
- **Selected text and cursor.** The light `textSelectionTheme` (blue @ 20 % selection, black cursor) becomes a `accentText` @ 30 % selection and an `#ECEFF3` cursor in `AppTheme.dark`.

---

## 6. Component treatment

| Component | Today (light) | Proposed dark treatment |
|---|---|---|
| `AppButton` filled | `#296CFF` + white; disabled `#C9CBDA` | Unchanged fill and label. Disabled → `disabled` `#2C323C` + `disabledInk` |
| `AppButton` outlined | white + `border` + `textPrimary` | `surface` + `border` + `textPrimary` |
| `HomePillButton` / `TeacherPillButton` | blue/white pill + depth edge | Blue pill unchanged + `primaryDepth`. White pill → `surface` + `neutralDepth` edge |
| `AppTextField` | white; `border`; focus black 90 %; error red; disabled `surfaceMuted` | `surface`; `border`; focus `borderFocused` `#ECEFF3`; error `#FF7A70`; disabled `surfaceMuted`. Placeholder `textSecondary` |
| Cards (`ProgramCard`, `CohortCard`, `CourseCard`, `HomeStatCard`, `PaymentCard`, Teacher class card, Gradebook cards) | white on grey, `border` outline, faint shadow | `surface` on `pageBackground`, `border` hairline, **no shadow** |
| `ProgramCard` / `CohortCard` decoration SVGs | `#3478FF`/`#94AAFF` shapes on white | Keep the shapes, drawn at ~35 % opacity on `surface`, so they read as texture, not glare. Needs design sign-off (§16.4) |
| Attendance card gradient | `#175FEF → #518BFF` + white | Unchanged: a saturated blue block with white text works on dark (as Teacher's band does) |
| `AppBottomNav` | white bar, `#EAEDF0` top rule, selected `#2970FF`, unselected `textSecondary` | `surface` bar, `divider` rule, selected `accentText` (icon + label), unselected `textSecondary` |
| `CourseLearningBackButton` | white disc, `#D6DBE1` ring, soft shadow | `surface` disc, `border` ring, no shadow; arrow `textPrimary` |
| `NotificationTile` | as migrated in #253 | Unread: `accent` glyph/dot, `textPrimary`/`textSecondary`. Read: `textInactive` |
| Notification Detail | `accentSubtle` disc, `pageBackground` body ground | Same roles: disc `#1A2A47`, body ground `#0F1217` on a `surface` page. The body block becomes **darker** than the page, which reads as an inset well; design may prefer `surfaceSubtle` (§16.7) |
| Profile parts (rows, captions, switch, MN/EN) | white rows; `#F4F5F7` caption bands; switch track `accent`/`#D6DBE1` | Rows `surface`; caption bands `pageBackground`; switch on = `accent`, off = `border` `#3A424E`, knob `#ECEFF3`; MN/EN segment ink `accentText` |
| Status pills (`HomeBadges`, cohort status) | pale fill + outline + ink | Status triplets from §4.5 |
| Sheets and dialogs (Manager contact, Teacher session, payment sheets, success dialog) | white, `#99000000` barrier, `#DBDBDC` handle | `surfaceElevated`, `barrier` 70 %, `sheetHandle` |
| `SnackBar`, spinners, `RefreshIndicator`, date picker | Material defaults from `ColorScheme` | `AppTheme.dark`'s `ColorScheme` (`brightness: dark`, `primary` = `accent`, `surface` = `surfaceElevated`), so stock widgets follow automatically |
| Quiz answer and feedback cards | `#EAEDF0` border; correct `#14AE5C`/`#009951`; wrong `#EF4444`/`#DC3412` | `border`; success and error triplets |
| Lesson rows and connectors | `#EAEDF0`, locked `#B5B5B5` | `divider`; locked `textInactive` |
| Exercise video header | `#080F35` | Unchanged: already dark. On `#0F1217` it needs the `divider` hairline below it to separate (§14) |

---

## 7. Icon and SVG strategy

| Class | Assets | Proposal |
|---|---|---|
| Monochrome, black | 17: Profile row icons, the bell, the exercise icons, the lock | Draw through `AppSvgIcon` (exists since Phase 3, Issue #258): `ColorFilter.mode(role, srcIn)` with role `iconInk` by default, applied **only when the role differs from the asset's own black**, because a same-colour tint moves edge pixels. In dark, `iconInk` takes the approved value (proposed: as `textPrimary`). **No asset changes** |
| Monochrome, brand blue | `nav_*_active` ×5, `certificate_badge` | Tint with `accentText` in dark (selected nav already uses a `colorFilter`) |
| Single-colour status and brand | `quiz_correct` `#009951`, `quiz_incorrect` `#EF4444`, `course_detail_completed_check` `#14AE5C`, `contract_warning` `#B86200` | Tint with the status ink (§4.5) in dark; keep as authored in light |
| Near-black glyph | `exercise_play` `#0B1230` (on the video header) | **Keep as authored, no tint.** It sits on the white `mediaControl` play disc, which stays white in every theme (Phase 6b, Issue #268), not on the dark video. *(Corrected in Phase 9: this row used to say "tint `#FFFFFF`", which would have drawn white on white.)* |
| Wordmark | `splash_wordmark.svg` `#14053D`, on Splash and the Home header | **Tint with `textTitle` in dark.** Single colour, so no new asset is needed. The brand navy on a near-black ground is 1.00:1, which is invisible |
| Track glyphs | `adult.svg` `#86C3FF`, `junior.svg` `#E16D31` | Keep as authored: both read on dark (role identity, §10–11) |
| Module art | `module_*` ×6 (bright accents) | Keep; they're illustration and already bright |
| Phosphor glyphs (`AppIcons`) | 33 `Icon(...)` with explicit colours | Colour from roles; nothing else |

---

## 8. Illustration and image treatment

| Asset | Proposal | Needs approval |
|---|---|---|
| Certificate images (`certificate.png`, `certificate_backround.png`) | **Keep light.** It is a document, and its look is what gets printed and shared. Frame it with a `border` hairline on dark | Yes (§16.3) |
| Bank logos (15 PNG) | Keep. Draw each on a small **white logo plate** (radius as today), because many are dark-on-transparent and vanish on dark | Yes |
| App mark PNG (Home header, Splash) | Keep: the blue gradient mark reads on dark | — |
| Junior map world (sky `#BFD9F8`, cloud/grass/coin SVGs, backdrop/islands/nodes PNG) | See §11. Recommended: keep the daytime art and dim the scenery layer only (black @ 25 %). Nodes and progress stay full strength | **Yes** |
| `how_ai_works.svg`, `junior_lesson_day/missed.svg` (greyscale-ish art) | Keep, on a `surfaceSubtle` plate, so their light greys don't float on near-black | Yes |
| Program/Cohort decoration | §6: keep at reduced opacity | Yes |
| User content (course banners from the network) | Unchanged: content is content | — |

**Rule:** never auto-invert artwork. Every illustration is kept, plated, dimmed or re-exported by decision, and recorded.

---

## 9. System UI treatment

> The mechanism exists since Phase 4 (Issue #260): `AppSystemUi.page` and `overDarkContent` (`lib/core/theme/app_system_ui.dart`). Dark Mode only needs `AppTheme.dark` to have `brightness: Brightness.dark`; the regions follow on their own.

- **Status bar.** Derived from the active theme, not per screen (audit §8, Phase 4).
  - Dark theme → light icons (`SystemUiOverlayStyle.light`) on transparent.
  - The two screens that already use `.light` (camera scanner, Teacher Schedule's blue band) stay `.light` in both modes.
- **Navigation bar (Android).** Matches the screen's bottom ground: `surface` where a bottom bar sits, otherwise the page ground. Light icons in dark.
- **Launch.**
  - **Android:** `values-night` already uses a black window today; it should become `#0F1217`, so the hand-off to a dark Splash is seamless.
  - **iOS:** `LaunchScreen.storyboard` is white. A dark launch needs a dark-appearance colour asset.

  Both are Phase 11 native work, outside the protected files.
- **Splash** draws on `pageBackground` in dark, with the tinted wordmark (§7).

---

## 10. Adult-specific considerations

- **Home.**
  - Program card on `surface` with dimmed decoration.
  - Attendance gradient card unchanged.
  - Payment and Attendance stat cards `surface`.
  - "Ирц бүртгүүлэх" muted pill → `surface` + `neutralDepth`.
- **Blue as text.** "08/04 • 09:00", "3 хоног дутуу" and "35% complete" links use `accentText`.
- **Payments and payment flow.**
  - Progress bar `accent` on `divider` track.
  - Installment states use the status triplets; the "next" outline `#155EEF` → `accentText`.
  - Bank logos on white plates (§8).
  - The ebarimt receipt is a document, so it stays light like the certificate (§16.3).
- **Course Learning.**
  - Lesson and module pages (`#F9FAFB` `_page`) → `surfaceSubtle`.
  - Module card art kept.
  - Quiz states from §4.5.
  - Exercise video header unchanged.
- **Certificate.** Page dark; certificate image light and framed. "Download" outlined pill → §6 outlined.
- **Profile.** Captions `pageBackground`; rows `surface`; the theme row → §15.

---

## 11. Junior-specific considerations

Junior has the strongest visual identity, so it is the highest-risk role.

- **The map world** is a bright daytime illustration (sky field, clouds, grass islands, coins, pixel-art nodes).
  - Inverting it would break the art.
  - Keeping it untouched makes a glaring bright panel in a dark app.
  - **Proposed:**
    - keep the art;
    - dim the scenery layer only (black @ 25 %);
    - set `juniorMapSky` to a dusk blue (`#2A4A73`, PROPOSED), so the field the art floats on is no longer the brightest thing on screen;
    - keep nodes, the progress ring and the current-lesson marker at full strength, so the path stays the focus.
  - A true night variant (moon, dark clouds) would need new art (§16.2).
- **Cards.** `juniorCard` `#EFF4FF` → `#1A2235`; `juniorCardBorder` `#D1D3F5` → `#2E3A5C` (PROPOSED). Still pale-blue-*tinted* surfaces, so Junior keeps its softer, bluer feel than Adult.
- **Calendar.**
  - `calendarNeutral` `#F2F2F3` → `#20252E`;
  - `calendarLesson` `#E5F4FF` → `#1A2A47` (= `accentSubtle`);
  - `calendarMissed` `#FFE7E7` → `#3A1F22`.

  Day numbers on all three: `textPrimary` (12.4–13.3:1).
- **Track glyph** `junior.svg` orange `#E16D31` is kept. It is Junior's mark (5.07:1 on `surface`).
- **Contract banner** (yellow) → the warning triplet.
- **Junior Profile** has no theme row today, so one is added in Phase 10 (§15).

---

## 12. Teacher-specific considerations

- **Schedule header band** (`HomePalette.accent`, white text, light status bar).
  - Keep it as Teacher's identity, deepened to `scheduleBand` `#1F4FC9` (PROPOSED).
  - White on it is **6.95:1** (vs 4.32 today), and a full-width `#2970FF` slab is the brightest thing on a dark screen.
  - The blue still reads as the same brand.
- **Week grid.**
  - Lines `divider`.
  - Session blocks keep `accent` + white.
  - Held sessions `scheduleHeld` `#1A2A47` with `scheduleHeldInk` `#A3ACB9`.
  - Weekday and caption inks → `textInactive`/`textSecondary`.
  - Bar track `#E5E7EB` → `divider`.
- **Session sheet.**
  - `surfaceElevated`, `sheetHandle`.
  - Teacher name and role inks (`#0C226E`, `#6371A2`) → `textPrimary` and `textSecondary`. Navy text would vanish on dark.
- **Gradebook.**
  - Cards per §6.
  - Gradebook `link` `#1501A6` (deep violet-blue, 1.25:1 on dark) → `accentText`.
  - Name ink `#808080` → `textSecondary`.
- **Teacher Home and Request.** Same card treatment as Adult; track glyphs as authored.
- **Teacher Profile** has no theme row today, so one is added to its "App settings" group in Phase 10 (§15).

---

## 13. Accessibility and contrast

**Measured pairs, light (shipped) → dark (proposed):**

| Pair | Light | Dark | Target |
|---|---|---|---|
| body text / surface | 17.58 | 14.35 | ≥ 7 |
| body text / elevated | — | 12.66 | ≥ 7 |
| supporting text / surface | **4.00** | 7.22 | ≥ 4.5 |
| supporting text / elevated | — | 6.37 | ≥ 4.5 |
| title / surface | 17.58 | 15.42 | ≥ 7 |
| inactive (read) / surface | 2.12 | 3.61 | ≥ 3 (faint by design) |
| blue text / surface | 4.32 | 6.14 | ≥ 4.5 |
| blue text / accentSubtle | — | 5.32 | ≥ 4.5 |
| white / primary button | 4.48 | 4.48 | 4.5 (see below) |
| white / Teacher band | 4.32 | 6.95 | ≥ 4.5 |
| success / error / warning / info ink on fill | 3.54 / 4.32 / — / — | 7.51 / 6.31 / 7.98 / 6.79 | ≥ 4.5 |
| divider / border vs surface | 1.18 / 1.39 | 1.25 / 1.63 | match light's quietness |
| surface step over page; elevated over surface | (shadow) | 1.13 / 1.13 | visible step |

- **White on the brand button is 4.48:1 in both modes.** That's a hair under AA for small text, and it isn't introduced by dark mode. Changing the brand blue is a brand decision, so it's flagged, not changed (§16.8).
- **Translucency.** No dark text role is translucent. Translucent text is the main reason a "just swap white and black" approach fails: today's `textSecondary` (black @ 50 %) on `#1A1F27` measures 1.16:1, and white @ 50 % drifts per ground.
- **Status is never colour-only.** It already pairs with text ("Active", "Finished", "Хоцорсон"); keep it that way.
- **Focus** stays a neutral high-contrast ring (14.4:1).

---

## 14. Screens and components that need special treatment

1. **Junior Home map:** illustration dimming, sky field, nodes on top (§11). Highest risk.
2. **Certificate, ebarimt receipt:** documents stay light and framed (§8).
3. **Payment method and bank sheets:** logo plates (§8).
4. **Splash and Home header:** wordmark tint (§7).
5. **Teacher Schedule:** deepened band, grid, held fills, light status bar kept (§12).
6. **Exercise Detail:** the dark video header on a dark page needs a hairline (§6). `exercise_play` keeps its authored colour, since it sits on the white `mediaControl` play disc (§7).
7. **Program and Cohort cards:** decoration opacity (§6).
8. **Attendance scanner:** already dark (camera + scrim). Verify only.
9. **Profile (×3):** the theme row and inert controls; segment ink `#1501A6` → `accentText`.
10. **Every `SvgPicture` without a `colorFilter`** (24 of 28 files): must be tinted before dark ships (audit §7).
11. **Notification Detail body well:** darker-than-page inset; design to confirm (§16.7).

---

## 15. Recommended implementation order

This fits the audit's phases (§15 there). **No step starts before §17 approval**, except those marked *no design needed*.

1. **Design review of this proposal** → approved values (or changes) written back here and marked **APPROVED**.
2. **Phase 2: token consolidation** *(no design needed; **done, Issue #256**)*. Add the *new* roles from §3 with light values equal to today's, and fold the duplicates. No visible change; goldens unchanged.
3. **Phases 3–8: migrate shared components, then Adult, Course Learning, Junior and Teacher** *(no design needed; shared components done in #258, Adult done in #262)*. Every screen reads roles; light goldens stay byte-identical.
4. **Phase 9: `AppPalette.dark` + `AppTheme.dark`** with the **approved** values, plus asset decisions (§8). Add dark goldens (`*_dark.png`) for every golden screen. The harness already takes a theme.
5. **Phase 4 completion: system UI by brightness.**
6. **Phase 10: controls and persistence.**
   - One global `AppThemeController`.
   - The Adult row becomes interactive.
   - A new Junior row in "App settings" and a new Teacher row in "App settings".
   - All three call the same `setMode`.
   - Restore from `flutter_secure_storage` in `main()` before `runApp`.

   No role-specific state. The control type (switch vs System/Light/Dark) is §16.1.
7. **Phase 11: device validation** (iOS and Android, both modes) and native launch screens.

**How the Profile controls fit the global model:** each role's row is a *view* of `AppThemeController.instance.mode` and a *caller* of `setMode`. None stores the mode. Changing it in Teacher Profile changes Adult and Junior too, because there is only one.

---

## 16. Open product and design decisions

1. **The control and the default.**
   - The control: a "Light mode" switch (today), a "Dark mode" switch, or a System / Light / Dark selector.
   - The default: follow the device, or light.
   - The *recommendation* is System / Light / Dark, defaulting to System. It's the platform norm, and the only option that fits all three roles with one label.
2. **Junior map:** dim the daytime art (proposed), commission a night variant, or keep it bright.
3. **Documents:** do the certificate and ebarimt receipt stay light (proposed)?
4. **Card decoration:** the Program/Cohort shapes at reduced opacity (proposed), or removed in dark?
5. **The violet-blue `#1501A6`** (segment and Gradebook link): fold into `accentText` (proposed), or keep a distinct violet role?
6. **Caption weight:** should 12–13 pt captions get a weight step on dark? (Not proposed by default.)
7. **Notification Detail body ground:** a darker inset (`pageBackground`, as specified), or `surfaceSubtle`?
8. **Brand blue contrast:** white on `#296CFF` is 4.48:1 in *both* modes. Accept, or darken the brand blue app-wide (a light-mode change too)?
9. **Teacher band:** the deepened `#1F4FC9` (proposed), or keep `#2970FF` exactly?
10. **Per-device or per-account preference** (audit §10; per-account would need a backend field).

---

## 17. What still requires human or design approval

Before any dark value enters code:
- [x] **Every dark value in §4, §11 and §12:** approve, or replace with Figma values, then mark **APPROVED** here. *Accepted for release as the candidate on 2026-10-09, at the product owner's request after reviewing it on a physical iPhone (Issue #282). The roles keep their PROPOSED / DERIVED / UNRESOLVED labels, and the items under "Open after enabling" (§18) remain open. This is not an accessibility sign-off.*
- [ ] **The new roles in §3:** names and scope.
- [ ] **Each asset decision in §8:** keep, plate, dim or re-export. This includes the Junior map (§11).
- [ ] **Component treatments in §6** that change shape language: no shadows, decoration opacity.
- [ ] **The decisions in §16.**
- [ ] **Ideally, Figma frames** for at least one screen per role (Adult Home, Junior Home, Teacher Schedule) plus Profile, so implementation is checked against a frame, not this text.

Since Issue #282 users can choose Dark with Adult Profile's "Light mode" switch. The candidate `AppTheme.dark` (Phase 9, Issue #276) is what they get, through the preference saved and restored since Phase 10 (Issue #278). `AppThemeController.darkThemeApproved` mirrors the first box above, and a test fails if the two disagree.

---

## 18. Phase 9 candidate: every role's dark value and status

`AppPalette.dark` (Issue #276), role by role. `app_palette_dark_test.dart` fails if the code and this table disagree, or if a role is missing.

- **PROPOSED:** the value in §4, §11 or §12.
- **DERIVED:** follows a rule this document states (a fold in §3/§5, "unchanged" in §6, "no shadow" in §4.6), or the role's own documented "same in every theme" (the video's media roles).
- **UNRESOLVED:** this document gives nothing; a stand-in, named, until design decides.

Counts: **48 PROPOSED, 35 DERIVED, 11 UNRESOLVED**, 94 roles in all. None is approved.

| Role | Dark (candidate) | Status | Source / stand-in |
|---|---|---|---|
| `pageBackground` | `#FF0F1217` | PROPOSED | §4.1 |
| `surfaceSubtle` | `#FF14181E` | PROPOSED | §4.1 |
| `surface` | `#FF1A1F27` | PROPOSED | §4.1 |
| `surfaceElevated` | `#FF232934` | PROPOSED | §4.1 |
| `surfaceMuted` | `#FF20252E` | PROPOSED | §4.1 |
| `surfaceTile` | `#FF14181E` | DERIVED | §3 lists icon tiles under surfaceSubtle |
| `textPrimary` | `#FFECEFF3` | PROPOSED | §4.2 |
| `textSecondary` | `#FFA3ACB9` | PROPOSED | §4.2 |
| `textTitle` | `#FFF5F7FA` | PROPOSED | §4.2 |
| `textStrong` | `#FFECEFF3` | DERIVED | §3 folds #1A1A1A into textPrimary |
| `textSupporting` | `#FFA3ACB9` | DERIVED | §3 folds #7D7D7E into textSecondary |
| `textMuted` | `#FFA3ACB9` | DERIVED | §3 folds #808080 into textSecondary |
| `textInactive` | `#FF6E7682` | PROPOSED | §4.2 |
| `textLocked` | `#FF6E7682` | DERIVED | §3: locked lesson ink is textInactive |
| `iconInk` | `#FFECEFF3` | DERIVED | §7: iconInk as textPrimary |
| `wordmark` | `#FFF5F7FA` | DERIVED | §7: tint the wordmark with textTitle |
| `border` | `#FF3A424E` | PROPOSED | §4.3 |
| `borderFocused` | `#FFECEFF3` | PROPOSED | §4.3 |
| `divider` | `#FF2A303A` | PROPOSED | §4.3 |
| `outline` | `#FF3A424E` | DERIVED | §4.3: border covers #D6DBE1 |
| `outlineSubtle` | `#FF2A303A` | DERIVED | §12: the bar track #E5E7EB → divider |
| `primary` | `#FF296CFF` | PROPOSED | §4.4 unchanged |
| `onPrimary` | `#FFFFFFFF` | PROPOSED | §4.4 unchanged |
| `primaryDepth` | `#FF1D4FC4` | PROPOSED | §4.4 |
| `accent` | `#FF2970FF` | PROPOSED | §4.4 unchanged |
| `accentText` | `#FF6E9BFF` | PROPOSED | §4.4 |
| `accentSubtle` | `#FF1A2A47` | PROPOSED | §4.4 |
| `accentSubtleOutline` | `#FF2A78B8` | UNRESOLVED | no value; the info outline of the same pale-blue family |
| `linkInk` | `#FF6E9BFF` | DERIVED | §3: #1501A6 → accentText (pending §16.5) |
| `disabled` | `#FF20252E` | UNRESOLVED | §4.2 gives only disabledInk; surfaceMuted ("set back") stands in |
| `disabledInk` | `#FF6E7682` | PROPOSED | §4.2 |
| `neutralDepth` | `#FF0B0E12` | PROPOSED | §4.4 |
| `subtleDepth` | `#FF0B0E12` | DERIVED | §3: neutralDepth folds secondaryDepth |
| `error` | `#FFFF7A70` | PROPOSED | §4.5 error as field text |
| `errorInk` | `#FFFF7A70` | PROPOSED | §4.5 |
| `errorFill` | `#FF341A1C` | PROPOSED | §4.5 |
| `errorOutline` | `#FFC2453F` | PROPOSED | §4.5 |
| `success` | `#FF45D18C` | DERIVED | §4.5 success ink |
| `successInk` | `#FF45D18C` | PROPOSED | §4.5 |
| `successFill` | `#FF0F2E20` | PROPOSED | §4.5 |
| `successOutline` | `#FF2E8F5E` | PROPOSED | §4.5 |
| `successLabel` | `#FF45D18C` | DERIVED | text: the §4.5 success ink, as #262 required |
| `successFillStrong` | `#FF0F2E20` | UNRESOLVED | no value; the §4.5 success fill stands in |
| `warning` | `#FFF5B547` | DERIVED | §4.5 warning ink (partial state, preview score) |
| `warningFill` | `#FF33280F` | PROPOSED | §4.5 |
| `warningOutline` | `#FFA87A1E` | PROPOSED | §4.5 |
| `warningInk` | `#FFF5B547` | PROPOSED | §4.5 (#DD940E is in its ink set) |
| `infoInk` | `#FF5CB8FF` | PROPOSED | §4.5 |
| `infoFill` | `#FF132A42` | PROPOSED | §4.5 |
| `barrier` | `#B3000000` | PROPOSED | §4.6 black @ 70 % |
| `sheetHandle` | `#FF4A525E` | PROPOSED | §4.6 |
| `shadow` | `#00000000` | PROPOSED | §4.6 no shadow |
| `shadowSubtle` | `#00000000` | DERIVED | §4.6: shadows vanish on dark |
| `accentOutline` | `#FF2970FF` | UNRESOLVED | no value; the unchanged accent blue stands in |
| `timelineConnector` | `#FF3A424E` | UNRESOLVED | no value; the border line stands in |
| `textFaint` | `#FF6E7682` | DERIVED | §5: greys fold into textInactive |
| `textDeep` | `#FFECEFF3` | DERIVED | §3 folds #101828 into textPrimary |
| `textStatLabel` | `#FFA3ACB9` | DERIVED | §3 folds statLabel into textSecondary |
| `attendanceGradientStart` | `#FF175FEF` | PROPOSED | §6 unchanged |
| `attendanceGradientEnd` | `#FF518BFF` | PROPOSED | §6 unchanged |
| `surfaceTinted` | `#FF1A1F27` | DERIVED | §6: cards → surface |
| `scrim` | `#94000000` | PROPOSED | §4.6 unchanged |
| `learningHeroTint` | `#FF1A2A47` | UNRESOLVED | no value; the blue-tinted accentSubtle stands in |
| `surfaceLocked` | `#FF20252E` | UNRESOLVED | no value; surfaceMuted ("set back") stands in |
| `cardDepth` | `#FF0B0E12` | DERIVED | §4.4: depth darker than the page |
| `outlineFaint` | `#FF2A303A` | UNRESOLVED | no value; the quieter divider line stands in |
| `videoSurface` | `#FF080F35` | PROPOSED | §6 video header unchanged |
| `mediaControl` | `#FFFFFFFF` | DERIVED | the role: same in every theme |
| `onMediaControl` | `#E6000000` | DERIVED | the role: same in every theme |
| `mediaControlOutline` | `#FFD6DBE1` | DERIVED | the role: same in every theme |
| `onMedia` | `#FFFFFFFF` | DERIVED | the role: same in every theme |
| `progressTrack` | `#FF2A303A` | DERIVED | §12: tracks → divider |
| `textAnswerLetter` | `#FFA3ACB9` | DERIVED | §5: greys fold into textSecondary |
| `juniorCard` | `#FF1A2235` | PROPOSED | §11 |
| `juniorCardBorder` | `#FF2E3A5C` | PROPOSED | §11 |
| `juniorMapSky` | `#FF2A4A73` | PROPOSED | §11 dusk sky |
| `calendarNeutral` | `#FF20252E` | PROPOSED | §11 #20252E |
| `calendarLesson` | `#FF1A2A47` | PROPOSED | §11 #1A2A47 |
| `calendarMissed` | `#FF3A1F22` | PROPOSED | §11 |
| `juniorMutedFill` | `#FF20252E` | UNRESOLVED | §11 "nodes at full strength" is open; surfaceMuted stands in (the light value left the certificate panel's text illegible) |
| `juniorHeaderRule` | `#FF2A303A` | DERIVED | a header rule; every other is divider |
| `onJuniorMapSky` | `#FFFFFFFF` | DERIVED | white reads on the dusk sky |
| `scheduleBand` | `#FF1F4FC9` | PROPOSED | §12 #1F4FC9 |
| `scheduleHeld` | `#FF1A2A47` | PROPOSED | §12 #1A2A47 |
| `scheduleHeldInk` | `#FFA3ACB9` | PROPOSED | §12 #A3ACB9 |
| `teacherTitle` | `#FFECEFF3` | DERIVED | §3 folds #0B1230 into textPrimary |
| `teacherNameInk` | `#FFECEFF3` | DERIVED | §12: name → textPrimary |
| `teacherRoleInk` | `#FFA3ACB9` | DERIVED | §12: role → textSecondary |
| `teacherDetailInk` | `#FFA3ACB9` | DERIVED | §12: Teacher greys → textSecondary |
| `teacherCaptionInk` | `#FFA3ACB9` | DERIVED | §12: caption ink → textSecondary |
| `teacherSheetRule` | `#FF2A303A` | DERIVED | a rule → divider |
| `dangerOutline` | `#FFC2453F` | DERIVED | §4.5 error outline |
| `avatarPlaceholder` | `#FF20252E` | UNRESOLVED | no value; surfaceMuted stands in |
| `avatarPlaceholderInk` | `#FF6E7682` | UNRESOLVED | no value; textInactive stands in |

### Measured contrast of the candidate (WCAG 2.x)

Measured from the values above. `app_palette_dark_test.dart` holds each figure to two decimals.

| Pair | Ratio |
|---|---|
| `textPrimary` on `surface` / `pageBackground` / `surfaceElevated` | 14.35 / 16.27 / 12.66 |
| `textTitle` on `surface` | 15.42 |
| `textSecondary` on `surface` / `surfaceElevated` | 7.22 / 6.37 |
| `accentText` on `surface` / `accentSubtle` | 6.14 / 5.32 |
| `errorInk`/`errorFill` · `error`/`surface` | 6.31 · 6.52 |
| `successInk`/`successFill` · `warningInk`/`warningFill` · `infoInk`/`infoFill` | 7.51 · 7.98 · 6.79 |
| `scheduleHeldInk`/`scheduleHeld` · `onPrimary`/`scheduleBand` | 6.25 · 6.95 |
| `textPrimary`/`juniorCard` · `onJuniorMapSky`/`juniorMapSky` · `onMedia`/`videoSurface` | 13.75 · 9.03 · 18.58 |
| **Below 4.5:1 for text:** `onPrimary` on `primary` / `accent` | **4.48 / 4.32**. The same as light; the brand blues are unchanged |
| **Below 4.5:1 for text:** `textInactive` on `surface` | **3.61**. Deliberately quiet (§4.2) |
| **Below 4.5:1 for text:** `disabledInk` on `disabled` | **3.35**. `disabled` is UNRESOLVED |
| `accent` (non-text) on `surface` | 3.83 (≥ 3:1 for non-text) |

**Field and button edges are below the 3:1 non-text guideline, and are not declared compliant.** `border` and `outline` (both `#3A424E` in the candidate) measure **1.63:1** on `surface`. They are more than hairlines: `border` is the resting edge of a field and an outlined button, and `outline` is the edge of Exercise Detail's fields. WCAG 1.4.11 asks 3:1 for a boundary needed to identify a control, so this is an **unresolved design and accessibility decision** (below).

Light mode has the same issue today: `border` `#E4E6EF` measures 1.25:1 on white and `outline` `#D6DBE1` 1.39:1. That is context, not an exemption.

`divider` (1.25:1 on `surface`, as light's 1.18) is a different case. It is a rule between rows, a decorative separator that identifies no control, and is judged separately from the edges above.

### Open after enabling (Issue #282)

- **Every value** (§17), including the Teacher band's deeper `#1F4FC9` (§12) and the dusk `juniorMapSky` (§11).
- **The 11 UNRESOLVED roles** above. Most were added in Phases 5–8, after this proposal was written.
- **Field and button edge contrast:** `border`/`outline` at 1.63:1 on `surface`, below the 3:1 non-text guideline for control boundaries (light: 1.25 / 1.39 on white). Design must choose a stronger edge for fields and outlined buttons, another way to identify them, or record a decision. Not compliant as proposed.
- **Junior map:** the scenery dim (black @ 25 %, §11) is not implemented. Whether nodes keep their light colours or take the candidate's is open. `juniorMutedFill` stands in as `surfaceMuted`'s value: its light value was tried and left the certificate panel's line illegible (light text on a near-white panel).
- **SVG tinting:** the monochrome icons that go through `AppSvgIcon` follow `iconInk`: Profile rows (Adult, Teacher and, since #282, Junior), the bell, and since #282 the course-material file and download glyphs. The wordmark follows `wordmark`. Multi-colour artwork and the coloured status glyphs draw as authored (§7). The faint lock on locked modules and lessons is legible but quiet; design to confirm.
- **Theme rows on Junior and Teacher Profile:** there are none, because there are no frames (PRODUCT DECISION). The preference is device-wide, so a Junior or Teacher who signs in after Dark was chosen sees Dark and can't switch it from their own Profile.
- **Plates and assets (§8):** bank logos, `how_ai_works.svg` and the certificate are not plated.
- **Shadows:** `shadow`/`shadowSubtle` are transparent, but widgets that apply their own strength (`withValues(alpha: …)`, Phases 3–8) still draw a black lift in dark. Design must say whether that should vanish.
- **The Mentor Feedback divider** still uses Material's default; in dark that is `AppTheme.dark`'s `outlineVariant`, not `divider` (Issue #268).
- **Native launch screens** (Phase 11): iOS `LaunchScreen.storyboard` is white, and Android's is white (or the system background on API 21+). They draw before Dart runs, so a saved Dark shows a brief native white before the first Flutter frame, which is already dark.
