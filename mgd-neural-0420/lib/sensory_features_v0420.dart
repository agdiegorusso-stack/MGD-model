import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Low-level descriptors only. No semantic recognition or transcription.
class SensoryFeatures420 {
  static Map<String, double> vision(Uint8List bytes) {
    if (bytes.length > 16 * 1024 * 1024)
      throw StateError('Immagine troppo grande.');
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('Immagine non decodificabile.');
    final resized = img.copyResize(decoded,
        width: 48, height: 48, interpolation: img.Interpolation.average);
    return {'v:bias': .25, ..._visionFeatures(resized)};
  }

  static Map<String, double> audio(Uint8List bytes,
      {int sampleRate = 16000}) {
    if (bytes.length < 800) throw StateError('Registrazione troppo breve.');
    if (sampleRate != 16000 || bytes.length.isOdd || bytes.length > 640000) {
      throw StateError('Usa audio PCM16 mono a 16 kHz, massimo 20 secondi.');
    }
    final bd = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    final samples = Float64List(n);
    for (var i = 0; i < n; i++) {
      samples[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return {'a:bias': .05, ..._audioFeatures(samples, sampleRate)};
  }

  static Map<String, double> _visionFeatures(img.Image image) {
    final out = <String, double>{};
    final gray =
        List.generate(image.height, (_) => List<double>.filled(image.width, 0));
    var sr = 0.0, sg = 0.0, sb = 0.0, sy = 0.0, sy2 = 0.0, ss = 0.0;
    final hue = List<double>.filled(8, 0);
    final grid = List<double>.filled(9, 0);
    final gridN = List<int>.filled(9, 0);
    final count = image.width * image.height;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble() / 255.0;
        final g = p.g.toDouble() / 255.0;
        final b = p.b.toDouble() / 255.0;
        final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
        gray[y][x] = lum;
        sr += r;
        sg += g;
        sb += b;
        sy += lum;
        sy2 += lum * lum;
        final mx = max(r, max(g, b));
        final mn = min(r, min(g, b));
        final d = mx - mn;
        final sat = mx <= 1e-9 ? 0.0 : d / mx;
        ss += sat;
        var h = 0.0;
        if (d > 1e-9) {
          if (mx == r) {
            h = ((g - b) / d) % 6;
          } else if (mx == g) {
            h = (b - r) / d + 2;
          } else {
            h = (r - g) / d + 4;
          }
          h /= 6;
          if (h < 0) h += 1;
        }
        hue[min(7, (h * 8).floor())] += sat * (0.25 + 0.75 * mx);
        final gx = min(2, x * 3 ~/ image.width);
        final gy = min(2, y * 3 ~/ image.height);
        final gi = gy * 3 + gx;
        grid[gi] += lum;
        gridN[gi]++;
      }
    }

    final mean = sy / count;
    out['v:rgb:r'] = sr / count;
    out['v:rgb:g'] = sg / count;
    out['v:rgb:b'] = sb / count;
    out['v:lum:mean'] = mean;
    out['v:lum:std'] = sqrt(max(0, sy2 / count - mean * mean)).clamp(0.0, 1.0);
    out['v:sat'] = ss / count;
    final hueSum = hue.fold<double>(0, (a, b) => a + b) + 1e-9;
    for (var i = 0; i < hue.length; i++) out['v:hue:$i'] = hue[i] / hueSum;
    for (var i = 0; i < grid.length; i++)
      out['v:grid:$i'] = grid[i] / max(1, gridN[i]);

    final orient = List<double>.filled(8, 0);
    var edgeSum = 0.0;
    for (var y = 1; y < image.height - 1; y++) {
      for (var x = 1; x < image.width - 1; x++) {
        final dx = gray[y][x + 1] - gray[y][x - 1];
        final dy = gray[y + 1][x] - gray[y - 1][x];
        final mag = sqrt(dx * dx + dy * dy);
        if (mag < 0.025) continue;
        var angle = atan2(dy, dx);
        if (angle < 0) angle += pi;
        if (angle >= pi) angle -= pi;
        final bin = min(7, (angle / pi * 8).floor());
        orient[bin] += mag;
        edgeSum += mag;
      }
    }
    final denom = edgeSum + 1e-9;
    out['v:edge:density'] = (edgeSum / (count * 0.55)).clamp(0.0, 1.0);
    for (var i = 0; i < orient.length; i++)
      out['v:edge:$i'] = orient[i] / denom;
    return out;
  }

