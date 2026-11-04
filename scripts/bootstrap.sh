#!/usr/bin/env bash
set -euo pipefail
command -v flutter >/dev/null || { echo "Flutter belum terpasang: https://docs.flutter.dev/get-started/install"; exit 1; }
flutter create --org id.mab --project-name mab_file --platforms=android,ios,windows,macos,linux .
flutter pub get
# Izin Android (akses semua file)
M=android/app/src/main/AndroidManifest.xml
if [ -f "$M" ] && ! grep -q MANAGE_EXTERNAL_STORAGE "$M"; then
python3 - "$M" <<'PY'
import sys
f=sys.argv[1]; s=open(f).read()
perm='''    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
'''
s=s.replace('<application',perm+'    <application',1)
open(f,'w').write(s)
PY
fi
echo "Selesai. Baca docs/PLATFORM_SETUP.md lalu: flutter run"
