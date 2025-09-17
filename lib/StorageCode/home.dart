import 'dart:io';
import 'package:flutter/foundation.dart' show compute, Uint8List;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:obscura/Components/fullScreenImg.dart';
import 'package:obscura/Database/dbHelper.dart';
import 'package:obscura/Encryption/CryptoUtils.dart';
import 'package:file_selector/file_selector.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final db = DatabaseHelper();
  final jpe = JumblePixels();

  List<String> folderPaths = [];
  List<String> bookmarkList = [];
  List<String> keys = [];
  List<File> originalImages = [];
  List<File> encryptedImages = [];

  String folderName = "";

  late TabController _tabController;

  int imgCount = 0;
  int orgImages = 0;
  int encImages = 0;

  bool checking = false;

  String currentKey = "";
  String currentBookmark = "";
  String currentPath = "";

  bool isProcessing = false;

  String getRandomString(int length) {
    String chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Multi-select functionality
  bool isSelecting = false;
  Set<File> selectedImages = <File>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Rebuild on tab change to update actions/labels
      setState(() {});
    });
    loadFolder();
    //db.deleteDb();
    //db.deleteAllRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadFolder() async {
    print("loadFolder is called");
    final folders = await db.getAllRecords();
    folderPaths.clear();
    bookmarkList.clear();

    for (final folder in folders) {
      final folderPath = folder['folderPath'] as String;
      final bookmark = folder['bookmark'] as String?;
      final key = folder['key'] as String?;

      String? finalPath = folderPath;

      if (Platform.isMacOS && bookmark != null && bookmark.isNotEmpty) {
        try {
          final resolved = await SecureBookmarks().resolveBookmark(bookmark);

          if (resolved is Uri) {
            finalPath = resolved.path; // get actual usable path
            print("Resolved bookmark → $finalPath");
          } else {
            print("Unexpected type from resolveBookmark: $resolved");
          }
        } catch (e) {
          print("Failed to resolve bookmark for $folderPath: $e");
        }
      }

      // Always add something (either resolved path or fallback)
      folderPaths.add(finalPath!);
      bookmarkList.add(bookmark ?? "");
      keys.add(key ?? "");

      print("Folder added to list: $finalPath");
    }

    setState(() {}); // ensure UI updates
  }

  Future<void> pickFolder() async {
    print("pickFolder is called");
    try {
      final key = getRandomString(10);

      final String? path = await getDirectoryPath();
      if (path == null) return;

      String bookmark = "";

      if (Platform.isMacOS) {
        bookmark = await SecureBookmarks().bookmark(Directory(path));
      }

      if (!folderPaths.contains(path)) {
        setState(() {
          folderPaths.add(path);
          bookmarkList.add(bookmark);
          keys.add(key);
        });

        await db.saveFolder(
          bookmark,
          folderPath: path,
          key: key,
          password: "", // default empty password
          encType: 1,
        );

        print("Folder added: $path, bookmark=$bookmark");
      }

      await loadImagesFromFolder(path, bookmark, key);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting folder: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> deleteFolder(String path) async {
    print("deleteFolder is called");
    await db.deleteRecordByFilePath(path);
    setState(() {
      folderPaths.remove(path);
      encryptedImages = [];
      originalImages = [];
    });
  }

  Future<void> loadImagesFromFolder(
      String path, String bookmark, String key) async {
    print("loadImagesFromFolder is called");
    setState(() {
      currentKey = key;
      checking = true;
      originalImages = [];
      encryptedImages = [];
    });

    try {
      String finalPath = path;
      if (Platform.isMacOS && bookmark.isNotEmpty) {
        try {
          final resolved = await SecureBookmarks().resolveBookmark(bookmark);
          finalPath = resolved.path;
          await SecureBookmarks()
              .startAccessingSecurityScopedResource(resolved);
        } catch (e) {
          finalPath = path;
        }
      }

      final dir = Directory(finalPath);
      if (!await dir.exists()) {
        setState(() {
          originalImages = [];
          encryptedImages = [];
          imgCount = 0;
          checking = false;
        });
        return;
      }

      final exts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'];

      // Offload expensive scanning + decoding to a background isolate
      final Map<String, List<String>> scanned = await compute(
        scanFolderWrapper,
        {'path': finalPath, 'exts': exts},
      );

      // Convert to File lists and update state once
      setState(() {
        encryptedImages =
            (scanned['encrypted'] ?? []).map((p) => File(p)).toList();
        originalImages =
            (scanned['original'] ?? []).map((p) => File(p)).toList();
        imgCount = encryptedImages.length + originalImages.length;
        folderName = finalPath.split(Platform.pathSeparator).last;
        currentPath = finalPath; // mark currently loaded folder
        isSelecting = false;
        selectedImages.clear();
        checking = false;
      });
    } catch (e) {
      setState(() {
        originalImages = [];
        encryptedImages = [];
        imgCount = 0;
        checking = false;
      });
      print("Error loading images: $e");
    }
  }
  
  void toggleSelection(File image) {
    setState(() {
      if (selectedImages.contains(image)) {
        selectedImages.remove(image);
      } else {
        selectedImages.add(image);
      }

      // Exit selection mode if no images are selected
      if (selectedImages.isEmpty) {
        isSelecting = false;
      }
    });
  }

  void selectAllImages() {
    setState(() {
      if (selectedImages.length == originalImages.length) {
        selectedImages.clear();
        isSelecting = false;
      } else {
        selectedImages = Set<File>.from(originalImages);
      }
    });
  }

  void clearSelection() {
    setState(() {
      selectedImages.clear();
      isSelecting = false;
    });
  }

  Future<void> encryptSelectedImages(
      String path, String bookmark, String key) async {
    setState(() {
      isProcessing = true;
    });
    print("encryptSelectedImages is called");
    if (selectedImages.isEmpty) return;

    // Simulate encryption process
    for (var image in selectedImages) {
      if (!encryptedImages.contains(image)) {
        // await jpe.jumbleImage(image.path, image.path, key);
        // await FileImage(File(image.path)).evict();
        await compute(jumbleWrapper, {'in': image.path, 'out': image.path, 'key': key});
        await FileImage(File(image.path)).evict();
        
        print("Encrypted ${image.path.split(Platform.pathSeparator).last}");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Encrypted ${selectedImages.length} image(s)'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(seconds: 2),
      ),
    );

    // Clear selection after encryption
    clearSelection();
    await loadImagesFromFolder(path, bookmark, key);
    setState(() {
      isProcessing = false;
    });
  }

  Future<void> decryptSelectedImages(
      String path, String bookmark, String key) async {
    setState(() {
      isProcessing = true;
    });
    print("decryptSelectedImages is called");
    if (selectedImages.isEmpty) return;

    for (var image in selectedImages) {
      if (!originalImages.contains(image)) {
        // await jpe.unjumbleImage(image.path, image.path, key);
        // await FileImage(File(image.path)).evict();

        await compute(unjumbleWrapper, {'in': image.path, 'out': image.path, 'key': key});
        await FileImage(File(image.path)).evict();
        print("Decrypted ${image.path.split(Platform.pathSeparator).last}");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Decrypted ${selectedImages.length} image(s)'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(seconds: 2),
      ),
    );

    clearSelection();
    await loadImagesFromFolder(path, bookmark, key);
    setState(() {
      isProcessing = false;
    });
  }

  Future<void> showTempDecrypted(File file) async {
    setState(() => isProcessing = true);
    try {
      // call compute wrapper that returns PNG bytes of the unjumbled image
      final Uint8List bytes = await compute(
          unjumbleToMemoryWrapper, {'in': file.path, 'key': currentKey});

      // Show a dialog with the image (keeps it in memory only)
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                child: Text(
                  file.path.split(Platform.pathSeparator).last,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, st) =>
                        const SizedBox(child: Text('Cannot render image')),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: $e')),
      );
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> encryptImage(File originalImage) async {
    print("encryptImage is called");
    // Actually encrypt the image in-place with currentKey
    try {
      jpe.jumbleImage(originalImage.path, originalImage.path, currentKey);
      await loadImagesFromFolder(currentPath, currentBookmark, currentKey);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Encrypted ${originalImage.path.split(Platform.pathSeparator).last}'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Encryption failed: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> decryptImage(File encryptedImage) async {
    print("decryptImage is called");
    // Actually encrypt the image in-place with currentKey
    try {
      jpe.unjumbleImage(encryptedImage.path, encryptedImage.path, currentKey);
      await loadImagesFromFolder(currentPath, currentBookmark, currentKey);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Decrypted ${encryptedImage.path.split(Platform.pathSeparator).last}'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Decryption failed: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onShowImage(File file) {
    final images = _tabController.index == 1 ? encryptedImages : originalImages;
    final start = images.indexWhere((f) => f.path == file.path);
    if (start < 0) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullscreenImageGallery(
        images: images,
        startIndex: start,
        encrypted: (_tabController.index == 1),
        keyString: currentKey,
        cacheSize: 10,
      ),
      fullscreenDialog: true,
    ));
  }

  Widget _buildImageGrid(List<File> imagesToShow, bool checking,
      {bool showEncryptButton = true}) {
    if (imagesToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            checking
                ? CircularProgressIndicator()
                : Icon(
                    Icons.photo_library,
                    size: 64,
                    color: Colors.grey[400],
                  ),
            const SizedBox(height: 16),
            Text(
              checking ? "Loading Images..." : "No images found",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.8,
      ),
      itemCount: imagesToShow.length,
      itemBuilder: (context, index) {
        final file = imagesToShow[index];
        final isSelected = selectedImages.contains(file);

        return _buildImageCard(
          file,
          showEncryptButton,
          isSelected,
          showDecryptButton: !showEncryptButton,
        );
      },
    );
  }

  Widget _buildImageCard(File file, bool showEncryptButton, bool isSelected,
      {bool showDecryptButton = false}) {
    return GestureDetector(
      onLongPress: () {
        if (!isSelecting) {
          setState(() {
            isSelecting = true;
            selectedImages.add(file);
          });
        }
      },
      onTap: () {
        if (isSelecting) {
          toggleSelection(file);
        }
      },
      child: Stack(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: isSelected ? Colors.blue[50] : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (c, e, st) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          if (isSelecting)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 20,
                ),
              ),
            ),
          // Add Show button overlay for encrypted items (only when not selecting)
          if (showDecryptButton && !isSelecting)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    onPressed: () => showTempDecrypted(file),
                    child: const Text('Show', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obscura Gallery'),
        toolbarHeight: 50,
        leading: IconButton(
          onPressed: () async {
            print("Settings button pressed");
            List<Map<String, dynamic>> data = await db.getAllRecords();
            for (var i = 0; i < data.length; i++) {
              print(data[i]);
            }
          },
          icon: Icon(Icons.settings),
        ),
        actions: <Widget>[
          IconButton(
            // Reload Button
            onPressed: () {
              loadImagesFromFolder(currentPath, currentBookmark, currentKey);
            },
            icon: Icon(Icons.replay_rounded),
          ),
        ],
      ),

      body: Stack(
        children: [
          Row(
            children: [
              // LEFT SIDEBAR - Folder List
              Container(
                width: 280,
                // Decoration of Container
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
          
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      //Header
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Folders",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: pickFolder,
                            color: Theme.of(context).colorScheme.primary,
                            tooltip: "Add folder",
                          ),
                        ],
                      ),
                    ),
          
                    const Divider(height: 1),
          
                    const SizedBox(height: 2),
          
                    // Folders List
                    Expanded(
                      child: ListView.builder(
                        itemCount: folderPaths.length,
                        itemBuilder: (context, index) {
                          currentPath = folderPaths[index];
                          final name =
                              currentPath.split(Platform.pathSeparator).last;
                          currentBookmark = bookmarkList[index];
                          final key = keys[index];
                          return ListTile(
                            leading: const Icon(Icons.folder, color: Colors.amber),
                            title: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: folderName == name
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: folderName == name
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[700],
                              ),
                            ),
                            subtitle: Text(
                              currentPath,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_forever_outlined,
                                  size: 20, color: Colors.red),
                              onPressed: () => deleteFolder(currentPath),
                              tooltip: "Delete Path",
                            ),
                            onTap: () => loadImagesFromFolder(
                                currentPath, currentBookmark, key),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          
              // MAIN CONTENT AREA
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      // Folder name and status (finalized)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              (folderName.isEmpty
                                  ? "No folder selected"
                                  : folderName),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                                child: Row(
                              children: [
                                if (folderName.isNotEmpty)
                                  Text(
                                    "(${originalImages.length + encryptedImages.length} images)",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            )),
                            if (!isSelecting)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    isSelecting = true;
                                  });
                                },
                                child: const Text("Select"),
                              ),
                            // Single "Show" button — shows the first image of the current tab
                            if (!isSelecting &&
                                ((_tabController.index == 0 && originalImages.isNotEmpty) ||
                                    (_tabController.index == 1 && encryptedImages.isNotEmpty)))
                              TextButton(
                                onPressed: () {
                                  final images = _tabController.index == 1 ? encryptedImages : originalImages;
                                  if (images.isNotEmpty) _onShowImage(images.first);
                                },
                                child: const Text("Show"),
                              ),
                             if (isSelecting)
                               TextButton(
                                 onPressed: clearSelection,
                                 child: Text("Cancel"),
                               ),
                          ],
                        ),
                      ),
                  
                      // Selection mode info bar (finalized)
                      if (isSelecting)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.blue[50],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                _tabController.index == 0
                                    ? "Select images to encrypt (${selectedImages.length} selected)"
                                    : "Select images to decrypt (${selectedImages.length} selected)",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                  
                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        // child: TabBar(
                        //   controller: _tabController,
                        //   labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                        //   tabs: [
                        //     Tab(text: "Original Images"),
                        //     Tab(text: "Encrypted Images"),
                        //   ],
                        // ),
                        child: IgnorePointer(
                          ignoring: isSelecting,
                          child: TabBar(
                            controller: _tabController,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                            tabs: [
                              Tab(text: "Original Images"),
                              Tab(text: "Encrypted Images"),
                            ],
                          ),
                        ),
                      ),
                  
                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: isSelecting
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          children: [
                            // Original Images Tab
                            _buildImageGrid(
                              originalImages,
                              checking,
                              showEncryptButton: true,
                            ),
                  
                            // Encrypted Images Tab
                            _buildImageGrid(
                              encryptedImages,
                              checking,
                              showEncryptButton: false,
                            ),
                          ],
                        ),
                      ),
                      
                    ],
                  ),
                ),
              ),
            ],
          ),
        
          if (isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Processing...", 
                      style: TextStyle(color: Colors.white, fontSize: 18)
                    ),
                    SizedBox(height: 16),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
        
        ],
      ),
      // Bottom action button when in selection mode

      floatingActionButton: isSelecting && selectedImages.isNotEmpty
          ? (_tabController.index == 0
              ? FloatingActionButton.extended(
                  onPressed: () => encryptSelectedImages(
                      currentPath, currentBookmark, currentKey),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  icon: const Icon(Icons.lock),
                  label: Text('Encrypt ${selectedImages.length} image(s)'),
                )
              : FloatingActionButton.extended(
                  onPressed: () => decryptSelectedImages(
                      currentPath, currentBookmark, currentKey),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  icon: const Icon(Icons.lock_open),
                  label: Text('Decrypt ${selectedImages.length} image(s)'),
                ))
          : null,
    );
  }
}
