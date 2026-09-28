# Screen Patterns

> How screens are assembled, and which screens deliberately deviate.
>
> **Figma remains the visual authority.** This records the structural conventions the code follows so a new screen is consistent by default — and flags the documented exceptions so they are not mistaken for mistakes, or copied blindly.

## 1. The default screen skeleton

```dart
AnnotatedRegion<SystemUiOverlayStyle>(          // status-bar style per screen
  value: SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: AppColors.background),
  child: Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: ListenableBuilder(                  // the screen's controller
        listenable: _controller,
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(                 // caps the column on tablets
            constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
            child: /* scroll body, padded by AppDimens.screenPadding */,
          ),
        ),
      ),
    ),
  ),
)
```

Five conventions in that skeleton, all worth keeping:

1. **`AnnotatedRegion`** sets the status-bar style per screen (`dark` on light pages, `light` over the dark video header).
2. **`Scaffold.backgroundColor = AppColors.background`** — the page is grey; white is for surfaces.
3. **`SafeArea`** wraps the body — **except** where a deliberate full-bleed is wanted (see §3).
4. **`ConstrainedBox(maxWidth: 480)` + `Align(topCenter)`** — the column stops and centres instead of stretching on wide screens.
5. **A single `ListenableBuilder`** around the body; the controller is created in `initState`, disposed in `dispose`.

Body layout: `SingleChildScrollView` with `EdgeInsets` built from `AppDimens.screenPadding` (16), giving the 361 content width.

## 2. Screen inventory

| Screen | Route | Chrome | Data |
|---|---|---|---|
| Splash | `/` | none | none — 7000 ms, then `pushReplacement` to `/login` |
| Login | `/login` | none | `auth` (real) |
| Reset Password | `/reset-password` | none | `auth` (real) |
| Home | `/home` | bottom nav | composed (real) |
| Cohort List | `/my-cohorts`, `/cohorts` | bottom nav | `cohorts` + `enrollments` (real) |
| Profile | `/profile` | bottom nav | `auth` current user (real) |
| Course Catalog | `/courses` | — | `courses` (real) |
| Course Detail | pushed | — | `courses` (real) |
| Course Module List | pushed | back button | **sample** |
| Lesson List | not navigated to | back button | **sample** |
| Exercise Detail | pushed, + dev route | in-video back | **sample** |
| Quiz / Quiz Result | pushed | close button / none | **sample** |

## 3. Documented exceptions

Each of these breaks the default skeleton on purpose. The reasoning is recorded in the code; do not "normalise" them without a Figma frame saying otherwise.

**Exercise Detail — no `SafeArea` around the body.** The video header runs genuinely full-bleed under the status bar. The back button and badge are instead offset by `MediaQuery.paddingOf(context).top` individually. This is not an oversight — see [COMPONENT_PATTERNS.md](COMPONENT_PATTERNS.md) §5 for the iOS touch-interception bug that makes the offset mandatory.

**Course Module List — page-level tint, not a card.** The soft blue wash at the top is a `LinearGradient` painted behind the whole `SafeArea` (`#0D296CFF` → `background`, stops `0.0`/`0.22`), *not* a decoration on the hero. An earlier pass put it on a rounded box behind the hero and it read as a floating card.

**Course Module List — the certification panel.** The Figma section bleeds edge-to-edge across the 393 width; inside the app's shared padded, `maxContentWidth`-capped scroll body that would need a differently-padded scroll region for one block. It is drawn at the normal 361 content width with its own padding standing in for the bleed.

**Quiz screens — full-screen, own `Scaffold`, no bottom nav.** A fixed bottom action area sits outside the scroll body:

```dart
Column(children: [
  QuizProgressHeader(...),                    // fixed, 64 tall
  Expanded(child: SingleChildScrollView(...)),// questions / results
  Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Center(child: ExerciseSubmitButton(...))),  // fixed action
])
```

Reuse that three-part shape for any future full-screen flow with a persistent bottom action.

**Exercise Detail — the unified tab card.** Tabs and tab content live inside **one** bordered container (`clipBehavior: Clip.antiAlias`, radius 16), not a header plus a separate floating card. Mentor Feedback sits *inside* the Assignment tab's content, below a divider. The Quiz preview is a **separate card below that container**, with a 16pt gap — it is not a tab.

**Profile / Settings rows** — `settingsRowHeight` 40 minimum with a 20pt leading SVG, so rows with and without a trailing control stay the same height.

## 4. Scroll, keyboard and overflow

- Long pages use `SingleChildScrollView`; lists build children with a `for` loop inside a `Column` rather than `ListView.builder` (these lists are short and fixed).
- Separators between rows are drawn explicitly (a `SizedBox` gap, or a connector rule on Module List) rather than via `ListView.separated`.
- **Tab rows scroll horizontally** so a longer label or a large accessibility text scale cannot overflow.
- Fixed-width inner blocks (the 329 form/action width) live inside a 16pt-padded 361 column — check both when a layout overflows by a few pixels.

## 5. Testing a screen

Match the existing harness (see [../ai/ARCHITECTURE.md](../ai/ARCHITECTURE.md) §7): real fonts via `FontLoader`, `Size(393, 852)` at `devicePixelRatio: 3` with `addTearDown(tester.view.reset)`, an injected fake repository, and — for any screen with a back button — pushed onto a real navigation stack rather than pumped bare.

Two traps that have actually bitten this codebase:

- **Off-screen taps.** `tester.tap` on something below the fold throws "derived an Offset that would not hit test". Fix with `await tester.ensureVisible(finder)` first — not `warnIfMissed: false`, which silences a different warning.
- **Pending timers.** Any `Future.delayed`/`Timer` a tap starts must be advanced explicitly (`await tester.pump(duration)`) before the test ends, or teardown fails on a pending timer.
