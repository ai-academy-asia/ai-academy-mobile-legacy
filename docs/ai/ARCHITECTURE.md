# Architecture

> Describes the **current** structure of `lib/` and `test/`. Verified by inspection, not inferred.

## 1. Layering

```
lib/
  main.dart                  runApp(AiAcademyApp)
  app.dart                   MaterialApp + named route table + AppTheme.light
  core/
    api/       api_client.dart (getJson/getRaw/postWithoutBody), api_failure.dart
    models/    localized_text.dart      — {en, mn} bilingual wire shape
    theme/     app_colors, app_typography, app_dimens, app_icons, app_theme
    utils/     describe_json.dart       — renders JSON whose shape is unconfirmed
  shared/widgets/            app_button.dart, app_text_field.dart, app_bottom_nav.dart
  features/<feature>/
    data/          HTTP repository implementations (or the sample one)
    domain/        models, repository interfaces, failure types
    presentation/  screens, controllers, <feature>_strings.dart
      widgets/     widgets private to that feature
```

**Dependency direction:** `presentation → domain ← data`. A screen depends on a repository *interface* from `domain/`, never on an HTTP class from `data/`. The concrete repository is constructed at the screen's edge and injected, which is also what makes widget tests possible.

**Cross-feature imports are allowed and do happen** — `home/data/enrolled_home_dashboard_repository.dart` imports repositories from `auth`, `cohorts`, `courses` and `enrollments` to compose the dashboard, and `profile` reuses `auth`'s `CurrentUserRepository` rather than defining its own. This is deliberate: it avoids inventing a second contract for data that already has one.

## 2. State management

**`ChangeNotifier` + `ListenableBuilder`. No package.** All 12 controllers follow one shape:

```dart
class XController extends ChangeNotifier {
  XController({required this._repository, /* fixed params */});

  bool _disposed = false;     // guards notifyListeners() after dispose
  bool _loading = false;
  bool _hasLoadedOnce = false; // distinguishes "first load" from "reload"
  X? _data;
  String? _errorMessage;      // user-facing copy, or null

  Future<void> load() async { /* set loading, await repo, map failure, notify */ }
  void _notify() { if (_disposed) return; notifyListeners(); }
  @override void dispose() { _disposed = true; super.dispose(); }
}
```

Conventions that hold across the codebase:

- The controller is created in `initState()` and disposed in `dispose()`; its constructor parameters (a slug, a module id) are **fixed for its lifetime**.
- Screens render via a single `ListenableBuilder` around the body.
- **Failures become `String? errorMessage` in the controller**, not exceptions thrown at the widget layer. Mapping from a typed failure to display copy happens in the controller, using that feature's `*_strings.dart`.
- `course_learning`'s remaining two controllers (`LessonListController`, `CourseExerciseDetailController`) have **no `errorMessage`** — there is no fallible source behind either one yet. Adding a real repository there means adding an error state too, which is exactly what `CourseLearningController` gained when `GET /me/courses/{course_slug}/learning` was wired up behind it.

## 3. Navigation

**Named routes in `lib/app.dart`, no routing package.** `initialRoute: '/'`.

