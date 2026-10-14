plugins {
    kotlin("jvm") version "2.4.0"
    application
}
repositories { google(); mavenCentral() }
dependencies {
    implementation("com.google.ai.edge.litertlm:litertlm-jvm:0.18.0")
    implementation("com.google.code.gson:gson:2.13.2")
}
kotlin { jvmToolchain(21) }
application { mainClass.set("SmokeKt") }
tasks.withType<JavaExec>().configureEach { maxHeapSize = "2g" }
