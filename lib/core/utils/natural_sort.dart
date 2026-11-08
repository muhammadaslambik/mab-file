/// Urutan "alami": deret angka dibandingkan sebagai angka (file2 < file10),
/// huruf tidak peduli kapital. Nol di depan hanya jadi penentu terakhir (a1 < a01).
int naturalCompare(String a, String b) {
  final x = a.toLowerCase(), y = b.toLowerCase();
  bool digit(int c) => c >= 48 && c <= 57;
  var i = 0, j = 0, tie = 0;
  while (i < x.length && j < y.length) {
    final cx = x.codeUnitAt(i), cy = y.codeUnitAt(j);
    if (digit(cx) && digit(cy)) {
      final si = i, sj = j;
      while (i < x.length && digit(x.codeUnitAt(i))) {
        i++;
      }
      while (j < y.length && digit(y.codeUnitAt(j))) {
        j++;
      }
      var ax = si, ay = sj;
      while (ax < i - 1 && x.codeUnitAt(ax) == 48) {
        ax++;
      }
      while (ay < j - 1 && y.codeUnitAt(ay) == 48) {
        ay++;
      }
      final lx = i - ax, ly = j - ay;
      if (lx != ly) return lx < ly ? -1 : 1;
      for (var k = 0; k < lx; k++) {
        final d = x.codeUnitAt(ax + k) - y.codeUnitAt(ay + k);
        if (d != 0) return d < 0 ? -1 : 1;
      }
      final zx = ax - si, zy = ay - sj;
      if (tie == 0 && zx != zy) tie = zx < zy ? -1 : 1;
    } else {
      if (cx != cy) return cx < cy ? -1 : 1;
      i++;
      j++;
    }
  }
  final rest = (x.length - i) - (y.length - j);
  if (rest != 0) return rest < 0 ? -1 : 1;
  return tie;
}
