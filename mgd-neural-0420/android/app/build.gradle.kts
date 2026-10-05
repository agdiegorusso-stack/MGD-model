plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.diegorusso.mgd_neuro_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "it.diegorusso.mgdneurostable"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val customStore = System.getenv("MGD_STORE_FILE")
    if (!customStore.isNullOrBlank()) {
        signingConfigs {
            create("mgdRelease") {
                storeFile = file(customStore)
                storePassword = requireNotNull(System.getenv("MGD_STORE_PASSWORD"))
                keyAlias = requireNotNull(System.getenv("MGD_KEY_ALIAS"))
                keyPassword = requireNotNull(System.getenv("MGD_KEY_PASSWORD"))
            }
        }
    }

    buildTypes {
        release {
            // Development installation by default; an owned key is optional.
            signingConfig = signingConfigs.getByName(
                if (customStore.isNullOrBlank()) "debug" else "mgdRelease"
            )
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
