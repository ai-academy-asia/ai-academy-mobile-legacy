import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Push notifications (Issue #398). The Firebase project's own
// google-services.json, placed in this directory, initialises the default
// Firebase app natively — what FCM needs when a push starts the process.
// Without the file the plugin is not applied, the build is unchanged, and
// push stays off at runtime.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing (Issue #425). android/key.properties (git-ignored, as are
// *.jks and *.keystore) names the upload keystore:
//   storeFile=<path, relative to android/app>
//   storePassword=…   keyAlias=…   keyPassword=…
// With it, release builds are signed with that key; a file missing a field, or
// naming a keystore that does not exist, stops the build. Without it, a local
// release APK (`flutter run --release`, `flutter build apk --release`) is still
// signed with the debug keys, with a warning, so testing keeps working — but an
// App Bundle, the format Play takes, refuses to build: debug keys are never a
// production signature.
val releaseSigningFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigning: Properties? =
    rootProject.file("key.properties").takeIf { it.exists() }?.let { source ->
        Properties().apply { FileInputStream(source).use { load(it) } }
    }
releaseSigning?.let { props ->
    val missing = releaseSigningFields.filter { props.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException("android/key.properties is missing: ${missing.joinToString()}")
    }
    if (!file(props.getProperty("storeFile")).isFile) {
        throw GradleException("android/key.properties: storeFile does not exist (relative to android/app)")
    }
}

gradle.taskGraph.whenReady {
    if (releaseSigning != null) return@whenReady
    val tasks = allTasks.map { it.name }.toSet()
    if ("bundleRelease" in tasks) {
        throw GradleException(
            "No android/key.properties: an App Bundle is never signed with the debug keys.",
        )
    }
    if ("assembleRelease" in tasks) {
        logger.warn("No android/key.properties: this release APK is signed with the DEBUG keys and is not for distribution.")
    }
}

android {
    namespace = "com.aiacademyasia.aia_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aiacademyasia.aia_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseSigning?.let { props ->
            create("release") {
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The upload key when android/key.properties provides one; otherwise
            // the debug keys for local release runs only — see the top of this file.
            signingConfig = signingConfigs.getByName(if (releaseSigning != null) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
