<h1 align="center">
  Secure Chat 💬
</h1>

<p align="center">
  <strong>A Zero-Knowledge, End-to-End Encrypted Chat Application with Secure UI and Immutable Backup.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite" />
</p>

---

## 🌟 Overview

**Secure Chat** is designed from the ground up to guarantee absolute privacy. Engineered with a **Zero-Knowledge** architecture, your data remains yours. No one—not even the server—can read your messages. With seamless **End-to-End Encryption (E2EE)**, a heavily fortified **Secure UI**, and an **Immutable Backup** mechanism, Secure Chat provides uncompromised security without sacrificing the user experience.

---

## ✨ Key Features

- **🔐 Zero-Knowledge End-to-End Encryption**: Messages are encrypted on your device and can only be decrypted by the intended recipient. The server never sees your plaintext.
- **🛡️ Secure UI**: Built-in protections to prevent screenshotting, screen recording, and unauthorized data leakage on compatible devices.
- **☁️ Immutable Backups**: Encrypted data is safely backed up to the cloud remotely configured in a way that prevents malicious overwriting, ensuring message history integrity.
- **⚡ Supercharged by Supabase**: Powered by modern WebSockets for instant, real-time message delivery.
- **📱 Fluid Cross-Platform Experience**: A native-feeling iOS and Android experience beautifully built with Flutter.
- **🗄️ Instant Local Caching**: Sqflite integration ensures your chats load immediately, whether you're offline or online.

---

## 🛠️ Technology Stack

| Component | Technology | Description |
|-----------|------------|-------------|
| **Frontend Platform** | [Flutter](https://flutter.dev/) | Cross-platform UI toolkit enabling beautiful, responsive applications. |
| **Language** | [Dart](https://dart.dev/) | Client-optimized language for fast apps on any platform. |
| **Backend & Backend Auth**| [Supabase](https://supabase.com/) | Open source Firebase alternative providing PostgreSQL, Auth, and Realtime. |
| **Local Database** | [Sqflite](https://pub.dev/packages/sqflite) | SQLite plugin for fast, reliable local data caching. |

---

## 🚀 Getting Started

Follow these steps to get the project up and running on your local machine.

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.4 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- A [Supabase](https://supabase.com/) Project instance

### Installation Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/secure_chat.git
   cd secure_chat
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   - Connect your configuration files or placeholders for Supabase.
   - Example configuration inputs:
     ```env
     SUPABASE_URL=your_supabase_project_url
     SUPABASE_ANON_KEY=your_supabase_anon_key
     ```

4. **Run the Application:**
   ```bash
   flutter run
   ```

---

## 🏗️ Architecture Design

1. **Local Key Generation:** 
   Cryptographic keys are generated entirely locally and stored safely on the device.
2. **Cipher Pipeline:** 
   Outgoing messages are encrypted locally using standard algorithms before they traverse the network.
3. **Storage & Sync:** 
   Fully encrypted payloads are pushed to Supabase. Sqflite simultaneously maintains a locally cached snapshot for swift load times.

---

## 📝 License

This project is open-sourced and licensed under the MIT License.

---

<p align="center">
  <i>Built with ❤️ using Flutter and Supabase. Keep your secrets safe.</i>
</p>
