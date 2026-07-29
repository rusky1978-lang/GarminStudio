# Sparkle Release Workflow

Use this checklist when publishing a new Garmin Screen Studio update.

## 1. Build

1. Confirm the working tree is clean.
2. Confirm the version and build number are correct in Xcode.
3. Build the app in Xcode.
4. Run a local smoke test of import, browse recordings, and conversion.

## 2. Archive

1. In Xcode, select the release destination.
2. Choose `Product > Archive`.
3. When the archive completes, open it in Organizer.
4. Export the app for distribution.
5. Zip the exported `.app` bundle if the export process did not already create a zip archive.

## 3. Sign With Sparkle

1. On the release machine, confirm the Sparkle private key is available in Keychain.
2. Run Sparkle's signing tool against the final archive:

```sh
sign_update /path/to/GarminScreenStudio.zip
```

3. Keep the printed `sparkle:edSignature` value for the appcast entry.
4. Record the final archive size in bytes.

## 4. Upload To GitHub Release

1. Create a GitHub Release for the new version.
2. Upload the signed archive.
3. Copy the final release asset download URL from GitHub.
4. Do not guess or hand-type the asset URL.

## 5. Update Appcast

1. Add a new `<item>` to `appcast.xml`.
2. Set `sparkle:version` to the build number.
3. Set `sparkle:shortVersionString` to the user-facing app version.
4. Set `url` to the final GitHub Release asset URL.
5. Set `sparkle:edSignature` to the value from `sign_update`.
6. Set `length` to the archive size in bytes.
7. Add release notes in the `<description>` block.
8. Upload `appcast.xml` to the configured `SUFeedURL` location.
9. Test update detection from an older installed build.
