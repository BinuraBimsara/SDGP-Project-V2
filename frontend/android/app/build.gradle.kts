import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read MAPS_API_KEY from local.properties (git-ignored)
val localPropsFile = rootProject.file("local.properties")
val localProps = Properties()
if (localPropsFile.exists()) {
    localPropsFile.reader().use { localProps.load(it) }
}
val mapsApiKey: String = localProps.getProperty("MAPS_API_KEY", "")

android {
    namespace = "com.example.spotit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.spotit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            // Intentionally no debug signing in release.
            // Configure a proper release keystore via signingConfigs before production builds.
        }
    }
}

flutter {
    source = "../.."
}
