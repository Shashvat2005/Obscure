import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obscura/Encryption/CryptoUtils.dart';

class FullscreenImageGallery extends StatefulWidget {
  final List<File> images;
  final int startIndex;
  final bool encrypted;
  final String keyString;
  final int cacheSize;

  const FullscreenImageGallery({
    super.key,
    required this.images,
    required this.startIndex,
    required this.encrypted,
    required this.keyString,
    this.cacheSize = 10,
  });

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late int index;
  final Map<int, Uint8List> cache = {}; // index -> bytes
  final Set<int> loading = {};
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    index = widget.startIndex.clamp(0, max(0, widget.images.length - 1));
    _preloadAround(index);
    // request keyboard focus to capture arrow keys
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    cache.clear();
    super.dispose();
  }

  Future<Uint8List> _loadBytesForIndex(int i) async {
    if (cache.containsKey(i)) return cache[i]!;
    if (loading.contains(i)) {
      // wait until loaded
      while (loading.contains(i)) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return cache[i]!;
    }
    loading.add(i);
    try {
      final path = widget.images[i].path;
      Uint8List bytes;
      if (widget.encrypted) {
        // compute wrapper already exists in CryptoUtils.dart
        bytes = await compute(
            unjumbleToMemoryWrapper, {'in': path, 'key': widget.keyString});
      } else {
        bytes = await File(path).readAsBytes();
      }
      cache[i] = bytes;
      _trimCacheIfNeeded();
      return bytes;
    } finally {
      loading.remove(i);
    }
  }

  void _trimCacheIfNeeded() {
    final maxEntries = widget.cacheSize;
    if (cache.length <= maxEntries) return;
    // keep nearest indices to current index
    final keys = cache.keys.toList();
    keys.sort((a, b) => (a - index).abs().compareTo((b - index).abs()));
    final keep = keys.take(maxEntries).toSet();
    final remove = cache.keys.where((k) => !keep.contains(k)).toList();
    for (final r in remove) cache.remove(r);
  }

  void _preloadAround(int center) {
    final n = widget.images.length;
    if (n == 0) return;
    final half = (widget.cacheSize / 2).floor();
    final start = max(0, center - half);
    final end = min(n - 1, center + (widget.cacheSize - 1 - half));
    for (int i = start; i <= end; i++) {
      _loadBytesForIndex(i);
    }
  }

  void _goTo(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.images.length) return;
    setState(() => index = newIndex);
    _preloadAround(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No images')),
        body: const Center(child: Text('No images to display')),
      );
    }
    final file = widget.images[index];
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${file.path.split(Platform.pathSeparator).last} (${index + 1}/${widget.images.length})'),
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop()),
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (ev) {
          if (ev is RawKeyDownEvent) {
            if (ev.logicalKey == LogicalKeyboardKey.arrowLeft) _goTo(index - 1);
            if (ev.logicalKey == LogicalKeyboardKey.arrowRight)
              _goTo(index + 1);
          }
        },
        child: Stack(
          children: [
            Center(
              child: FutureBuilder<Uint8List>(
                future: _loadBytesForIndex(index),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                        height: 80,
                        width: 80,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading image: ${snap.error}'),
                    );
                  }
                  final bytes = snap.data!;
                  return InteractiveViewer(
                    maxScale: 8,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  );
                },
              ),
            ),
            // Left / Right buttons
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  iconSize: 48,
                  color: Colors.white70,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: index > 0 ? () => _goTo(index - 1) : null,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  iconSize: 48,
                  color: Colors.white70,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: index < widget.images.length - 1
                      ? () => _goTo(index + 1)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