  static Map<String, double> _audioFeatures(Float64List s, int sampleRate) {
    final out = <String, double>{};
    var energy = 0.0;
    var zc = 0;
    for (var i = 0; i < s.length; i++) {
      energy += s[i] * s[i];
      if (i > 0 && ((s[i] >= 0) != (s[i - 1] >= 0))) zc++;
    }
    final rms = sqrt(energy / max(1, s.length));
    out['a:rms'] = (rms * 4).clamp(0.0, 1.0);
    out['a:zcr'] = (zc / max(1, s.length - 1) * 12).clamp(0.0, 1.0);

    const freqs = <double>[125, 250, 500, 750, 1000, 1500, 2500, 4000];
    final powers = <double>[];
    for (final f in freqs) powers.add(_goertzel(s, sampleRate, f));
    final powerSum = powers.fold<double>(0, (a, b) => a + b) + 1e-12;
    var centroid = 0.0;
    for (var i = 0; i < freqs.length; i++) {
      final v = powers[i] / powerSum;
      out['a:band:$i'] = v;
      centroid += freqs[i] * v;
    }
    out['a:centroid'] = (centroid / 4000).clamp(0.0, 1.0);

    const segments = 8;
    for (var k = 0; k < segments; k++) {
      final a = k * s.length ~/ segments;
      final b = (k + 1) * s.length ~/ segments;
      var e = 0.0;
      for (var i = a; i < b; i++) e += s[i] * s[i];
      final local = sqrt(e / max(1, b - a));
      out['a:env:$k'] = (local * 4).clamp(0.0, 1.0);
    }

    final pitch = _estimatePitch(s, sampleRate);
    out['a:pitch'] = pitch == null ? 0 : ((pitch - 70) / 330).clamp(0.0, 1.0);
    out['a:voiced'] = pitch == null ? 0 : 1;
    return out;
  }

  static double _goertzel(Float64List s, int sampleRate, double frequency) {
    final n = min(s.length, sampleRate * 2);
    final omega = 2 * pi * frequency / sampleRate;
    final coeff = 2 * cos(omega);
    var q0 = 0.0, q1 = 0.0, q2 = 0.0;
    const stride = 1; // Preserve the actual sampling rate in Goertzel recurrence.
    var used = 0;
    for (var i = 0; i < n; i += stride) {
      q0 = coeff * q1 - q2 + s[i];
      q2 = q1;
      q1 = q0;
      used++;
    }
    return max(0, q1 * q1 + q2 * q2 - coeff * q1 * q2) / max(1, used);
  }

  static double? _estimatePitch(Float64List s, int sampleRate) {
    final n = min(s.length, 6000);
    if (n < 1000) return null;
    final minLag = sampleRate ~/ 400;
    final maxLag = min(sampleRate ~/ 70, n ~/ 3);
    var bestLag = 0;
    var best = 0.0;
    var zero = 0.0;
    for (var i = 0; i < n; i += 2) zero += s[i] * s[i];
    if (zero < 1e-4) return null;
    for (var lag = minLag; lag <= maxLag; lag += 2) {
      var c = 0.0;
      for (var i = 0; i < n - lag; i += 2) c += s[i] * s[i + lag];
      if (c > best) {
        best = c;
        bestLag = lag;
      }
    }
    if (bestLag == 0 || best / zero < 0.18) return null;
    return sampleRate / bestLag;
  }

}
