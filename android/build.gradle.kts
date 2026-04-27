// File: android/build.gradle.kts (Project Level)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Carichiamo il plugin Google qui per evitare conflitti con il blocco plugins
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Manteniamo la tua configurazione delle directory di build
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ABBIAMO RIMOSSO IL BLOCCO PLUGINS DA QUI PERCHÉ FLUTTER LO GESTISCE IN SETTINGS.GRADLE