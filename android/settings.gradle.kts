import groovy.json.JsonSlurper
import java.nio.charset.StandardCharsets
import java.util.Base64

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
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

val firebaseConfigFile = file("../config/firebase.android.json")
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseBuildRequested && !firebaseConfigFile.exists()) {
    throw GradleException(
        "Android release builds require the ignored local file " +
            "config/firebase.android.json."
    )
}
if (firebaseConfigFile.exists()) {
    @Suppress("UNCHECKED_CAST")
    val firebaseConfig =
        JsonSlurper().parse(firebaseConfigFile) as Map<String, Any?>
    val requiredKeys =
        setOf(
            "FIREBASE_API_KEY",
            "FIREBASE_APP_ID",
            "FIREBASE_MESSAGING_SENDER_ID",
            "FIREBASE_PROJECT_ID"
        )
    if (requiredKeys.any { firebaseConfig[it]?.toString().isNullOrBlank() }) {
        throw GradleException(
            "config/firebase.android.json is missing required Firebase values."
        )
    }
    gradle.beforeProject {
        if (name == "app") {
            val existing = findProperty("dart-defines")?.toString().orEmpty()
            val existingKeys =
                existing.split(',').mapNotNull { encoded ->
                    if (encoded.isBlank()) {
                        null
                    } else {
                        String(
                            Base64.getDecoder().decode(encoded),
                            StandardCharsets.UTF_8
                        ).substringBefore('=')
                    }
                }.toSet()
            val missingFirebaseDefines =
                firebaseConfig.entries
                    .filter { (key, _) -> key !in existingKeys }
                    .joinToString(",") { (key, value) ->
                        Base64.getEncoder().encodeToString(
                            "$key=${value ?: ""}".toByteArray(StandardCharsets.UTF_8)
                        )
                    }
            extensions.extraProperties["dart-defines"] =
                listOf(existing, missingFirebaseDefines)
                    .filter { it.isNotBlank() }
                    .joinToString(",")
        }
    }
}

include(":app")
