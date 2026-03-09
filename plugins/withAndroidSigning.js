// @ts-check
const { withAppBuildGradle } = require('@expo/config-plugins');

/**
 * Expo config plugin that injects a release signingConfig into the generated
 * android/app/build.gradle. Credentials are read from Gradle properties so
 * they can be set globally in ~/.gradle/gradle.properties and never committed.
 *
 * Required properties (add to ~/.gradle/gradle.properties):
 *   RELEASE_STORE_FILE=<absolute path to your .keystore file>
 *   RELEASE_KEY_ALIAS=m3u-tv
 *   RELEASE_STORE_PASSWORD=<your store password>
 *   RELEASE_KEY_PASSWORD=<your key password>
 */
const withAndroidSigning = (config) =>
  withAppBuildGradle(config, (mod) => {
    let contents = mod.modResults.contents;

    // Idempotency guard — don't add twice
    if (contents.includes('RELEASE_STORE_FILE')) {
      return mod;
    }

    // 1. Add a release signingConfig block after the existing debug one
    contents = contents.replace(
      /signingConfigs\s*\{([\s\S]*?debug\s*\{[\s\S]*?\})\s*\}/,
      (match, debugBlock) =>
        `signingConfigs {${debugBlock}
        release {
            storeFile file(findProperty('RELEASE_STORE_FILE') ?: 'release.keystore')
            storePassword findProperty('RELEASE_STORE_PASSWORD') ?: ''
            keyAlias findProperty('RELEASE_KEY_ALIAS') ?: ''
            keyPassword findProperty('RELEASE_KEY_PASSWORD') ?: ''
        }
    }`,
    );

    // 2. Point the release buildType at the new signingConfig
    contents = contents.replace(
      /(buildTypes\s*\{[\s\S]*?release\s*\{[\s\S]*?)signingConfig\s+signingConfigs\.debug/,
      '$1signingConfig signingConfigs.release',
    );

    mod.modResults.contents = contents;
    return mod;
  });

module.exports = withAndroidSigning;
