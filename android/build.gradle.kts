allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Force all Android library subprojects (e.g. agora_rtc_engine)
// to compile against SDK 36 so they don't conflict with our app.
// plugins.withId fires at plugin-application time, BEFORE evaluation,
// which avoids the "cannot run afterEvaluate when already evaluated" error.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 36
            defaultConfig {
                ndk {
                    abiFilters.addAll(setOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
