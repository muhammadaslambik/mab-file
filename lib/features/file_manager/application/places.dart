import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/paths.dart';

class Place {
  const Place(this.label, this.path, this.icon);
  final String label, path;
  final IconData icon;
}

/// Lokasi cepat ala "Quick access" Explorer / "Favorites" Finder.
final placesProvider = FutureProvider<List<Place>>((ref) async {
  final home = await defaultRoot();
  final List<(String, String, IconData)> c = Platform.isAndroid
      ? [
          ('Penyimpanan', home, Icons.phone_android_rounded),
          ('Unduhan', '$home/Download', Icons.download_rounded),
          ('Dokumen', '$home/Documents', Icons.description_rounded),
          ('Kamera', '$home/DCIM', Icons.photo_camera_rounded),
          ('Gambar', '$home/Pictures', Icons.photo_library_rounded),
          ('Musik', '$home/Music', Icons.library_music_rounded),
          ('Video', '$home/Movies', Icons.video_library_rounded),
        ]
      : [
          ('Beranda', home, Icons.home_rounded),
          ('Desktop', p.join(home, 'Desktop'), Icons.desktop_windows_rounded),
          ('Dokumen', p.join(home, 'Documents'), Icons.description_rounded),
          ('Unduhan', p.join(home, 'Downloads'), Icons.download_rounded),
          ('Gambar', p.join(home, 'Pictures'), Icons.photo_library_rounded),
          ('Musik', p.join(home, 'Music'), Icons.library_music_rounded),
          ('Video', p.join(home, 'Videos'), Icons.video_library_rounded),
          ('Video', p.join(home, 'Movies'), Icons.video_library_rounded),
        ];
  return [
    for (final e in c)
      if (Directory(e.$2).existsSync()) Place(e.$1, e.$2, e.$3),
  ];
});
