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

// CameraX 1.5 exposes CallbackToFutureAdapter in its public API.  With AGP 9
// the library module must compile against concurrent-futures explicitly; an
// app-level dependency does not reach the camera plugin's compile classpath.
subprojects {
    if (name == "camera_android_camerax") {
        afterEvaluate {
            dependencies.add(
                "implementation",
                "androidx.concurrent:concurrent-futures:1.1.0",
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
