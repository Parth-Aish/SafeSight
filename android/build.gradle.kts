allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ------------------------------------------------------------------
// FLUTTER LEGACY PLUGIN FIX (Injects namespaces & fixes lStar error)
// MOVED UP: Must be declared before evaluationDependsOn(":app")
// ------------------------------------------------------------------
subprojects {
    fun applyAndroidFixes(proj: Project) {
        val androidExt = proj.extensions.findByName("android")
        if (androidExt != null) {
            // 1. Force Compile SDK 35 for ALL plugins (Fixes 'lStar' error)
            try {
                val setCompileSdk = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                setCompileSdk.invoke(androidExt, 35)
            } catch (e: Exception) {
                try {
                    val setCompileSdk2 = androidExt.javaClass.getMethod("setCompileSdk", Int::class.java)
                    setCompileSdk2.invoke(androidExt, 35)
                } catch (e2: Exception) {
                    // Ignore silent failures
                }
            }

            // 2. Inject Namespace for AGP 8+
            try {
                val getNamespaceMethod = androidExt.javaClass.getMethod("getNamespace")
                val namespace = getNamespaceMethod.invoke(androidExt)
                if (namespace == null) {
                    val setNamespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespaceMethod.invoke(androidExt, proj.group.toString())
                }
            } catch (e: Exception) {
                // Ignore silent failures
            }
        }
    }

    // SMART GUARD: If already evaluated, run instantly. Otherwise, queue it.
    if (project.state.executed) {
        applyAndroidFixes(project)
    } else {
        project.afterEvaluate {
            applyAndroidFixes(project)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}