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
| `/reset-password` | `ResetPasswordScreen` — the authenticated change-password form: from Profile's Change password, from Login's "Нууц үг сэргээх" only while a live session is held, and in place of Home when `must_change_password` (#182). Signed out, "Нууц үг сэргээх" and the "Менежертэй холбогдоорой" card open the contact sheet instead (`chooseManagerContact`, Issue #186): "Утасдах" opens `tel:+97675051055`, "Email бичих" `mailto:info@ai-academy.asia` — the business-confirmed contact (`ManagerContact`, Issue #184) — and dismissing the sheet (barrier, drag, back; it has no cancel button since #239) opens nothing |
| `/home` | `AdultStudentShell` on Нүүр (`HomeScreen`) — the adult tabs' persistent shell (Issue #237) |
| `/junior-home` | `JuniorStudentShell` on Нүүр (`JuniorHomeScreen`) — the junior tabs' persistent shell (Issue #241); `homeRouteFor` picks between the Homes by `user_type` |
| `/teacher-home` | `TeacherShell` on Хуваарь (Issue #370; Нүүр, `TeacherHomeScreen` of Issue #229, is no longer a tab) — the teacher tabs' persistent shell (Issue #241), where `user_type: "teacher"` lands. System back on another tab returns to Хуваарь |
| `/teacher-schedule` | `TeacherShell` on Хуваарь (`TeacherScheduleScreen`, Issue #231) |
| `/teacher-gradebook` | `TeacherShell` on Хөтөлбөрүүд (`TeacherGradebookScreen`, Issues #233, #390); the fourth tab, Профайл, is `TeacherProfileScreen` (Issue #243), reached from the bar only — it has no route of its own |
| `/my-cohorts` | `AdultStudentShell` on Хичээл (`CohortListScreen(enrolledOnly: true)`) |
| `/junior-progress` | `JuniorStudentShell` on Сурлагын явц (`JuniorProgressScreen`) |
| `/junior-profile` | `JuniorStudentShell` on Профайл (`JuniorProfileScreen`) |
| `/courses` | `CourseCatalogScreen` — draft catalog, no longer reached from Home |
| `/cohorts` | `CohortListScreen`, optional `int` course-id argument via `ModalRoute.settings.arguments` |
| `/profile` | `AdultStudentShell` on Профайл (`ProfileScreen`) |

**Everything deeper is pushed imperatively** with `Navigator.push(MaterialPageRoute(...))`: Course Detail, Course Module List, Lesson List (from an unlocked module card), Exercise Detail, and the two Quiz screens. There is no deep-linking and no route-argument type safety beyond the one `/cohorts` cast.

One navigation idiom worth knowing, in `course_learning`: `CourseQuizScreen` finishes by calling `pushReplacement` to `CourseQuizResultScreen`, passing the server's `QuizAttemptResult` as the **replaced route's** result. That completes the *original* `push` future immediately (not when the result screen later pops), which is invisible to the user because Exercise Detail is off-screen throughout. Exercise Detail then re-reads the lesson for its quiz summary (`refreshQuiz`) — it does so however the quiz screen ends, since closing part-way leaves an attempt open on the server. The result screen pops once to return there.

**Bottom navigation** (`AppBottomNav`) appears on each track's Home, progress and profile tab. **Adult** (Issue #237): the three tabs live in one `AdultStudentShell` (`home/presentation/adult_student_shell.dart`) — one `Scaffold` owns the one bar, and a tab switch is a `setState` over a lazily-built `IndexedStack`, so the bar never takes part in a page transition and each opened tab keeps its state (an opened tab is not re-fetched on return; pull-to-refresh still works). The tab screens are built with `showBottomNav: false`; system back on Хичээл/Профайл returns to Нүүр; detail screens are still pushed on the root navigator, over the whole shell. **Junior and Teacher** (Issue #241) work the same way on the shared `PersistentTabShell` (`shared/widgets/persistent_tab_shell.dart`): `JuniorStudentShell` (Нүүр / Сурлагын явц / Профайл) and `TeacherShell` (Хуваарь / Хөтөлбөрүүд / Профайл — `TeacherProfileScreen`, Issue #243; Профайл has no route and on a standalone bar stays inert). Their tab screens also take `showBottomNav: false`, their bars an `onSelect`, and session sheets, the request screen, Programs' student list → student detail and the Profile actions still push over the whole shell. (The Adult shell predates `PersistentTabShell` and is its own widget.) **Standalone screens** — the `/cohorts` list, or a tab screen pumped on its own — still draw their own bar and switch by route: `openStudentTab(context, track, tab)` (`auth/presentation/student_tabs.dart`) / `openTeacherTab` pop back to Home for Нүүр and otherwise replace whatever tab sits above Home with the tab's route — so that stack is never deeper than Home plus one tab. Each track draws the bar through one wrapper holding its item list: `AdultBottomNav` (the shared defaults unmodified; each tab a gray Phosphor outline, filled blue when active, the same on every screen, Issue #188) and `JuniorBottomNav` (the same defaults and outline/filled treatment, Issue #190).

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
    _baseUrl = baseUrl ?? ApiConfig.baseUrl;
```

The base URL is **one shared configuration**, `ApiConfig.baseUrl` (`lib/core/api/api_config.dart`, Issue #388): production, unless a **debug** build sets `--dart-define=AIA_API_BASE_URL=<origin>` for a local backend ([DATA_AND_API.md](DATA_AND_API.md) §3.1). Everything is injectable, so tests can pass a `MockClient` and a fake base URL.

## 5. Theme system

`core/theme/` holds four token files plus a deliberately thin `AppTheme`:

- **`AppColors`** — brand blues sampled from the logo, neutrals, semantic `error`/`success`/`warning`.
- **`AppTypography`** — Manrope, as a **semantic scale**: one style per role (`screenTitle`, `cardTitle`, `itemTitle`, `body`, `supporting`, `caption`, `dateTime`, `buttonLabel`, …), the same on every screen, with no baked colour (Issue #366). Its roles, exceptions and the legacy tokens left for unmigrated code are in [DESIGN_SYSTEM.md](../design-system/DESIGN_SYSTEM.md) §3.
- **`AppDimens`** — measurements read from the Figma Login frame (393 artboard, 16 gutter, 361 content, 44 button height, radii, border widths), plus later per-screen additions.
- **`AppIcons`** — Phosphor icon font codepoints. **Codepoints are confirmed against the bundled font's cmap, never guessed**; where no confirmed Phosphor glyph exists the code falls back to a Material `Icons.*` glyph with a comment saying why.
- **`AppTheme.light`** — only what the framework needs so it does not contradict the design: font family, the stock widgets' type (`bodyMedium` → `body`, `labelLarge` → `buttonSmall`), scaffold background, colour scheme, text selection. **The app does not style itself through Material component themes**; widgets paint from tokens directly.

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

No known pre-existing failures: the full suite passes on `main` (see [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §5).

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
| Firebase (Issue #398) | `com.google.gms.google-services` 4.5.0, declared in `settings.gradle.kts` and applied by `:app` **only when `android/app/google-services.json` exists** — none is committed, so push is off and the build is unchanged without it. `POST_NOTIFICATIONS` and the FCM services come from `firebase_messaging`'s own manifest. See [DATA_AND_API.md](DATA_AND_API.md) §1.2 |
| Notification defaults (Issue #425) | `AndroidManifest.xml` names Firebase's `default_notification_channel_id` (`aia_default`, "Мэдэгдэл", created by `MainActivity` on API 26+, importance default), `default_notification_icon` (`drawable/ic_stat_notification`, the in-app bell as a white vector) and `default_notification_color` (`#296CFF`, `AppColors.blue`). `test/core/platform/android_notification_config_test.dart` pins the wiring |

**No SDK level is pinned in this repository** — all four come from the Flutter tooling, so the effective numbers move with the Flutter version. To know the concrete values for a given checkout, resolve them from the installed Flutter SDK; do not assume.

**Release signing (Issue #425).** `android/app/build.gradle.kts` reads `android/key.properties`, which is git-ignored, as are `*.jks` and `*.keystore` (`android/.gitignore`). Its fields are `storeFile` (relative to `android/app`), `storePassword`, `keyAlias` and `keyPassword`.
- **With the file**, release builds are signed with that upload key. A missing field, or a `storeFile` that does not exist, stops the build. The error names the field, never a value.
- **Without it**, a local release APK (`flutter run --release`, `flutter build apk --release`) is still signed with the debug keys, so testing keeps working. Gradle warns that it is not for distribution; Flutter shows the warning with `-v`.
- **An App Bundle** (`flutter build appbundle`, the format Play takes) **refuses to build without the file.** Debug keys are never a production signature.

No real keystore exists in the repository or the workspace. Creating the upload key and enrolling in Play App Signing are owner tasks. (The `TODO:` left in `build.gradle.kts`, on `applicationId`, is the Flutter template's own and lives in Gradle config. It does not contradict the "no `TODO`/`FIXME`" rule, which is scoped to `lib/` and `test/`.)

### iOS — `ios/`

| Setting | Value |
|---|---|
| `CFBundleDisplayName` | `AI Academy Asia` |
| `CFBundleName` | `aia_mobile` |
| `CFBundleShortVersionString` / `CFBundleVersion` | `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` — driven by `pubspec.yaml`'s `version` |
| Orientations (iPhone) | Portrait, LandscapeLeft, LandscapeRight — **no** upside-down |
| Scene support | `UIApplicationSceneManifest` present; `UIApplicationSupportsMultipleScenes` declared |
| Entitlements | **None** — no `.entitlements` file exists. Push needs `aps-environment` (a `Runner.entitlements` wired in the protected `project.pbxproj`) — an approval-gated blocker, [DATA_AND_API.md](DATA_AND_API.md) §1.2 |
| Plugin integration | **Swift Package Manager.** The committed `Runner.xcodeproj` has linked `FlutterGeneratedPluginSwiftPackage` since the initial project setup. That is the package Flutter generates, under the git-ignored `ios/Flutter/ephemeral/Packages/`, for the plugins in `pubspec.yaml` (`url_launcher`, `file_selector`, `flutter_secure_storage` — its `flutter_secure_storage_darwin` ships a `Package.swift` — `pdfx` (Issue #310), which ships `darwin/pdfx/Package.swift`, iOS 13+, so it fits the 15.0 deployment target, and `mobile_scanner` (Issue #384), which ships `darwin/mobile_scanner/Package.swift`, iOS 12+, Apple Vision — its Android side is CameraX with ML Kit barcode scanning bundled, minSdk 23). **No `Podfile` exists or is used.** A plugin without Swift Package Manager support would be brought in through CocoaPods instead, which generates a `Podfile` and edits `project.pbxproj`, a protected file ([DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §3). Check a new plugin's support first |
| Custom permission keys | `NSCameraUsageDescription` only (Issue #384) — the attendance scanner's camera. No photo or location keys. Android's `CAMERA` permission comes from `mobile_scanner`'s own manifest |

That last row matters: Junior Home's check-in node and Adult Home's "Ирц бүртгүүлэх" (Issue #386) open `AttendanceScannerScreen`, which scans with the camera through `mobile_scanner` and checks in with `POST /me/attendance/check-in` (Issue #384; [DATA_AND_API.md](DATA_AND_API.md) §1.1). The camera sits behind a swappable `QrScanViewBuilder` (`mobileScannerQrView` in the app, a fake in tests), so no test needs a camera; the iOS simulator has none, and shows the scanner's "unsupported" state.

### iOS deployment target

`IPHONEOS_DEPLOYMENT_TARGET` is **15.0**, committed and local alike. Until Issue #419 the committed value was 13.0 and only the local working tree had 15.0. `firebase_core` and `firebase_messaging` (Issue #398) require iOS **15.0** (their `Package.swift`). With 13.0 committed, every `flutter build ios` / `flutter run` from a clean checkout rewrote the three lines itself ("Updating minimum iOS deployment target to 15.0"), leaving the protected file modified (verified on `main` @ `29982f5`; the build itself succeeded, and so did a plain `xcodebuild`). Issue #419 committed only those three lines. The rest of the local modification to `ios/Runner.xcodeproj/project.pbxproj` stays local and protected ([DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §3). Resolving the Firebase Swift packages also leaves `Package.resolved` files under `ios/Runner.xcworkspace/xcshareddata/swiftpm/` and `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`; none is committed yet (a decision to take with the iOS change).

### Launcher icons

Generated by the `flutter_launcher_icons` dev dependency from `assets/icon/` (config block in `pubspec.yaml`: `app_icon_ios.png`, `app_icon_foreground.png`, white adaptive background, `remove_alpha_ios: true`). Regenerate with `dart run flutter_launcher_icons`; the generated platform icon files are build output of that command, not hand-edited.
