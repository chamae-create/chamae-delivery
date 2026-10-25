import java.security.KeyStore
import java.security.cert.X509Certificate
import java.util.Properties
import javax.naming.ldap.LdapName

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Standard Flutter local signing contract. key.properties and keystores are ignored
// by Git. No password, alias or debug fallback is embedded in the build script.
val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
if (releasePropertiesFile.isFile) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
val releaseSigningValues = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .associateWith { releaseProperties.getProperty(it) }
val releaseStoreFile = releaseSigningValues["storeFile"]
    ?.takeIf { it.isNotBlank() }?.let { file(it) }

val validateChamaeReleaseSigning = tasks.register("validateChamaeReleaseSigning") {
    group = "verification"
    description = "Validates local release signing without exposing credentials."
    notCompatibleWithConfigurationCache("Release signing credentials must be checked for each invocation.")
    doLast {
        if (!releasePropertiesFile.isFile || releaseSigningValues.values.any { it.isNullOrBlank() }) {
            throw GradleException("CHAMAE_RELEASE_SIGNING_MISSING: configure android/key.properties with an authorized upload key.")
        }
        val store = releaseStoreFile
        if (store == null || !store.isFile) {
            throw GradleException("CHAMAE_RELEASE_KEYSTORE_MISSING: the configured keystore is unavailable.")
        }
        try {
            val keyStore = KeyStore.getInstance(store, releaseSigningValues.getValue("storePassword")!!.toCharArray())
            val entry = keyStore.getEntry(
                releaseSigningValues.getValue("keyAlias"),
                KeyStore.PasswordProtection(releaseSigningValues.getValue("keyPassword")!!.toCharArray())
            )
            if (entry !is KeyStore.PrivateKeyEntry) {
                throw GradleException("CHAMAE_RELEASE_PRIVATE_KEY_REQUIRED: review the authorized signing configuration.")
            }
            val certificate = entry.certificate as? X509Certificate
                ?: throw GradleException("CHAMAE_RELEASE_CERTIFICATE_INVALID: review the signing certificate.")
            certificate.checkValidity()
            val debugCertificate = LdapName(certificate.subjectX500Principal.name).rdns.any {
                it.type.equals("CN", ignoreCase = true) && it.value.toString().equals("Android Debug", ignoreCase = true)
            }
            if (store.name.equals("debug.keystore", ignoreCase = true) || debugCertificate) {
                throw GradleException("CHAMAE_RELEASE_DEBUG_KEY_FORBIDDEN: debug signing cannot produce a release.")
            }
        } catch (error: GradleException) {
            throw error
        } catch (_: Exception) {
            // Never include provider/keystore exceptions, paths, aliases or passwords.
            throw GradleException("CHAMAE_RELEASE_KEYSTORE_INVALID: verify credentials and certificate validity locally.")
        }
    }
}

// Also protects aggregate tasks (build/assemble) through their release subtasks.
// Debug/profile and clean tasks remain independent of release credentials.
tasks.configureEach {
    if (name.contains("release", ignoreCase = true) &&
        !name.startsWith("clean", ignoreCase = true) && name != validateChamaeReleaseSigning.name) {
        dependsOn(validateChamaeReleaseSigning)
    }
}

android {
    namespace = "br.com.loumak.chamae"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        manifestPlaceholders["MAPS_API_KEY"] = providers.gradleProperty("CHAMAE_MAPS_API_KEY")
            .orElse(providers.environmentVariable("CHAMAE_MAPS_API_KEY")).getOrElse("")
        // Official Chamaê application ID; Firebase must register the same package.
        applicationId = "br.com.loumak.chamae"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseStoreFile
            storePassword = releaseSigningValues["storePassword"]
            keyAlias = releaseSigningValues["keyAlias"]
            keyPassword = releaseSigningValues["keyPassword"]
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
