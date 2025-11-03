import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// Репозитории для всех проектов
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Настройка кастомной директории build
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Настройка buildDir для всех под-проектов
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Указываем зависимость оценки под-проектов от :app
subprojects {
    project.evaluationDependsOn(":app")
}

// Задача clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
