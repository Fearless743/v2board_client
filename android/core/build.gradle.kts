import java.util.Properties

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}
val appTitle = localProperties.getProperty("app.title", "FlClashX")

android {
    namespace = "com.follow.clashx.core"
    compileSdk = 36
    ndkVersion = "28.0.13004108"

    defaultConfig {
        minSdk = 23

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            isJniDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    externalNativeBuild {
        cmake {
            path("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    implementation("androidx.annotation:annotation-jvm:1.9.1")
}

val copyNativeLibs by tasks.register<Copy>("copyNativeLibs") {
    doFirst {
        val libclashDir = file("../../libclash/android")
        val missingAbis = listOf("armeabi-v7a", "arm64-v8a", "x86_64").filter {
            !file("../../libclash/android/$it/libclash.so").exists()
        }
        if (!libclashDir.exists() || missingAbis.isNotEmpty()) {
            val missingAbiMessage = if (missingAbis.isEmpty()) "" else " Missing ABIs: ${missingAbis.joinToString(", ")}."
            throw GradleException(
                "Missing native core artifacts at libclash/android. " +
                    "Run: dart setup.dart dev --target android. " +
                    "Then retry: flutter run -d <android-device>." +
                    missingAbiMessage
            )
        }
        delete("src/main/jniLibs")
    }
    from("../../libclash/android")
    into("src/main/jniLibs")

    doLast {
        val includesDir = file("src/main/jniLibs/includes")
        val targetDir = file("src/main/cpp/includes")
        if (includesDir.exists()) {
            copy {
                from(includesDir)
                into(targetDir)
            }
            delete(includesDir)
        }
    }
}

afterEvaluate {
    tasks.named("preBuild") {
        dependsOn(copyNativeLibs)
    }
}