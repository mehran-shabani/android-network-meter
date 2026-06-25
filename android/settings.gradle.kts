pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) localPropertiesFile.inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")
        require(path != null) { "flutter.sdk not set. Add flutter.sdk=/path/to/flutter to android/local.properties or set FLUTTER_ROOT." }
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.12.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
}

include(":app")
