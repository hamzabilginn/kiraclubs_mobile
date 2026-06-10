allprojects {
    repositories {
        google()
        mavenCentral()
    }
    project.ext.set("compileSdkVersion", 34)
    project.ext.set("targetSdkVersion", 34)
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

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 34
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
