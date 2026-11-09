import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/core/settings/settings.dart';

void main() {
  test('JSON bolak-balik', () {
    const s = AppSettings(
      themeId: 'porcelain',
      animated: true,
      ffmpegPath: 'C:/ff/ffmpeg.exe',
      editorFont: 16,
      videoMode: 'system',
      mpvHwdec: 'd3d11va',
    );
    final r = AppSettings.fromJson(s.toJson());
    expect(r.themeId, 'porcelain');
    expect(r.animated, isTrue);
    expect(r.ffmpegPath, 'C:/ff/ffmpeg.exe');
    expect(r.editorFont, 16);
    expect(r.videoMode, 'system');
    expect(r.mpvHwdec, 'd3d11va');
  });

  test('nilai bawaan bila JSON kosong atau rusak sebagian', () {
    final s = AppSettings.fromJson({});
    expect(s.themeId, 'aurora');
    expect(s.animated, isFalse);
    expect(s.videoMode, 'auto');
    expect(s.mpvHwdec, 'default');
    expect(s.editorFont, 14);
    expect(AppSettings.fromJson({'editorFont': 18}).editorFont, 18.0);
  });
}
