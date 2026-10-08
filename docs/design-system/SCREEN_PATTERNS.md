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

1. **`AnnotatedRegion`** sets the status-bar style per screen (`dark` on light pages, Exercise Detail included: its video header starts below the status bar, see §3).
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
| Home | `/home` (in `AdultStudentShell`) | bottom nav — the shell's, persistent | composed (real) |
| Teacher Home | `/teacher-home` (in `TeacherShell`) | teacher bottom nav — the shell's, persistent (four tabs; 10pt labels per its reference) | `teacher` — `GET /teachers/{actor_id}/schedule` (real) |
| Teacher Schedule | `/teacher-schedule` (in `TeacherShell`) | blue date header + week strip; the shell's teacher bottom nav, Хуваарь selected | `teacher` — schedule + `GET /teacher/cohorts/{id}/sessions`, sheets read `GET /teacher/sessions/{id}/attendance` (real) |
| Teacher Gradebook | `/teacher-gradebook` (in `TeacherShell`; student list, student detail, submission detail pushed on top, no bottom nav) | white title band + rule; the shell's teacher bottom nav, Дүнгийн хуудас selected | `teacher` — schedule, class assignments and their submissions, `GET /teacher/submissions/{id}` (real) |
| Cohort List | `/my-cohorts` (in `AdultStudentShell`), `/cohorts` | bottom nav — the shell's on `/my-cohorts`, its own on `/cohorts` | `cohorts` + `enrollments` (real) |
| Profile | `/profile` (in `AdultStudentShell`) | bottom nav — the shell's, persistent | `auth` current user (real) |
| Certificate | pushed from the Certificate row of the Adult and Junior Profiles (`CertificateScreen.open`) | `CourseLearningBackButton` (arrow) with the title centred on its row; no bottom nav | `certificates` — enrolled cohorts + §2.9 certificate per course + download (real) |
| Notification | pushed from any bell (`NotificationScreen.open`) | `CourseLearningBackButton` (arrow) with "Notification" centred; no bottom nav; 72pt rows with full-width rules | `notifications` — `GET /me/notifications`, mark read (real) |
| Notification Detail | pushed by any Notification row tap (`NotificationDetailScreen.open`) | no frame (Issue #248, product decision): the Notification header (`NotificationHeader`); a scrolling page — 32pt accent bell, title 20/28 w700, sent time `2026.10.01 12:57` 14/20 `textSecondary`, a `HomePalette.headerRule` rule, the body 16/24 `textPrimary`, untruncated | the tapped `AppNotification`, as already loaded — no request of its own |
| Teacher Profile | Профайл tab of `TeacherShell` (no route; Change password pushed on top) | white title band + rule; the shell's teacher bottom nav, Профайл selected | `auth` current user (real); log out and change password real; MN/EN, Notification, contact rows inert |
| Course Catalog | `/courses` | — | `courses` (real) |
| Course Detail | pushed | — | `courses` (real) |
| Course Module List | pushed | back button | `course_learning` — `GET /me/courses/{slug}/learning` (real) |
| Lesson List | pushed from an unlocked module card or a completed Junior node | back button in the hero | `course_learning` — `GET /me/modules/{id}/lessons` (real) |
| Exercise Detail | pushed | in-video back | `course_learning` — `GET /me/lessons/{id}` (real) |
| Quiz / Quiz Result | pushed | close button / none | `course_learning` — §2.7 quiz attempt endpoints (real) |

## 3. Documented exceptions

Each of these breaks the default skeleton on purpose. The reasoning is recorded in the code; do not "normalise" them without a Figma frame saying otherwise.

**Exercise Detail — `SafeArea(bottom: false)` and a full-width video header.** The body is inset at the top only, so the video header starts below the status bar, which stays on the page's light background with `dark` glyphs. `bottom: false` lets the scroll run to the screen's bottom edge. Within the content column the header is full-width, with no `screenPadding` gutter. `ExerciseVideoHeader` still adds `MediaQuery.paddingOf(context).top` to its back button and badge ([COMPONENT_PATTERNS.md](COMPONENT_PATTERNS.md) §5); under this `SafeArea` that inset has already been removed, so it adds 0 here.

**Lesson List — the module hero runs under the status bar, so no `SafeArea`.** Drawn to the Figma level-detail reference (Issue #215). A hero of `topInset + 200` in the module's accent (the same tile tint and `moduleVisualsFor(order)` artwork as that module's Course Detail card) starts at the top of the screen. `CourseLearningBackButton` sits at the inset, and the artwork is centred in the 200 below it. The caption, title and cards follow in one scroll, with the bottom inset as padding. The loading, empty and error states sit under the same header. The reference's progress row and "Continue learning" are left off: Course Detail already shows them.

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
