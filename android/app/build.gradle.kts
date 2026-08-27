import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, kept out of the repo. CI writes key.properties from
// repository secrets; locally the file is absent and the build falls back to
// the debug key so `flutter run --release` still works. Every release APK is
// signed with the one shared key, so updates install over each other instead
// of forcing an uninstall.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.kuhy.punchme"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        // Only declared when key.properties exists; otherwise the release
        // build falls back to the debug key below.
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                // Absolute path: key.properties is read from android/, but
                // Gradle's file() resolves against android/app/.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    // Two installable builds from one source tree. `daily` is the real app;
    // `sandbox` carries a different applicationId, so Android gives it its own
    // data directory and it physically cannot read or write the real
    // timesheet, and a different NFC MIME type, so a test tag can never punch
    // the real one. The MIME is a manifest placeholder rather than a
    // --dart-define because the intent filter is read at install time, long
    // before any Dart runs.
    flavorDimensions += "store"
    productFlavors {
        create("daily") {
            dimension = "store"
            manifestPlaceholders["punchMime"] = "application/vnd.kuhy.punchme"
            buildConfigField("String", "PUNCH_MIME",
                "\"application/vnd.kuhy.punchme\"")
        }
        create("sandbox") {
            dimension = "store"
            applicationIdSuffix = ".sandbox"
            versionNameSuffix = "-sandbox"
            manifestPlaceholders["punchMime"] =
                "application/vnd.kuhy.punchme.sandbox"
            buildConfigField("String", "PUNCH_MIME",
                "\"application/vnd.kuhy.punchme.sandbox\"")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.kuhy.punchme"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // The debug fallback keeps `flutter run --release` working with no
            // keystore present. CI must never take it -- the apksigner verify
            // step in ci.yml fails the build if it does.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
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
