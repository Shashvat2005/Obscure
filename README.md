# 🛡️ Obscura – Secure Encrypted Gallery

Obscura is a cross-platform desktop application (macOS & Windows) built with **Flutter** that allows you to securely store, encrypt, and manage your image folders.  
It combines powerful encryption with a simple and intuitive gallery UI — giving you complete control and privacy over your media.

---

## ✨ Features

### 🔐 Security & Privacy
- End-to-end encryption with multiple supported algorithms (e.g., AES).
- Passwords are **bcrypt hashed** before storage (never saved in plain text).
- Folder-level password protection for enhanced security.
- Decryption occurs **only in memory** (RAM) — never written back to disk in plain text.

### 📂 Folder Management
- Import and manage **multiple folders** simultaneously.
- Each folder can have its own encryption type, key, and password.
- Full **macOS secure bookmark** support for persistent folder access.

### 🖼️ Secure Gallery Mode
- Browse and preview encrypted images securely within the app.
- Supported image formats: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.bmp`, `.heic`.
- Fast and efficient in-memory decryption.

### ⚙️ Settings & Customization
- Built-in settings page to manage global preferences.
- Easily edit folder properties or remove them without affecting original files.
- Configure default encryption methods and security options.

### 💻 Cross-Platform Support
- Works seamlessly on **macOS (`.dmg`)** and **Windows (`.exe`)**.
- Designed to be distributed as a standalone desktop app.

---

## 🛠 Tech Stack

- [Flutter](https://flutter.dev/) – Cross-platform UI framework  
- [Sqflite](https://pub.dev/packages/sqflite) – Local SQLite database  
- [macos_secure_bookmarks](https://pub.dev/packages/macos_secure_bookmarks) – Secure persistent folder access (macOS)  
- [bcrypt](https://pub.dev/packages/bcrypt) – Password hashing  
- [Crypto](https://pub.dev/packages/crypto) – Encryption utilities

---

## 🚀 Getting Started

### 📦 Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>=3.x)
- Dart (comes with Flutter)
- macOS or Windows development environment

---

### 🔧 Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/obscura.git
cd obscura
flutter pub get
```

Run in development:
-  macOS
```bash 
flutter run -d macos
```
- Windows
```bash 
flutter run -d windows
```