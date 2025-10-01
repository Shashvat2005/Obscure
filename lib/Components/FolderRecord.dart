class FolderRecord {
  final String folderPath;
  final String bookmark;
  final String key;
  final String passwordHash;
  final int encType;

  FolderRecord({
    required this.folderPath,
    required this.bookmark,
    required this.key,
    required this.passwordHash,
    required this.encType,
  });
}