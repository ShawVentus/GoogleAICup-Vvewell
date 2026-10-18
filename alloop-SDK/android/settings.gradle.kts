pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // Use Aliyun mirrors for better network stability in China (Plugin Management)
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        // Fallback to official repositories
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.2.20" apply false
}

include(":app")
// XiaoZhi is supplied with this project as an Android BLE SDK. Keep it as a
// separate module so the existing Flutter ring plugins remain untouched.
include(":xiaozhi-ble")
project(":xiaozhi-ble").projectDir = file("../hardware/xiaozhi/xiaozhi-ble-sdk/xiaozhi-ble")
// Kept independent from the ring and XiaoZhi modules.
include(":radar-bridge")
project(":radar-bridge").projectDir = file("../hardware/android_radar_bridge/radar-bridge")
