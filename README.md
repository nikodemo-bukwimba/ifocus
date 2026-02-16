# iFocus - 1000-Day Transformation Tracker

A comprehensive Flutter application designed to help users track their 1000-day personal transformation journey through structured daily tasks, focus sessions, weekly planning, and detailed progress analytics.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Running the Application](#running-the-application)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

iFocus is a productivity tracking application that implements a phase-based goal system across 1000 days. The application helps users maintain focus, track daily progress, and achieve long-term objectives through structured planning and accountability mechanisms.

## Features

- Daily task tracking with phase-based goal progression
- Pomodoro timer integration for focused work sessions
- Focus Mode with social media blocking capabilities
- Weekly planning system with goal categorization
- Progress analytics and visualization
- Cloud backup integration with Google Drive
- Local data persistence and backup management
- PDF export functionality for progress reports
- Customizable notifications and reminders

## Prerequisites

Before setting up the project, ensure you have the following installed on your development machine:

### Required Software

1. **Flutter SDK** (version 3.0.0 or higher)
   - Download from: https://docs.flutter.dev/get-started/install
   - Verify installation: `flutter --version`

2. **Dart SDK** (included with Flutter)
   - Verify installation: `dart --version`

3. **Git**
   - Download from: https://git-scm.com/downloads
   - Verify installation: `git --version`

4. **IDE** (choose one):
   - **Android Studio** (recommended for full Flutter support)
     - Download from: https://developer.android.com/studio
     - Install Flutter and Dart plugins
   - **Visual Studio Code**
     - Download from: https://code.visualstudio.com/
     - Install Flutter and Dart extensions

### Platform-Specific Requirements

#### Windows
- Operating System: Windows 10 or later (64-bit)
- Visual Studio 2022 with "Desktop development with C++" workload
- Windows PowerShell 5.0 or later

#### macOS
- Operating System: macOS 10.14 (Mojave) or later
- Xcode 13 or later (for iOS development)
- CocoaPods (install via: `sudo gem install cocoapods`)

#### Linux
- Operating System: Ubuntu 20.04 LTS or later (64-bit)
- Required libraries:
```bash
  sudo apt-get install libgtk-3-dev libblkid-dev liblzma-dev
```

## Installation

Follow these steps to set up the project on your local machine:

### Step 1: Clone the Repository
```bash
git clone https://github.com/yourusername/ifocus.git
cd ifocus
```

### Step 2: Verify Flutter Installation

Ensure Flutter is properly installed and configured:
```bash
flutter doctor
```

Address any issues reported by `flutter doctor` before proceeding. Common issues include:
- Missing Android SDK
- Unaccepted Android licenses
- Missing Xcode (macOS only)

### Step 3: Install Dependencies

Install all required Flutter packages:
```bash
flutter pub get
```

This command installs the following key dependencies:
- `flutter_local_notifications` - Local notification support
- `fl_chart` - Data visualization and charting
- `pdf` - PDF document generation
- `http` - HTTP client for API requests
- `path_provider` - File system path access
- `intl` - Internationalization support
- `url_launcher` - URL and external app launching

### Step 4: Verify Installation

Confirm that all dependencies are correctly installed:
```bash
flutter pub deps
```

## Running the Application

### Desktop Platforms

#### Windows
```bash
flutter run -d windows
```

#### macOS
```bash
flutter run -d macos
```

#### Linux
```bash
flutter run -d linux
```

### Mobile Platforms

#### Android
1. Connect an Android device via USB with USB debugging enabled, or start an Android emulator
2. Verify device connection:
```bash
   flutter devices
```
3. Run the application:
```bash
   flutter run
```

#### iOS (macOS only)
1. Connect an iOS device via USB, or start an iOS simulator
2. Verify device connection:
```bash
   flutter devices
```
3. Run the application:
```bash
   flutter run
```

### Development Mode Options

Run with specific features:
```bash
# Run in debug mode with hot reload
flutter run

# Run in profile mode for performance testing
flutter run --profile

# Run in release mode
flutter run --release

# Run on a specific device
flutter run -d 
```

## Configuration

### Google Drive Cloud Backup (Optional)

To enable cloud backup functionality:

1. **Create Google Cloud Project**
   - Navigate to https://console.cloud.google.com/
   - Create a new project
   - Enable Google Drive API

2. **Configure OAuth 2.0 Credentials**
   - Go to "Credentials" section
   - Create OAuth 2.0 Client ID
   - Select "Desktop app" as application type
   - Download credentials

3. **Create Configuration File**
   
   Create a `config.json` file at the following location:
   
   - **Windows**: `%USERPROFILE%\AppData\Local\iFocus\config.json`
   - **macOS**: `~/Library/Application Support/iFocus/config.json`
   - **Linux**: `~/.local/share/iFocus/config.json`

4. **Add Credentials**
```json
   {
     "google_client_id": "YOUR_CLIENT_ID_HERE.apps.googleusercontent.com",
     "google_client_secret": "YOUR_CLIENT_SECRET_HERE"
   }
```

### Data Storage

The application stores user data in the following locations:

- **Windows**: `%USERPROFILE%\Documents\iFocus\`
- **macOS**: `~/Documents/iFocus/`
- **Linux**: `~/Documents/iFocus/`

Data files include:
- `user_data.json` - Main application data
- `backup_*.json` - Automatic backup files

## Project Structure
```
ifocus/
├── lib/
│   └── main.dart                 # Main application entry point
├── assets/                       # Application assets (if any)
├── test/                        # Unit and widget tests
├── android/                     # Android-specific configuration
├── ios/                         # iOS-specific configuration
├── windows/                     # Windows-specific configuration
├── macos/                       # macOS-specific configuration
├── linux/                       # Linux-specific configuration
├── pubspec.yaml                 # Project dependencies
└── README.md                    # Project documentation
```

### Key Components

- **TrackerHomePage**: Main application interface
- **Task**: Task data model with scheduling and notification support
- **WeeklyPlan/DayPlan**: Weekly planning structure
- **GoalGroup**: Goal categorization system

## Development

### Running Tests

Execute all unit and widget tests:
```bash
flutter test
```

Generate test coverage report:
```bash
flutter test --coverage
```

### Code Analysis

Run static analysis to identify potential issues:
```bash
flutter analyze
```

### Building for Production

#### Windows
```bash
flutter build windows --release
```
Output: `build\windows\runner\Release\`

#### macOS
```bash
flutter build macos --release
```
Output: `build/macos/Build/Products/Release/`

#### Linux
```bash
flutter build linux --release
```
Output: `build/linux/x64/release/bundle/`

#### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

#### Android App Bundle
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

#### iOS
```bash
flutter build ios --release
```

### Code Formatting

Format all Dart files according to Flutter style guidelines:
```bash
flutter format .
```

## Troubleshooting

### Common Issues and Solutions

**Issue: "Unable to locate Android SDK"**
- Solution: Set the `ANDROID_HOME` environment variable to your Android SDK location
- Run `flutter doctor --android-licenses` to accept licenses

**Issue: "CocoaPods not installed" (macOS)**
- Solution: Install CocoaPods using `sudo gem install cocoapods`
- Run `pod setup` after installation

**Issue: "Gradle build failed" (Android)**
- Solution: Check your internet connection for dependency downloads
- Clear Gradle cache: `cd android && ./gradlew clean`

**Issue: "Flutter command not found"**
- Solution: Add Flutter to your PATH environment variable
- Verify with `flutter doctor`

**Issue: Google Drive sync fails**
- Solution: Verify `config.json` file exists and contains correct credentials
- Check Google Cloud Console for API quota limits

**Issue: Focus Mode doesn't block applications**
- Solution: Run the application with administrator privileges
- Windows: Right-click executable and select "Run as administrator"
- macOS/Linux: Run with `sudo` (not recommended for development)

**Issue: Notifications not appearing**
- Solution: Grant notification permissions in system settings
- Windows: Check Windows notification settings
- macOS: System Preferences > Notifications
- Linux: Verify notification daemon is running

**Issue: Hot reload not working**
- Solution: Stop the app and run `flutter clean`, then `flutter run` again
- Check for syntax errors that prevent hot reload

### Getting Additional Help

- Review Flutter documentation: https://docs.flutter.dev/
- Check Flutter GitHub issues: https://github.com/flutter/flutter/issues
- Visit Flutter community channels: https://flutter.dev/community
- Open an issue in this repository with detailed error messages

## Contributing

Contributions to iFocus are welcome and appreciated. To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature-name`)
3. Make your changes following the project's coding standards
4. Write or update tests as necessary
5. Commit your changes with clear, descriptive messages
6. Push to your fork (`git push origin feature/your-feature-name`)
7. Open a Pull Request with a detailed description of changes

### Contribution Guidelines

- Follow Flutter and Dart style guidelines
- Ensure all tests pass before submitting PR
- Update documentation for new features
- Keep commits focused and atomic
- Write clear commit messages

## License

This project is licensed under the MIT License. See the LICENSE file for complete details.

## Acknowledgments

This project utilizes the following open-source packages and tools:
- Flutter framework by Google
- Various Flutter community packages listed in `pubspec.yaml`

For questions or support, please open an issue in the GitHub repository.