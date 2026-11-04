# Setup per platform

## Android
- Izin sudah ditambahkan `bootstrap.sh` (MANAGE_EXTERNAL_STORAGE = "All files access"; butuh persetujuan khusus bila rilis ke Play Store, aman untuk APK/F-Droid).
- `local_auth`: ubah `MainActivity` menjadi `FlutterFragmentActivity` (android/app/src/main/kotlin/.../MainActivity.kt).
- minSdk 24 (`android/app/build.gradle`: `minSdk = 24`).

## iOS
- Sandbox iOS TIDAK mengizinkan akses seluruh filesystem. mab-file bekerja di folder Documents app (+ Files app lewat `UIFileSharingEnabled`).
- Tambah di `ios/Runner/Info.plist`: `NSFaceIDUsageDescription`, `UIFileSharingEnabled=true`, `LSSupportsOpeningDocumentsInPlace=true`.
- Build iOS membutuhkan macOS + Xcode. Instalasi ke perangkat fisik memakai Apple ID gratis (masa berlaku 7 hari).

## macOS
- Untuk akses penuh disk: matikan App Sandbox di `macos/Runner/DebugProfile.entitlements` & `Release.entitlements` (`com.apple.security.app-sandbox` = false).
- Keychain: tambahkan entitlement `keychain-access-groups`.

## Windows
- Aktifkan Developer Mode (symlink plugin). Butuh Visual Studio 2022 (Community, gratis) workload "Desktop development with C++".

## Linux
```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libjsoncpp-dev libmpv-dev mpv p7zip-full
```
