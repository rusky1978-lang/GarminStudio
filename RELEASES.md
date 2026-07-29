# Release Publishing

This project uses Sparkle 2 for macOS app updates.

## Required Values

Before publishing updates, fill in the missing production values:

- `SUFeedURL`: TODO, the final HTTPS URL where `appcast.xml` will be hosted.
- Sparkle private signing key: stored in the release machine's login Keychain.
- GitHub Release download URL: TODO, created after uploading the signed release asset.

Do not publish an update until the appcast URL and Sparkle signing key are confirmed.

## Publish A New Version

1. Update the app version and build number in Xcode.
2. Build and test the app locally.
3. Archive the app with Xcode.
4. Export the archive for distribution.
5. Sign the exported app archive with Sparkle's `sign_update` tool.
6. Create a GitHub Release for the version.
7. Upload the signed app archive to the GitHub Release.
8. Copy the final release asset download URL from GitHub.
9. Update `appcast.xml` with the new version, download URL, file length, Sparkle signature, and release notes.
10. Upload the updated `appcast.xml` to the production appcast host.
11. Launch the previously released app and use `Garmin Screen Studio > Check for Updates...` to verify the update is detected.

## Sparkle Signing

Generate or retrieve the Sparkle EdDSA key on the release machine:

```sh
generate_keys
```

Sign a release archive:

```sh
sign_update /path/to/GarminScreenStudio.zip
```

Copy the `sparkle:edSignature` value printed by `sign_update` into `appcast.xml`.

## Safety Checks

- The appcast URL must use HTTPS.
- The uploaded archive URL must be the final downloadable release asset URL.
- The Sparkle public key in the app must match the private key used by `sign_update`.
- Keep the private key in Keychain; do not commit exported private keys.
