import 'dart:io';

import 'package:flutter/material.dart';
import 'package:obscura/Components/FolderRecord.dart';
import 'package:obscura/Components/PasswordField.dart';
import 'package:obscura/Components/folderTile.dart';
import 'package:obscura/Database/dbHelper.dart';
import 'package:obscura/Encryption/CryptoUtils.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';

class ManageFoldersPage extends StatefulWidget {
  //final Future<void> Function()? delete;

  const ManageFoldersPage({
    super.key,
    //required this.delete,
  });

  @override
  State<ManageFoldersPage> createState() => _ManageFoldersPageState();
}

class _ManageFoldersPageState extends State<ManageFoldersPage> {
  final DatabaseHelper _db = DatabaseHelper();
  List<FolderRecord> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    final rows = await _db.getAllRecords();
    final list = <FolderRecord>[];
    for (final r in rows) {
      list.add(FolderRecord(
        folderPath: r['folderPath'] as String? ?? '',
        bookmark: r['bookmark'] as String? ?? '',
        key: r['key'] as String? ?? '',
        passwordHash: r['password'] as String? ?? '',
        encType: (r['encType'] is int) ? r['encType'] as int : 1,
      ));
    }
    setState(() {
      _folders = list;
      _loading = false;
    });
  }

  Future<String> _resolveDisplayPath(FolderRecord rec) async {
    if (Platform.isMacOS && rec.bookmark.isNotEmpty) {
      try {
        final resolved = await SecureBookmarks().resolveBookmark(rec.bookmark);
        return resolved.path;
      } catch (_) {
        return rec.folderPath;
      }
    }
    return rec.folderPath;
  }

  Future<void> _editFolder(FolderRecord rec) async {
    final pwdCtrl = TextEditingController();
    final showCurrentHash = rec.passwordHash.isNotEmpty;
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: showCurrentHash ? Text('Edit Password') : Text('Set Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<String>(
                future: _resolveDisplayPath(rec),
                builder: (context, snap) {
                  final p = snap.data ?? rec.folderPath;
                  return Text(p,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis);
                },
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: pwdCtrl,
                label: 'Password (leave blank to remove)', 
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newPwd = pwdCtrl.text;
              final storedPwd =
                  newPwd.isEmpty ? '' : hashPasswordToStore(newPwd);
              // Save by reusing saveFolder as upsert (delete+insert fallback if needed)
              await _db.deleteRecordByFilePath(rec.folderPath);
              await _db.saveFolder(
                rec.bookmark,
                folderPath: rec.folderPath,
                key: rec.key, // keep existing key unchanged
                password: storedPwd,
                encType: rec.encType,
              );
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (res == true) {
      await _refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Folder updated')));
    }
  }

  Future<void> _confirmDelete(FolderRecord rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete folder'),
        content: Text(
            'Delete folder "${rec.folderPath.split(Platform.pathSeparator).last}" from imported list? This will not delete files on disk.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteRecordByFilePath(rec.folderPath);
      await _refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Folder removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Imported Folders')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cross = (MediaQuery.of(context).size.width / 300).floor().clamp(1, 4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Imported Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _folders.isEmpty
            ? const Center(child: Text('No imported folders'))
            : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.6,
                ),
                itemCount: _folders.length,
                itemBuilder: (context, i) {
                  final rec = _folders[i];
                  return FolderTile(
                    record: rec,
                    onEdit: () => _editFolder(rec),
                    onDelete: () => _confirmDelete(rec),
                    resolveDisplayPath: _resolveDisplayPath,
                  );
                },
              ),
      ),
    );
  }
}


