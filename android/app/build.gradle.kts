import java.text.SimpleDateFormat
import java.util.Date
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release Signing ───────────────────────────────────────────────────────────
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}
// ─────────────────────────────────────────────────────────────────────────────

// ── Build-Info Generator ──────────────────────────────────────────────────────
// Generates lib/generated/build_info.dart with current timestamp before each build.
tasks.register("generateBuildInfo") {
    description = "Generate Build info"
    doFirst {
        val sdf = SimpleDateFormat("dd.MM.yyyy HH:mm")
        val timestamp = sdf.format(Date())
        val outputFile = File("${rootDir}/../lib/generated/build_info.dart")
        outputFile.parentFile.mkdirs()
        outputFile.writeText(
            "// Auto-generated – do not edit manually.\n" +
            "// ignore_for_file: constant_identifier_names\n" +
            "const String kBuildTimestamp = '$timestamp';\n"
        )
        println("✓ build_info.dart generated: $timestamp")
    }
}

tasks.named("preBuild") {
    dependsOn("generateBuildInfo")
}
// ─────────────────────────────────────────────────────────────────────────────

android {
    namespace = "de.leskate.inliner"
    // flutter_secure_storage requires compiling against Android SDK 37.
    // Override Flutter's default (36); higher compile SDKs are backward compatible.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    // Disable the automatic "lint vital" analysis that Gradle otherwise runs
    // as part of every release build. It currently crashes with
    // "NoSuchMethodError: java.util.List.removeLast()" on some CI runners -
    // a known bug in the Lint tool bundled with AGP (JDK/Kotlin PSI
    // incompatibility), unrelated to our own code. Full lint checks can still
    // be run manually via `./gradlew lint`.
    lint {
        checkReleaseBuilds = false
    }

    signingConfigs {
        // Only register the real release signing config if key.properties exists
        // (it's gitignored / provided locally or via CI secrets). This lets CI
        // builds without the keystore fall back to debug signing instead of
        // failing the Gradle configuration with a null keyAlias/storeFile.
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "de.leskate.inliner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Fall back to debug signing when no release keystore is configured
            // (e.g. CI runs without the ANDROID_KEYSTORE_BASE64 secret set).
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            ndk {
                debugSymbolLevel = "NONE"
            }

            // Custom keep rule for Room-generated database implementations (e.g.
            // WorkManager's WorkDatabase_Impl), see proguard-rules.pro for details.
            // Without it, R8 minification (enabled by default for release builds)
            // strips the reflectively-instantiated no-arg constructor, causing a
            // release-only crash on startup that does not occur in debug builds
            // (debug builds are not minified).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

}

androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            output.outputFileName.set(
                output.versionName.map { versionName ->
                    "LE_Skate_${versionName}-${variant.buildType}.apk"
                }
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
    }
}

// Force a modern androidx.work:work-runtime version. The transitive dependency
// pulled in by play-services-ads resolves to the outdated 2.7.0, whose consumer
// ProGuard rules don't fully protect Room's generated WorkDatabase implementation
// under R8, causing a release-only crash on startup
// ("Failed to create an instance of androidx.work.impl.WorkDatabase").
configurations.all {
    resolutionStrategy {
        force("androidx.work:work-runtime:2.10.1")
    }
}

flutter {
    source = "../.."
}
