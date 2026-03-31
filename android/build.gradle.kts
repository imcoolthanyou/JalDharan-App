allprojects {
    repositories {
        google()
        mavenCentral()
        jcenter() // Fallback for older AR/Sceneform artifacts
    }

    // Force specific Sceneform version to avoid metadata.xml fetch for '+' versioning
    configurations.all {
        resolutionStrategy {
            force("com.google.ar.sceneform:core:1.15.0")
            force("com.google.ar.sceneform.ux:sceneform-ux:1.15.0")
        }
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
