import 'dart:io';
import 'package:flutter/material.dart';

// Add these constants for encryption types
const List<String> encryptionTypes = ['Password', 'Caesar', 'Jumble'];
String defaultEncType = encryptionTypes[0];
String defaultKey = '';

// Encryption Setup Dialog Widget
class EncryptionSetupDialog extends StatefulWidget {
  @override
  _EncryptionSetupDialogState createState() => _EncryptionSetupDialogState();
}

class _EncryptionSetupDialogState extends State<EncryptionSetupDialog> {
  String _selectedEncType = defaultEncType;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _caesarController = TextEditingController(text: '3');
  final TextEditingController _jumbleController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _caesarController.dispose();
    _jumbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Encryption Setup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select encryption type:'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedEncType,
              items: encryptionTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedEncType = newValue!;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildEncryptionFields(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final key = _getEncryptionKey();
            if (_validateInput(key)) {
              Navigator.of(context).pop({
                'encType': _selectedEncType,
                'key': key,
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please provide valid encryption parameters'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildEncryptionFields() {
    switch (_selectedEncType) {
      case 'Password':
        return TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        );
      case 'Caesar':
        return TextField(
          controller: _caesarController,
          decoration: const InputDecoration(
            labelText: 'Shift Value (1-25)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );
      case 'Jumble':
        return TextField(
          controller: _jumbleController,
          decoration: const InputDecoration(
            labelText: 'Jumble Key',
            border: OutlineInputBorder(),
          ),
        );
      default:
        return Container();
    }
  }

  String _getEncryptionKey() {
    switch (_selectedEncType) {
      case 'Password':
        return _passwordController.text;
      case 'Caesar':
        return _caesarController.text;
      case 'Jumble':
        return _jumbleController.text;
      default:
        return '';
    }
  }

  bool _validateInput(String key) {
    if (key.isEmpty) return false;
    
    if (_selectedEncType == 'Caesar') {
      final shift = int.tryParse(key);
      return shift != null && shift >= 1 && shift <= 25;
    }
    
    return true;
  }
}

// Update your db.saveFolder method to handle the new parameters
// This is just a placeholder - you'll need to implement based on your database structure
class DBHelper {
  Future<void> saveFolder(String bookmark, 
                         {required String folderPath, 
                          required String key, 
                          required String encType}) async {
    // Implement your database saving logic here
    print('Saving to DB: $folderPath with encType=$encType, key=$key');
  }
}

// Placeholder for SecureBookmarks class
class SecureBookmarks {
  Future<String> bookmark(Directory directory) async {
    // Implement secure bookmarking for macOS
    return directory.path; // Simplified for example
  }
}