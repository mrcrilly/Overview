# Building and releasing Overview

The **Build and release macOS app** workflow builds the shared `Overview` Xcode
scheme in Release configuration on macOS 15 with Xcode 26.3. It builds a universal
app for Apple Silicon (`arm64`) and Intel (`x86_64`), targeting macOS 13 or later.
Swift packages use the versions in the committed `Package.resolved` file.

## Publish a release

1. Push the workflow and the changes you want to release to GitHub.
2. Create and push a version tag on that commit, for example:

   ```sh
   git tag v1.2.4
   git push origin v1.2.4
   ```

3. Follow the workflow in the repository's **Actions** tab. After the build and
   packaging checks pass, it creates a GitHub Release for the existing tag with
   generated release notes and one download:
   `Overview-v1.2.4-macOS-universal.dmg`. It contains `Overview.app` and an
   Applications shortcut for drag-and-drop installation.

Tags must use `vMAJOR.MINOR.PATCH`, optionally followed by a suffix such as
`-beta.1`. Tags with a suffix create GitHub prereleases. The numeric version goes
into the app's marketing version, and the workflow run number becomes its build
number. The complete tag appears in asset names and the release title.

Rerunning a tag workflow replaces its release assets while preserving existing
release notes and publication status. No personal access token is needed: only
the release job receives `contents: write` on GitHub's built-in token. GitHub
Actions must be enabled for the repository, including when using a fork.

## Build without publishing

Pull requests and pushes to `main` build and package the app, with downloadable
artifacts retained for 14 days. They do not create releases. **Run workflow** on a
branch also builds without publishing; dispatching on an existing version tag
publishes that tag. Branch builds use the placeholder version `0.0.0` and include
the run number in their filenames.

To run the same build and packaging process locally with Xcode installed:

```sh
BUILD_NUMBER=1 bash scripts/build-release.sh v1.2.4
```

The DMG is written to `.build/release/`. The built app is also
available at `.build/ReleaseDerivedData/Build/Products/Release/Overview.app`.

## Signing and updates

The pipeline uses ad-hoc signing, which requires no Apple credentials. The app is
**not signed with a Developer ID certificate or notarized by Apple**, so macOS
Gatekeeper may block opening downloaded builds until the user explicitly allows
them. Public distribution without that extra approval requires adding Developer
ID signing and notarization with the maintainer's Apple credentials.

Publishing these downloads does not update Sparkle's appcast. The project still
contains the upstream Sparkle feed and public key in `Overview/Info.plist`; in-app
updates do not track this fork's GitHub Releases. Install these releases manually.
