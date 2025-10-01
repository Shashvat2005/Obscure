import 'dart:io';

import 'package:flutter/material.dart';
import 'package:obscura/Components/FolderRecord.dart';

class FolderTile extends StatelessWidget {
  final FolderRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<String> Function(FolderRecord) resolveDisplayPath;

  const FolderTile({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.resolveDisplayPath,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: resolveDisplayPath(record),
      builder: (context, snap) {
        final display = snap.data ?? record.folderPath;
        final name = display.split(Platform.pathSeparator).last;
        final subtitle = display;

        return AspectRatio(
          aspectRatio: 1, 
          child: Card(
            margin: const EdgeInsets.all(6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 36, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: onDelete,
                      tooltip: 'Remove',
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
