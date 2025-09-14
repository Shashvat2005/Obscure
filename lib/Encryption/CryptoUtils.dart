import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart' as crypto;

class ImageCeaserEncryptor {
  static const markerR = 123;
  static const markerG = 45;
  static const markerB = 67;

  Future<void> EncryptImages(List<String> imagePaths, int shift) async {
    for (final path in imagePaths) {
      // Load image
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        print("❌ Failed to decode: $path");
        continue;
      }

      final markerPixel = image.getPixel(0, 0);
      final hasMarker = (markerPixel.r == markerR &&
          markerPixel.g == markerG &&
          markerPixel.b == markerB);
      if (hasMarker) {
        print("⚠️ Already encrypted (marker found), skipping: $path");
        continue;
      }

      // Apply Caesar shift on pixels
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          if (x == 0 && y == 0) {
            // Set marker pixel
            image.setPixelRgba(x, y, markerR, markerG, markerB, 255);
            continue;
          }

          final pixel = image.getPixel(x, y);
          // Extract channels
          int r = pixel.r.toInt();
          int g = pixel.g.toInt();
          int b = pixel.b.toInt();
          int a = pixel.a.toInt();

          // Apply Caesar shift (with wraparound 0–255)
          r = (r + shift) % 256;
          g = (g + shift) % 256;
          b = (b + shift) % 256;

          // Write back shifted pixel
          image.setPixelRgba(x, y, r, g, b, a);
        }
      }

      // Save output
      final suffix = "$shift _encrypted.png";
      final outPath = path.replaceAll(RegExp(r'1\.\w+$'), suffix);
      await File(outPath).writeAsBytes(img.encodePng(image));

      print("✅ Saved: $outPath");
    }
  }

  Future<void> DecryptImages(List<String> imagePaths, int shift) async {
    for (final path in imagePaths) {
      // Load image
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        print("❌ Failed to decode: $path");
        continue;
      }

      final markerPixel = image.getPixel(0, 0);
      final hasMarker = (markerPixel.r == markerR &&
          markerPixel.g == markerG &&
          markerPixel.b == markerB);
      if (hasMarker) {
        print("Encrypted (marker found), decrypting");
      } else {
        print("⚠️ Not encrypted (no marker), skipping: $path");
        continue;
      }

      // Apply Caesar shift on pixels
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          if (x == 0 && y == 0) {
            continue;
          }

          final pixel = image.getPixel(x, y);
          // Extract channels
          int r = pixel.r.toInt();
          int g = pixel.g.toInt();
          int b = pixel.b.toInt();
          int a = pixel.a.toInt();

          // Apply Caesar shift (with wraparound 0–255)
          r = (r - shift) % 256;
          g = (g - shift) % 256;
          b = (b - shift) % 256;

          // Write back shifted pixel
          image.setPixelRgba(x, y, r, g, b, a);
        }
      }

      // Save output
      final suffix = "$shift _decrypted.png";
      final outPath = path.replaceAll(RegExp(r'1\.\w+$_encrypted'), suffix);
      await File(outPath).writeAsBytes(img.encodePng(image));

      print("✅ Saved: $outPath");
    }
  }

  Future<bool> isEncrypted(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      return false;
    }
    final markedPixel = image.getPixel(0, 0);
    final r = markedPixel.r.toInt();
    final g = markedPixel.g.toInt();
    final b = markedPixel.b.toInt();
    if (r == markerR && g == markerG && b == markerB) {
      return true;
    } else if (r == markerR && g == markerG && b == markerB) {
      return false;
    } else {
      throw Exception('Invalid image format');
    }
  }
}

class JumblePixels {
  static const reservedCount = 1;
  // marker for encrypted image
  static const markerRE = 123;
  static const markerGE = 45;
  static const markerBE = 67;
  // marker for decrypted image
  static const markerRD = 98;
  static const markerGD = 15;
  static const markerBD = 76;

  img.Image? _loadImage(String path) {
    final bytes = File(path).readAsBytesSync();
    final image = img.decodeImage(bytes);
    return image;
  }

  int _seedFromKey(String key) {
    final h = crypto.sha256.convert(utf8.encode(key)).bytes;
    final bd = ByteData.sublistView(Uint8List.fromList(h));
    // big-endian uint32 -> deterministic positive seed
    return bd.getUint32(0, Endian.big);
  }

  List<int> _generatePermutation(int n, int seed) {
    final rnd = Random(seed);
    final perm = List<int>.generate(n, (i) => i);
    for (int i = n - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = perm[i];
      perm[i] = perm[j];
      perm[j] = tmp;
    }
    return perm;
  }

  int _packPixel(dynamic pixel) {
    // Convert whatever getPixel returned into a 32-bit ARGB int
    if (pixel is int) return pixel;
    try {
      final r = (pixel.r as num).toInt();
      final g = (pixel.g as num).toInt();
      final b = (pixel.b as num).toInt();
      final a = (pixel.a as num).toInt();
      return ((a & 0xFF) << 24) |
          ((r & 0xFF) << 16) |
          ((g & 0xFF) << 8) |
          (b & 0xFF);
    } catch (e) {
      throw Exception('Unsupported pixel type: ${pixel.runtimeType}');
    }
  }

