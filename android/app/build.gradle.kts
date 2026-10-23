plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

/**
 * M4 离线包：mock/h5 是唯一来源，不复制进 android/。构建时同步到 build/generated 下，
 * 再登记成 assets 目录，打进 APK 后路径是 assets/h5/index.html（spec 公共约定）。
 * 改了 mock/h5 直接重新运行就行，Gradle 发现输入变了会重新同步
 */
abstract class SyncH5Task : DefaultTask() {
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val source: DirectoryProperty

    /** AGP 负责给这个目录赋值，并把它当成 assets 根目录 */
    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @get:Inject
    abstract val fs: FileSystemOperations

    @TaskAction
    fun sync() {
        fs.sync {
            from(source)
            into(outputDir.dir("h5"))
        }
    }
}

val mockH5 = rootProject.layout.projectDirectory.dir("../mock/h5")

androidComponents {
    onVariants { variant ->
        val task = tasks.register<SyncH5Task>("sync${variant.name.replaceFirstChar { it.uppercase() }}H5") {
            source.set(mockH5)
        }
        variant.sources.assets?.addGeneratedSourceDirectory(task, SyncH5Task::outputDir)
    }
}

android {
    namespace = "com.example.mobile3end"
    // compileSdk 只决定能用哪些 API，和 targetSdk（运行时行为）分开升；Compose BOM 2026.09 要求 ≥ 37
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.example.mobile3end"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.navigation.compose)
    debugImplementation(libs.androidx.compose.ui.tooling)

    // M2
    implementation(libs.okhttp)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)

    // M3
    implementation(libs.androidx.lifecycle.process)
    // M5（M4 的想一想也会用到）：WebViewCompat，新版 WebView 能力的兼容层
    implementation(libs.androidx.webkit)

    // 填空检查：纯逻辑跑 JVM 单测，UI 跑模拟器上的仪器测试。见 check.sh
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.okhttp.mockwebserver)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.espresso.core)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
