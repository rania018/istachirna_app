pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "istachirna_app"
include(":app")

// Flutter settings
apply(from = "${settingsDir.parentFile.toPath()}/.android/include_flutter.groovy")

// Add Flutter SDK path
gradle.beforeProject {
    val flutterSdkPath = System.getenv("FLUTTER_ROOT") ?: System.getProperty("user.home") + "/flutter"
    extra["flutter.sdk"] = flutterSdkPath
} 