  List<int> _unpackPixelInt(int val) {
    final a = (val >> 24) & 0xFF;
    final r = (val >> 16) & 0xFF;
    final g = (val >> 8) & 0xFF;
    final b = val & 0xFF;
    return [r, g, b, a]; // order matches setPixelRgba(r,g,b,a)
  }

  Future<void> jumbleImage(
      String inPath, String outPath, String key) async {
    final image = _loadImage(inPath);
    if (image == null) throw Exception('Cannot load image');
    final w = image.width;
    final h = image.height;
    final n = w * h;

    if (n <= reservedCount) {
      throw Exception('Image too small ($n pixels)');
    }
    // Adding marker
    image.setPixelRgba(
        0, 0, markerRE, markerGE, markerBE, 255); // reserve pixel

    // Flatten the image into a list of pixels
    final pixels = List<int>.filled(n, 0);
    int idx = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        pixels[idx++] = _packPixel(image.getPixel(x, y));
      }
    }

    final m = n - reservedCount; // number of indices to permute
    final perm =
        _generatePermutation(m, _seedFromKey(key)); // values in [0..m-1]
    // apply permutation only to indices >= reservedCount
    final shuffled = List<int>.from(pixels);
    for (int j = 0; j < m; j++) {
      final targetIndex = reservedCount + j;
      final sourceIndex = reservedCount + perm[j];
      shuffled[targetIndex] = pixels[sourceIndex];
    }

    // write shuffled pixels back to image
    idx = 0;
    final out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final channels = _unpackPixelInt(shuffled[idx++]);
        out.setPixelRgba(
            x, y, channels[0], channels[1], channels[2], channels[3]);
      }
    }
    await File(outPath).writeAsBytes(img.encodePng(out));
    print('Saved jumbled image: $outPath');
    //return perm;
  }

  Future<void> unjumbleImage(
      String inPath, String outPath, String key) async {
    final image = _loadImage(inPath);
    if (image == null) throw Exception('Cannot load image');
    final w = image.width;
    final h = image.height;
    final n = w * h;

    if (n <= reservedCount) {
      throw Exception('Image too small ($n pixels)');
    }

    final markedPixel = image.getPixel(0, 0);
    final r = markedPixel.r.toInt();
    final g = markedPixel.g.toInt();
    final b = markedPixel.b.toInt();
    if (!(r == markerRE && g == markerGE && b == markerBE)) {
      print("Not an encrypted image");
      return ;
    }
    // Mark as decrypted
    image.setPixelRgba(0, 0, markerRD, markerGD, markerBD, 255);

    // leave input marker in place; output will get decrypted marker later
    final shuffled = List<int>.filled(n, 0);
    int idx = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        shuffled[idx++] = _packPixel(image.getPixel(x, y));
      }
    }
    //print("Shuffled");

    // permutation size must match jumble: only permute indices >= reservedCount
    final m = n - reservedCount;
    final perm = _generatePermutation(m, _seedFromKey(key));
    final orig = List<int>.from(shuffled);
    // recover original pixels: orig[reservedCount + perm[j]] = shuffled[reservedCount + j]
    for (int j = 0; j < m; j++) {
      final targetIndex = reservedCount + perm[j];
      final sourceIndex = reservedCount + j;
      orig[targetIndex] = shuffled[sourceIndex];
    }

    //print("Orig");
    idx = 0;
    final out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final channels = _unpackPixelInt(orig[idx++]);
        out.setPixelRgba(
            x, y, channels[0], channels[1], channels[2], channels[3]);
      }
    }
    await File(outPath).writeAsBytes(img.encodePng(out));
    print('Saved unjumbled image: $outPath');
    //return perm;
  }

  Future<bool> isJumbled(File image) async {
    final img = _loadImage(image.path);
    if (!await image.exists()) {
      throw Exception("File does not exist: $image");
    }
    if (img == null) throw Exception('Cannot load image');
    final markedPixel = img.getPixel(0, 0);
    final r = markedPixel.r.toInt();
    final g = markedPixel.g.toInt();
    final b = markedPixel.b.toInt();
    if (r == markerRE && g == markerGE && b == markerBE) {
      return true;
    }
    return false;
  }
}

// void main() async {
//   JumblePixels jumbler = JumblePixels();
//   String key = "secret";
//   String inPath = "/Users/shashvatgarg/Desktop/Test/1.jpg";
//   String outPath = "/Users/shashvatgarg/Desktop/Test/1_jumbled.png";
//   String outPath2 = "/Users/shashvatgarg/Desktop/Test/1_unjumbled.png";
//   List<int> perme = await jumbler.jumbleImage(inPath, outPath, key);
//   List<int> permd = await jumbler.unjumbleImage(outPath, outPath2, key);
//   for (int i = 0; i < perme.length; i++) {
//     if (perme[i] != permd[i]) {
//       print("Mismatch at index $i: ${perme[i]} != ${permd[i]}");
//       return;
//     }
//   }
// }
