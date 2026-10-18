allprojects {
    repositories {
        // Use Aliyun mirror for better network stability in China
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        // Prefer Maven Central for standard Java/Kotlin artifacts; a mirror
        // transport failure otherwise prevents Gradle from reaching fallback.
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/jcenter") }
        // Fallback to official repositories
        google()
        maven { url = uri("https://maven.rokid.com/repository/maven-public/") }
        maven { url = uri("https://jitpack.io") }
        // Embedded maven repo for the alloop_blue_lite plugin's native core
        // (com.alloop:core:1.0.0). The plugin's own android/build.gradle
        // registers this repo too, but that registration doesn't propagate
        // to the app module's dependency resolution, so it must also be
        // declared here.
        maven { url = uri("${rootDir}/../packages/alloop_blue_lite/android/repo") }
        // Embedded flatDir repo for the aizoring_blue_lite plugin's AARs
        flatDir { dirs("${rootDir}/../packages/aizoring_blue_lite/android/libs") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