| Route | Screen |
|---|---|
| `/` | `SplashScreen` — animates, then `pushReplacement` to `/login` after 7s |
| `/login` | `LoginScreen` — on success, `openSignedIn` opens the `homeRouteFor` Home, or first "Нууц үгээ тохируулах" when `must_change_password` (Issue #182) |
| `/reset-password` | `ResetPasswordScreen` — the authenticated change-password form: from Profile's Change password, from Login's "Нууц үг сэргээх" only while a live session is held, and in place of Home when `must_change_password` (#182). Signed out, "Нууц үг сэргээх" and the "Менежертэй холбогдоорой" card open the contact sheet instead (`chooseManagerContact`, Issue #186): "Утасдах" opens `tel:+97675051055`, "Email бичих" `mailto:info@ai-academy.asia` — the business-confirmed contact (`ManagerContact`, Issue #184) — and "Цуцлах" opens nothing |
| `/home` | `HomeScreen` (adult Нүүр tab) |
| `/junior-home` | `JuniorHomeScreen` (junior Нүүр tab) — `homeRouteFor` picks between the two |
| `/my-cohorts` | `CohortListScreen(enrolledOnly: true)` (adult Хичээл tab) |
| `/junior-progress` | `JuniorProgressScreen` (junior Сурлагын явц tab) |
| `/junior-profile` | `JuniorProfileScreen` (junior Профайл tab) |
| `/courses` | `CourseCatalogScreen` — draft catalog, no longer reached from Home |
| `/cohorts` | `CohortListScreen`, optional `int` course-id argument via `ModalRoute.settings.arguments` |
| `/profile` | `ProfileScreen` (adult Профайл tab) |

**Everything deeper is pushed imperatively** with `Navigator.push(MaterialPageRoute(...))`: Course Detail, Course Module List, Lesson List (from an unlocked module card), Exercise Detail, and the two Quiz screens. There is no deep-linking and no route-argument type safety beyond the one `/cohorts` cast.

One navigation idiom worth knowing, in `course_learning`: `CourseQuizScreen` finishes by calling `pushReplacement` to `CourseQuizResultScreen`, passing the server's `QuizAttemptResult` as the **replaced route's** result. That completes the *original* `push` future immediately (not when the result screen later pops), which is invisible to the user because Exercise Detail is off-screen throughout. Exercise Detail then re-reads the lesson for its quiz summary (`refreshQuiz`) — it does so however the quiz screen ends, since closing part-way leaves an attempt open on the server. The result screen pops once to return there.

**Bottom navigation** (`AppBottomNav`) appears on the six tab screens — each track's Home, progress and profile screen. The two tracks share the bar's *behaviour* but never its screens: every tab switch goes through `openStudentTab(context, track, tab)` (`auth/presentation/student_tabs.dart`), which pops back to Home for Нүүр and otherwise replaces whatever tab sits above Home with the track's own route (`StudentTabRoutes.of`) — so the stack is never deeper than Home plus one tab. The junior screens draw the bar through `JuniorBottomNav`, which carries the junior frames' smaller (10pt) labels; the 16pt gutter and `#2970FF` selection are the shared bar's defaults, which the adult screens use unmodified (Issue #188).

## 4. Repository pattern

`domain/` declares an `abstract interface class`; `data/` implements it over HTTP; `test/` supplies a `fake_*` implementation.

```dart
abstract interface class CourseRepository {
  Future<List<Course>> getCourses();
  Future<Course> getCourseDetail(String slug);
}
```

Every HTTP repository follows the same constructor shape:

```dart
HttpXRepository({http.Client? client, Uri? baseUrl, Duration? timeout, AuthSessionStore? sessionStore})
  : _client = client ?? http.Client(),
    _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl);

static const String defaultBaseUrl = 'https://api.ai-academy.asia';
```

`defaultBaseUrl` is **repeated as a constant in each HTTP repository** rather than centralised. Everything is injectable so tests can pass a `MockClient` and a fake base URL.

## 5. Theme system

`core/theme/` holds four token files plus a deliberately thin `AppTheme`:

- **`AppColors`** — brand blues sampled from the logo, neutrals, semantic `error`/`success`/`warning`.
- **`AppTypography`** — Manrope. Its own doc comment records that the scale was taken **~15% below the measured Figma values** by eye, while keeping line heights at the layout's values. That is a deliberate, documented decision; changing it is a design decision, not a bug fix.
- **`AppDimens`** — measurements read from the Figma Login frame (393 artboard, 16 gutter, 361 content, 44 button height, radii, border widths), plus later per-screen additions.
- **`AppIcons`** — Phosphor icon font codepoints. **Codepoints are confirmed against the bundled font's cmap, never guessed**; where no confirmed Phosphor glyph exists the code falls back to a Material `Icons.*` glyph with a comment saying why.
- **`AppTheme.light`** — only what the framework needs so it does not contradict the design: font family, scaffold background, colour scheme, text selection. **The app does not style itself through Material component themes**; widgets paint from tokens directly.

See [../design-system/DESIGN_SYSTEM.md](../design-system/DESIGN_SYSTEM.md) for the token values and the rules about screen-local tokens.

## 6. Strings

Each feature owns a `presentation/<feature>_strings.dart` — an `abstract final class` of `static const String` (and small `static String fn(...)` formatters). Copy is taken **verbatim from the design**, which is why Mongolian and English are mixed. There is no i18n framework; do not add one without a task that asks for it.

## 7. Testing

`test/` mirrors `lib/features/`. **46 Dart files: 37 `*_test.dart` suites plus 9 `fake_*` test doubles** (the doubles are shared helpers, not suites — one per feature that needs a repository stub).

The 37 suites come in three kinds:

1. **Controller tests** — drive a controller against a `fake_*` repository, assert on loading/data/error transitions.
2. **Repository tests** — drive the HTTP repository against `MockClient`, assert URL, headers, parsing and failure mapping.
3. **Widget/screen tests** — pump the screen with an injected fake repository.

The 9 doubles are `fake_auth_repository`, `fake_password_repository`, `fake_current_user_repository`, `fake_cohort_repository`, `fake_course_repository`, `fake_course_learning_repository`, `fake_enrollment_repository`, `fake_enrolled_cohorts_repository` and `fake_home_dashboard_repository`. **Reuse the existing double** for a feature rather than writing a second stub for the same interface.

Widget-test conventions that recur and should be followed:

- **Real fonts are loaded** via `FontLoader` in `setUpAll` (Manrope + Phosphor) so text metrics are real.
- **Viewport is set explicitly**, typically `Size(393, 852)` at `devicePixelRatio: 3`, with `addTearDown(tester.view.reset)`.
- Screens that need a back button are **pushed onto a real navigation stack** from a harness widget, not pumped bare.
- A test that triggers a `Future.delayed` or `Timer` must **advance time explicitly** (`await tester.pump(duration)`) before finishing, or teardown reports a pending timer.
- `tester.ensureVisible(finder)` before tapping anything that may sit below the fold.

Known pre-existing failure, unrelated to new work: `test/features/courses/course_catalog_screen_test.dart` → *"loaded falls back to a computed duration when duration_label is null"*.

## 8. Assets

```
assets/fonts/    Manrope (5 weights) + Phosphor.ttf (+ PHOSPHOR-LICENSE.txt)
assets/icons/    single-purpose SVGs (adult, junior, certificate, profile rows, junior calendar marks, …)
assets/images/   brand + certificate PNGs
assets/images/course_learning/   feature-specific SVGs (module icons, exercise chrome)
assets/icon/     launcher-icon sources for flutter_launcher_icons (build-time only)
```

Declared in `pubspec.yaml` as directory entries (`assets/images/`, `assets/images/course_learning/`, `assets/icons/`) — a new file in one of those directories needs no pubspec change; a **new directory does**.

## 9. Platform configuration

Everything below was read from the repository. Where a value is inherited rather than pinned here, that is stated — **do not quote an inherited value as if this repo set it.**

### Android — `android/app/build.gradle.kts`

| Setting | Value |
|---|---|
| `namespace` / `applicationId` | `com.aiacademyasia.aia_mobile` (both, identical) |
| `compileSdk` | `flutter.compileSdkVersion` — **inherited** from the Flutter Gradle plugin |
| `minSdk` | `flutter.minSdkVersion` — **inherited** |
| `targetSdk` | `flutter.targetSdkVersion` — **inherited** |
| `ndkVersion` | `flutter.ndkVersion` — **inherited** |
| `versionCode` / `versionName` | `flutter.versionCode` / `flutter.versionName` — **inherited**, ultimately from `pubspec.yaml`'s `version: 1.0.0+1` |
| Java / Kotlin | `sourceCompatibility` and `targetCompatibility` `VERSION_17`; Kotlin `jvmTarget` `JVM_17` |
| App label | `android:label="AI Academy Asia"` in `AndroidManifest.xml` |

**No SDK level is pinned in this repository** — all four come from the Flutter tooling, so the effective numbers move with the Flutter version. To know the concrete values for a given checkout, resolve them from the installed Flutter SDK; do not assume.

**Release signing is not configured.** The release build type still carries the Flutter template's arrangement:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

That is the scaffold default, left in place. **Release builds are signed with debug keys**, which is fine for `flutter run --release` and **not** shippable. Treat configuring real release signing as its own task. (These two `TODO:` markers are the Flutter template's own and live in Gradle config — they are not a contradiction of the "no `TODO`/`FIXME`" rule, which is scoped to `lib/` and `test/`.)

### iOS — `ios/`

| Setting | Value |
|---|---|
| `CFBundleDisplayName` | `AI Academy Asia` |
| `CFBundleName` | `aia_mobile` |
| `CFBundleShortVersionString` / `CFBundleVersion` | `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` — driven by `pubspec.yaml`'s `version` |
| Orientations (iPhone) | Portrait, LandscapeLeft, LandscapeRight — **no** upside-down |
| Scene support | `UIApplicationSceneManifest` present; `UIApplicationSupportsMultipleScenes` declared |
| Entitlements | **None** — no `.entitlements` file exists |
| CocoaPods | **No `Podfile` committed yet.** Until `url_launcher` (lesson material download) the dependency set was plugin-free; it is the first plugin, so the next iOS build generates a `Podfile` and wires Pods into `Runner.xcodeproj` |
| Custom permission keys | **None** in `Info.plist` — no camera/photo/location usage descriptions |

That last row matters: `home/widgets/program_card.dart` renders an `Icons.qr_code_scanner` affordance, but **there is no camera permission declared and no scanning implemented** — the icon is UI only.

### iOS deployment target — committed vs. local

This one is easy to misread, so it is spelled out:

| | `IPHONEOS_DEPLOYMENT_TARGET` |
|---|---|
| Committed in `HEAD` | **13.0** |
| Local working tree | **15.0** |

The 15.0 value is part of the persistent local modification to `ios/Runner.xcodeproj/project.pbxproj`. **It is a protected local change — never revert it** ([DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §3). When reasoning about the deployment target, state which of the two you mean.

### Launcher icons

Generated by the `flutter_launcher_icons` dev dependency from `assets/icon/` (config block in `pubspec.yaml`: `app_icon_ios.png`, `app_icon_foreground.png`, white adaptive background, `remove_alpha_ios: true`). Regenerate with `dart run flutter_launcher_icons`; the generated platform icon files are build output of that command, not hand-edited.
