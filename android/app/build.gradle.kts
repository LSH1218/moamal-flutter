import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// local.properties에서 소셜 로그인 키를 읽어 manifestPlaceholders에 주입
val localProps = Properties().also { props ->
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use(props::load)
}

android {
    namespace = "com.moamal.prototype"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.moamal.prototype"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // AndroidManifest.xml의 ${KAKAO_NATIVE_APP_KEY} 등을 local.properties 값으로 치환
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] =
            localProps.getProperty("KAKAO_NATIVE_APP_KEY", "")
        manifestPlaceholders["NAVER_CLIENT_ID"] =
            localProps.getProperty("NAVER_CLIENT_ID", "")
        manifestPlaceholders["NAVER_CLIENT_SECRET"] =
            localProps.getProperty("NAVER_CLIENT_SECRET", "")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
