import 'package:flutter/material.dart';
import 'package:obscura/manage_folders.dart';
import 'package:obscura/myapp.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EncryptionType { aes128, aes192, aes256 }

enum ThumbnailSize { small, medium, large }

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static const _kDarkMode = 'dark_mode';

  bool _darkMode = false;

  bool _loading = true;
  int _selectedSectionIndex = 0;

  // Section titles
  final List<String> _sectionTitles = [
    'Folder & Gallery',
    'Appearance',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  // load stored preferences (turn off loading when done)
  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = sp.getBool(_kDarkMode) ?? false;
      _loading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  Widget _buildFolderGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Folder & Gallery Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Manage Imported Folders'),
          leading: const Icon(Icons.folder_open),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageFoldersPage())),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Appearance Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Dark Mode'),
          value: _darkMode,
          onChanged: (v) async {
            setState(() => _darkMode = v);
            await _saveBool(_kDarkMode, v);
            await setDarkModeEnabled(v);
          },
          secondary: const Icon(Icons.dark_mode),
        ),
      ],
    );
  }

  // Build the left navigation pane
  Widget _buildLeftNavigation() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: ListView(
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_sectionTitles.length, (index) {
            return ListTile(
              title: Text(
                _sectionTitles[index],
                style: TextStyle(
                  fontWeight: _selectedSectionIndex == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _selectedSectionIndex == index
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[700],
                ),
              ),
              leading: Icon(
                _getSectionIcon(index),
                color: _selectedSectionIndex == index
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
              selected: _selectedSectionIndex == index,
              selectedTileColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
              onTap: () {
                setState(() {
                  _selectedSectionIndex = index;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  // Helper to get icons for each section
  IconData _getSectionIcon(int index) {
    switch (index) {
      case 0: // Folder & Gallery
        return Icons.folder;
      case 1: // Appearance
        return Icons.palette;
      default:
        return Icons.folder;
    }
  }

  // Build the right content pane
  Widget _buildRightContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        alignment: Alignment.topCenter,
        constraints: const BoxConstraints(maxWidth: 800),
        child: _getSectionContent(),
      ),
    );
  }

  // Get the content for the selected section
  Widget _getSectionContent() {
    switch (_selectedSectionIndex) {
      case 0:
        return _buildFolderGallerySection();
      case 1:
        return _buildAppearanceSection();
      default:
        return _buildFolderGallerySection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          _buildLeftNavigation(),
          Expanded(
            child: _buildRightContent(),
          ),
        ],
      ),
    );
  }
}
