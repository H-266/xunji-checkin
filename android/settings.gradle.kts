pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 国内镜像优先，官方仓库兜底。仅改下载来源，不改依赖版本。
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 使用本机 Gradle 缓存中已有的稳定版本，避免首次构建长时间卡在依赖下载。
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
}

include(":app")
