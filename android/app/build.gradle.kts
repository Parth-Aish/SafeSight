plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.safesight" 
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required for Local Notifications plugin
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.safesight"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Java 8 desugaring engine
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 🚨 FIX: Force 1.13.1 which perfectly matches API 34!
    implementation("androidx.browser:browser") {
        version { strictly("1.8.0") }
    }
    implementation("androidx.core:core") {
        version { strictly("1.13.1") }
    }
    implementation("androidx.core:core-ktx") {
        version { strictly("1.13.1") }
    }
}