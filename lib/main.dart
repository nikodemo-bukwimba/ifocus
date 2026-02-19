import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const initializationSettingsAndroid = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  const initializationSettingsDarwin = DarwinInitializationSettings();
  const initializationSettingsLinux = LinuxInitializationSettings(
    defaultActionName: 'Open',
  );
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const IfocusApp());
}

class IfocusApp extends StatelessWidget {
  const IfocusApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I focus >>> 1000-Days ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        cardColor: const Color(0xFF1A1F3A),
      ),
      home: const TrackerHomePage(),
    );
  }
}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

class Task {
  String id;
  String title;
  String category;
  bool isCompleted;
  DateTime? scheduledTime;
  bool notificationSent;
  String? notes;
  int pomodoroCount;

  Task({
    required this.id,
    required this.title,
    required this.category,
    this.isCompleted = false,
    this.scheduledTime,
    this.notificationSent = false,
    this.notes,
    this.pomodoroCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'isCompleted': isCompleted,
    'scheduledTime': scheduledTime?.toIso8601String(),
    'notificationSent': notificationSent,
    'notes': notes,
    'pomodoroCount': pomodoroCount,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    category: json['category'],
    isCompleted: json['isCompleted'] ?? false,
    scheduledTime: json['scheduledTime'] != null
        ? DateTime.parse(json['scheduledTime'])
        : null,
    notificationSent: json['notificationSent'] ?? false,
    notes: json['notes'],
    pomodoroCount: json['pomodoroCount'] ?? 0,
  );
}

// ADD THESE NEW CLASSES to replace the WeeklyPlan class
class WeeklyPlan {
  DateTime weekStart;
  Map<String, DayPlan> dayPlans; // Changed from goals/notes to dayPlans

  WeeklyPlan({required this.weekStart, required this.dayPlans});

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart.toIso8601String(),
    'dayPlans': dayPlans.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) {
    final raw = json['dayPlans'] as Map?;

    final mapped = raw != null
        ? raw.map((k, v) => MapEntry(k.toString(), DayPlan.fromJson(v)))
        : <String, DayPlan>{};

    return WeeklyPlan(
      weekStart: DateTime.parse(json['weekStart']),
      dayPlans: mapped,
    );
  }
}

// NEW: Detailed day plan structure
class DayPlan {
  String dayName;
  String? description;
  List<GoalGroup> goalGroups;
  String? notes;

  DayPlan({
    required this.dayName,
    this.description,
    List<GoalGroup>? goalGroups,
    this.notes,
  }) : goalGroups = goalGroups ?? []; // mutable empty list by default
  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'description': description,
    'goalGroups': goalGroups.map((g) => g.toJson()).toList(),
    'notes': notes,
  };

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
    dayName: json['dayName'],
    description: json['description'],
    goalGroups:
        (json['goalGroups'] as List?)
            ?.map((g) => GoalGroup.fromJson(g))
            .toList() ??
        [],
    notes: json['notes'],
  );
}

class Goal {
  String title;
  bool isCompleted;

  Goal({required this.title, this.isCompleted = false});

  Map<String, dynamic> toJson() => {'title': title, 'isCompleted': isCompleted};

  factory Goal.fromJson(Map<String, dynamic> json) =>
      Goal(title: json['title'], isCompleted: json['isCompleted'] ?? false);
}

class GoalGroup {
  String category;
  String? categoryDescription;
  List<Goal> goals; // make sure this is a class Goal, not just String

  GoalGroup({
    required this.category,
    this.categoryDescription,
    this.goals = const [],
  });

  // Add this method
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'categoryDescription': categoryDescription,
      'goals': goals.map((g) => g.toJson()).toList(),
    };
  }

  // Optional: fromJson
  factory GoalGroup.fromJson(Map<String, dynamic> json) {
    return GoalGroup(
      category: json['category'],
      categoryDescription: json['categoryDescription'],
      goals: (json['goals'] as List<dynamic>)
          .map((g) => Goal.fromJson(g))
          .toList(),
    );
  }
}

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({Key? key}) : super(key: key);

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage> {
  // Core tracking variables
  int currentDay = 1;
  int currentPhase = 1;
  DateTime selectedDate = DateTime.now();
  List<Task> todayTasks = [];
  List<Map<String, dynamic>> dailyLogs = [];

  // Focus mode variables
  bool isFocusMode = false;
  // Process? _firewallProcess;
  Timer? _processMonitoringTimer;

  // Week planning
  WeeklyPlan? currentWeekPlan;
  Map<String, WeeklyPlan> weeklyPlans = {};

  // Pomodoro timer
  Timer? pomodoroTimer;
  int pomodoroMinutesLeft = 25;
  bool isPomodoroRunning = false;
  Task? currentPomodoroTask;

  // Notifications
  Timer? notificationTimer;

  // File-based storage (NEW)
  File? _dataFile;
  Directory? _appDataDir;

  String _clientId = '';
  String _clientSecret = '';

  // Google Drive sync (NEW)
  bool _isSyncEnabled = false;
  DateTime? _lastSyncTime;
  Timer? _autoSyncTimer;
  String? _googleDriveFolderId;
  bool _isGoogleDriveConnected = false;
  String? _googleAccessToken;

  String get _tokenFilePath {
    return path.join(
      Platform.environment['USERPROFILE'] ?? '',
      'AppData/Local/iFocus/.google_token',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadConfigCredentials();
    _initializeDataFile().then((_) {
      _loadData();
      _startNotificationChecker();
      _checkHostsFilePermissions();
      _syncWeeklyGoalsToTasks();
      _syncTasksBackToGoals();
    });
    _syncWeeklyGoalsToTasks();
    _loadSavedToken();
  }

  Future<void> _loadConfigCredentials() async {
    try {
      final configFile = File(
        path.join(
          Platform.environment['USERPROFILE'] ?? '',
          'AppData/Local/iFocus/config.json',
        ),
      );

      if (configFile.existsSync()) {
        final json = jsonDecode(configFile.readAsStringSync());
        _clientId = json['google_client_id'] ?? '';
        _clientSecret = json['google_client_secret'] ?? '';
        print('✅ Loaded credentials from config.json');
      } else {
        // Create default config
        await configFile.parent.create(recursive: true);
        final defaultConfig = {
          'google_client_id': 'YOUR_CLIENT_ID_HERE',
          'google_client_secret': 'YOUR_CLIENT_SECRET_HERE',
        };
        configFile.writeAsStringSync(jsonEncode(defaultConfig));
        print('⚠️ Config file created at: ${configFile.path}');
        print('⚠️ Please edit it with your Google credentials');
      }
    } catch (e) {
      print('❌ Error loading config: $e');
    }
  }

  @override
  void dispose() {
    notificationTimer?.cancel();
    pomodoroTimer?.cancel();
    _processMonitoringTimer?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedToken() async {
    try {
      final tokenFile = File(_tokenFilePath);
      if (tokenFile.existsSync()) {
        final token = tokenFile.readAsStringSync().trim();
        if (token.isNotEmpty) {
          _googleAccessToken = token;
          _isGoogleDriveConnected = true;
          print('✅ Loaded saved Google Drive token');

          // Verify token is still valid and get folder ID
          await _createOrGetGoogleDriveFolder({
            'Authorization': 'Bearer $_googleAccessToken',
          });
        }
      }
    } catch (e) {
      print('⚠️ Could not load saved token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final tokenFile = File(_tokenFilePath);
      await tokenFile.parent.create(recursive: true);
      tokenFile.writeAsStringSync(token);
      print('✅ Token saved');
    } catch (e) {
      print('❌ Could not save token: $e');
    }
  }

  // NEW: Google Drive sync methods
  Future<void> _setupGoogleDriveSync() async {
    try {
      // If already connected, show disconnect option
      if (_isGoogleDriveConnected && _googleAccessToken != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('☁️ Google Drive'),
            content: const Text('Google Drive backup is already enabled'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _disconnectGoogleDrive();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        );
        return;
      }

      // Show setup dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('☁️ Google Drive Remote Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enable cloud backup to Google Drive?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Benefits:'),
              const SizedBox(height: 8),
              Text(
                '✅ Remote cloud backup',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                '✅ Access from any device',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                '✅ Automatic hourly sync',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                '✅ Plus local backup (already enabled)',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🔐 Requires Google account login (one-time setup)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _enableGoogleDriveSync();
              },
              child: const Text('Enable Cloud Backup'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Google Drive setup failed: $e');
    }
  }

  Future<void> _enableGoogleDriveSync() async {
    try {
      final clientId = _clientId;

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
        'response_type': 'code',
        'scope': 'https://www.googleapis.com/auth/drive.file',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      print('Opening browser for Google authentication...');

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);

        // Show dialog for user to paste auth code
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) {
              final codeController = TextEditingController();
              return AlertDialog(
                title: const Text('🔐 Google Drive Authentication'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'A browser window has opened.\n\n'
                      '1. Sign in with your Google account\n'
                      '2. Grant permission\n'
                      '3. Copy the authorization code\n'
                      '4. Paste it below',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        hintText: 'Paste authorization code here',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final code = codeController.text;
                      Navigator.pop(context);
                      if (code.isNotEmpty) {
                        await _exchangeCodeForToken(code);
                      }
                    },
                    child: const Text('Authenticate'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      print('❌ Google Drive auth failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Auth failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _exchangeCodeForToken(String code) async {
    try {
      final clientId = _clientId;
      final clientSecret = _clientSecret;

      final tokenUrl = Uri.https('oauth2.googleapis.com', '/token');

      final response = await http.post(
        tokenUrl,
        body: {
          'code': code,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _googleAccessToken = data['access_token'];

        // Save token for next time
        await _saveToken(_googleAccessToken!);

        await _setupWithToken();
      } else {
        print('❌ Token exchange failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Exchange failed: $e');
    }
  }

  Future<void> _setupWithToken() async {
    try {
      if (_googleAccessToken == null) return;

      final headers = {'Authorization': 'Bearer $_googleAccessToken'};

      // Create or get iFocus_Backups folder
      await _createOrGetGoogleDriveFolder(headers);

      _isGoogleDriveConnected = true;

      setState(() {
        _isSyncEnabled = true;
      });

      // Start auto-sync timer
      _autoSyncTimer?.cancel();
      _autoSyncTimer = Timer.periodic(const Duration(hours: 1), (timer) {
        _syncToGoogleDrive();
      });

      // Initial sync
      await _syncToGoogleDrive();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cloud backup enabled!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Setup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Setup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createOrGetGoogleDriveFolder(
    Map<String, String> headers,
  ) async {
    try {
      // Search for existing iFocus_Backups folder
      final query = Uri.encodeComponent(
        "name='iFocus_Backups' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      );
      final searchUrl = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$query&spaces=drive&pageSize=1',
      );

      final response = await http.get(searchUrl, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = data['files'] as List;

        if (files.isNotEmpty) {
          _googleDriveFolderId = files[0]['id'];
          print('✅ Found existing folder: $_googleDriveFolderId');
        } else {
          // Create new folder
          await _createGoogleDriveFolder(headers);
        }
      }
    } catch (e) {
      print('❌ Error creating/getting folder: $e');
    }
  }

  Future<void> _createGoogleDriveFolder(Map<String, String> headers) async {
    try {
      final url = Uri.parse('https://www.googleapis.com/drive/v3/files');
      final body = {
        'name': 'iFocus_Backups',
        'mimeType': 'application/vnd.google-apps.folder',
      };

      final response = await http.post(
        url,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _googleDriveFolderId = data['id'];
        print('✅ Created folder: $_googleDriveFolderId');
      }
    } catch (e) {
      print('❌ Error creating folder: $e');
    }
  }

  Future<void> _syncToGoogleDrive() async {
    try {
      if (!_isSyncEnabled || !_isGoogleDriveConnected || _dataFile == null)
        return;
      if (_googleAccessToken == null) return;

      final headers = {'Authorization': 'Bearer $_googleAccessToken'};

      // Upload file to Google Drive
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'ifocus_backup_$timestamp.json';

      await _uploadToGoogleDrive(fileName, headers);

      // Clean up old backups
      await _cleanupOldGoogleDriveBackups(headers);

      setState(() {
        _lastSyncTime = DateTime.now();
      });

      print(
        '☁️ Synced to Google Drive at ${DateFormat('HH:mm').format(_lastSyncTime!)}',
      );
    } catch (e) {
      print('❌ Google Drive sync failed: $e');
    }
  }

  Future<void> _uploadToGoogleDrive(
    String fileName,
    Map<String, String> headers,
  ) async {
    try {
      if (_googleDriveFolderId == null || _dataFile == null) return;

      final url = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      );

      final fileContent = await _dataFile!.readAsBytes();
      final metadata = {
        'name': fileName,
        'parents': [_googleDriveFolderId],
      };

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      request.fields['metadata'] = jsonEncode(metadata);
      request.files.add(
        http.MultipartFile.fromBytes('file', fileContent, filename: fileName),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        print('✅ File uploaded: $fileName');
      } else {
        print('❌ Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
    }
  }

  Future<void> _cleanupOldGoogleDriveBackups(
    Map<String, String> headers,
  ) async {
    try {
      if (_googleDriveFolderId == null) return;

      // List files in folder
      final query = Uri.encodeComponent(
        "'$_googleDriveFolderId' in parents and trashed=false",
      );
      final url = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$query&orderBy=createdTime%20desc&pageSize=50',
      );

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = data['files'] as List;

        // Delete files older than 10th
        for (var i = 10; i < files.length; i++) {
          final fileId = files[i]['id'];
          await _deleteGoogleDriveFile(fileId, headers);
        }
      }
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  }

  Future<void> _deleteGoogleDriveFile(
    String fileId,
    Map<String, String> headers,
  ) async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/drive/v3/files/$fileId',
      );
      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 204) {
        print('🗑️ Deleted old backup: $fileId');
      }
    } catch (e) {
      print('❌ Delete error: $e');
    }
  }

  Future<void> _disconnectGoogleDrive() async {
    try {
      final tokenFile = File(_tokenFilePath);
      if (tokenFile.existsSync()) {
        tokenFile.deleteSync();
      }
      _googleAccessToken = null;
      _googleDriveFolderId = null;
      _isGoogleDriveConnected = false;
      _isSyncEnabled = false;
      _autoSyncTimer?.cancel();

      setState(() {});

      print('✅ Disconnected from Google Drive');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Google Drive disconnected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Disconnect error: $e');
    }
  }

  // NEW: Restore from Google Drive
  Future<void> _restoreFromGoogleDrive() async {
    try {
      final googleDrivePath = path.join(
        Platform.environment['USERPROFILE'] ?? '',
        'Google Drive',
        'iFocus_Backups',
      );

      final syncDir = Directory(googleDrivePath);

      if (!await syncDir.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No Google Drive backups found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final syncedFiles =
          syncDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.contains('ifocus_sync_'))
              .toList()
            ..sort((a, b) => b.path.compareTo(a.path));

      if (syncedFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No sync files found in Google Drive'),
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('☁️ Restore from Google Drive'),
          content: SizedBox(
            width: 450,
            height: 400,
            child: ListView.builder(
              itemCount: syncedFiles.length,
              itemBuilder: (context, index) {
                final file = syncedFiles[index];
                final filename = path.basename(file.path);
                final stat = file.statSync();
                final modified = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(stat.modified);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.cloud_download,
                      color: Colors.blue,
                    ),
                    title: Text(
                      filename,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Synced: $modified\nSize: ${(stat.size / 1024).toStringAsFixed(2)} KB',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.restore),
                    onTap: () async {
                      await _performRestore(file);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Google Drive restore failed: $e');
    }
  }

  // NEW: Initialize persistent data file
  Future<void> _initializeDataFile() async {
    try {
      // Use Documents folder (survives uninstall/reinstall)
      final documentsDir = await getApplicationDocumentsDirectory();
      _appDataDir = Directory(path.join(documentsDir.path, 'iFocus'));

      // Create iFocus folder if doesn't exist
      if (!await _appDataDir!.exists()) {
        await _appDataDir!.create(recursive: true);
        print('📁 Created iFocus data folder: ${_appDataDir!.path}');
      }

      // Data file location
      _dataFile = File(path.join(_appDataDir!.path, 'user_data.json'));

      if (!await _dataFile!.exists()) {
        // Create initial data file
        await _dataFile!.writeAsString(
          json.encode({
            'version': 1,
            'currentDay': 1,
            'currentPhase': 1,
            'selectedDate': DateTime.now().toIso8601String(),
            'dailyLogs': [],
            'todayTasks': [],
            'weeklyPlans': {},
            'createdAt': DateTime.now().toIso8601String(),
          }),
        );
        print('✅ Created new data file at: ${_dataFile!.path}');
      } else {
        print('✅ Found existing data file: ${_dataFile!.path}');
      }
    } catch (e) {
      print('❌ Error initializing data file: $e');
    }
  }

  //Load from JSON file instead of SharedPreferences
  Future<void> _loadData() async {
    if (_dataFile == null) {
      print('❌ Data file not initialized');
      return;
    }

    try {
      final content = await _dataFile!.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      setState(() {
        currentDay = data['currentDay'] ?? 1;
        currentPhase = _getPhaseFromDay(currentDay);

        final dateStr = data['selectedDate'];
        if (dateStr != null) {
          selectedDate = DateTime.parse(dateStr);
        }

        final tasksData = data['todayTasks'] as List?;
        if (tasksData != null) {
          todayTasks = tasksData.map((t) => Task.fromJson(t)).toList();
        }

        final logsData = data['dailyLogs'] as List?;
        if (logsData != null) {
          dailyLogs = List<Map<String, dynamic>>.from(logsData);
        }

        final plansData = data['weeklyPlans'] as Map?;
        if (plansData != null) {
          weeklyPlans = plansData.map(
            (k, v) => MapEntry(k.toString(), WeeklyPlan.fromJson(v)),
          );
        }

        _loadWeekPlan();
        _initializeDefaultTasks();
      });

      print('✅ Data loaded successfully - Day $currentDay');
    } catch (e) {
      print('❌ Error loading data: $e');
    }
  }

  // UPDATED: Save to JSON file instead of SharedPreferences
  Future<void> _saveData() async {
    if (_dataFile == null) {
      print('❌ Data file not initialized');
      return;
    }

    try {
      final data = {
        'version': 1,
        'currentDay': currentDay,
        'currentPhase': currentPhase,
        'selectedDate': selectedDate.toIso8601String(),
        'todayTasks': todayTasks.map((t) => t.toJson()).toList(),
        'dailyLogs': dailyLogs,
        'weeklyPlans': weeklyPlans.map((k, v) => MapEntry(k, v.toJson())),
        'lastSaved': DateTime.now().toIso8601String(),
      };

      await _dataFile!.writeAsString(json.encode(data));
      print('💾 Data saved - Day $currentDay');
    } catch (e) {
      print('❌ Error saving data: $e');
    }
  }

  // NEW: Show data location
  Future<void> _showDataLocation() async {
    if (_dataFile == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📁 Data Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your tracking data is stored at:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SelectableText(
              _dataFile!.parent.path,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '✅ This data survives app updates and reinstalls',
              style: TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              'File size: ${(_dataFile!.lengthSync() / 1024).toStringAsFixed(2)} KB',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Process.run('explorer', [_dataFile!.parent.path]);
            },
            child: const Text('Open Folder'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // NEW: Create manual backup
  Future<void> _createManualBackup() async {
    try {
      if (_dataFile == null) return;

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFile = File(
        path.join(_dataFile!.parent.path, 'backup_$timestamp.json'),
      );

      await _dataFile!.copy(backupFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup created: backup_$timestamp.json'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () {
                Process.run('explorer', [_dataFile!.parent.path]);
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Backup failed: $e');
    }
  }

  // UPDATED: Better backup detection
  Future<void> _restoreFromBackup() async {
    try {
      if (_appDataDir == null) return;

      // Find all JSON files (includes renamed backups)
      final allJsonFiles =
          _appDataDir!
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.json'))
              .toList()
            ..sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
            ); // Sort by date modified

      // Exclude the main data file
      final backupFiles = allJsonFiles
          .where((f) => !f.path.endsWith('user_data.json'))
          .toList();

      if (backupFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No backup files found'),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () {
                  Process.run('explorer', [_appDataDir!.path]);
                },
              ),
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📂 Restore from Backup'),
          content: SizedBox(
            width: 450,
            height: 400,
            child: Column(
              children: [
                Text(
                  'Found ${backupFiles.length} backup file(s)',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: backupFiles.length,
                    itemBuilder: (context, index) {
                      final file = backupFiles[index];
                      final filename = path.basename(file.path);
                      final stat = file.statSync();
                      final modified = DateFormat(
                        'MMM dd, yyyy HH:mm',
                      ).format(stat.modified);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.backup, color: Colors.blue),
                          title: Text(
                            filename,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Modified: $modified\nSize: ${(stat.size / 1024).toStringAsFixed(2)} KB',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.restore),
                          onTap: () async {
                            await _performRestore(file);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Process.run('explorer', [_appDataDir!.path]);
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Folder'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Restore failed: $e');
    }
  }

  // NEW: Perform actual restore
  Future<void> _performRestore(File backupFile) async {
    try {
      final content = await backupFile.readAsString();
      final data = json.decode(content);

      setState(() {
        currentDay = data['currentDay'] ?? 1;
        currentPhase = data['currentPhase'] ?? 1;

        final dateStr = data['selectedDate'];
        if (dateStr != null) {
          selectedDate = DateTime.parse(dateStr);
        }

        final logsData = data['dailyLogs'] as List?;
        if (logsData != null) {
          dailyLogs = List<Map<String, dynamic>>.from(logsData);
        }

        final tasksData = data['todayTasks'] as List?;
        if (tasksData != null) {
          todayTasks = tasksData.map((t) => Task.fromJson(t)).toList();
        }

        final plansData = data['weeklyPlans'] as Map?;
        if (plansData != null) {
          weeklyPlans = plansData.map(
            (k, v) => MapEntry(k.toString(), WeeklyPlan.fromJson(v)),
          );
        }
      });

      await _saveData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Restored from: ${path.basename(backupFile.path)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Restore failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restore: Invalid backup file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadWeekPlan() {
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
    currentWeekPlan = weeklyPlans[weekKey];
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _startNotificationChecker() {
    notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) return;

      final now = DateTime.now();
      for (var task in todayTasks) {
        if (task.scheduledTime != null &&
            !task.notificationSent &&
            !task.isCompleted) {
          final diff = task.scheduledTime!.difference(now).inMinutes;
          if (diff <= 5 && diff >= 0) {
            _showSystemNotification(task);
            task.notificationSent = true;
            _saveData();
          }
        }
      }
    });
  }

  Future<void> _showSystemNotification(Task task) async {
    const androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Notifications',
      channelDescription: 'Notifications for scheduled tasks',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      task.id.hashCode,
      '⏰ Task Starting Soon',
      task.title,
      details,
    );
  }

  // Main toggle function that user calls
  Future<void> _toggleFocusMode() async {
    setState(() {
      isFocusMode = !isFocusMode;
    });

    if (isFocusMode) {
      final webSuccess = await _blockSocialMedia();
      final appSuccess = await _blockSocialMediaApps();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              webSuccess && appSuccess
                  ? '🎯 Focus Mode ON - All social media blocked'
                  : webSuccess && !appSuccess
                  ? '🎯 Websites blocked. Apps require admin access'
                  : !webSuccess && appSuccess
                  ? '🎯 Apps blocked. Websites require admin access'
                  : '⚠️ Focus Mode failed - Run as administrator',
            ),
            backgroundColor: (webSuccess || appSuccess)
                ? Colors.green
                : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Start monitoring processes on desktop
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        _startProcessMonitoring();
      }
    } else {
      final webSuccess = await _unblockSocialMedia();
      final appSuccess = await _unblockSocialMediaApps();

      // Stop monitoring
      _processMonitoringTimer?.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              webSuccess && appSuccess
                  ? '✅ Focus Mode OFF - All unblocked'
                  : '⚠️ Some blocks may still be active',
            ),
            backgroundColor: (webSuccess && appSuccess)
                ? Colors.orange
                : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Block social media websites by modifying hosts file
  Future<bool> _blockSocialMedia() async {
    final socialMediaHosts = [
      '0.0.0.0 www.facebook.com',
      '0.0.0.0 facebook.com',
      '0.0.0.0 www.instagram.com',
      '0.0.0.0 instagram.com',
      '0.0.0.0 www.twitter.com',
      '0.0.0.0 twitter.com',
      '0.0.0.0 x.com',
      '0.0.0.0 www.youtube.com',
      '0.0.0.0 youtube.com',
      '0.0.0.0 www.tiktok.com',
      '0.0.0.0 tiktok.com',
      '0.0.0.0 web.whatsapp.com',
      '0.0.0.0 reddit.com',
      '0.0.0.0 www.reddit.com',
      '0.0.0.0 www.linkedin.com',
      '0.0.0.0 linkedin.com',
      '0.0.0.0 www.snapchat.com',
      '0.0.0.0 snapchat.com',
    ];

    try {
      // Mobile doesn't have access to hosts file, skip
      if (Platform.isAndroid || Platform.isIOS) {
        print('📱 Skipping hosts file on mobile (not accessible)');
        return true; // Return true since it's expected behavior
      }

      String hostsPath;
      if (Platform.isWindows) {
        hostsPath = r'C:\Windows\System32\drivers\etc\hosts';
      } else if (Platform.isMacOS || Platform.isLinux) {
        hostsPath = '/etc/hosts';
      } else {
        print('Unsupported platform');
        return false;
      }

      final hostsFile = File(hostsPath);

      if (!await hostsFile.exists()) {
        print('Hosts file does not exist at: $hostsPath');
        return false;
      }

      String content = await hostsFile.readAsString();
      print(
        '🔒 Blocking websites - Original content length: ${content.length}',
      );

      // Remove existing entries
      if (content.contains('FOCUS_MODE_START')) {
        final lines = content.split('\n');
        final cleanedLines = <String>[];
        bool inFocusBlock = false;

        for (var line in lines) {
          if (line.contains('FOCUS_MODE_START')) {
            inFocusBlock = true;
            continue;
          }
          if (line.contains('FOCUS_MODE_END')) {
            inFocusBlock = false;
            continue;
          }
          if (!inFocusBlock) {
            cleanedLines.add(line);
          }
        }
        content = cleanedLines.join('\n');
      }

      if (!content.endsWith('\n')) {
        content += '\n';
      }

      final blockEntries =
          '# FOCUS_MODE_START\n${socialMediaHosts.join('\n')}\n# FOCUS_MODE_END\n';
      await hostsFile.writeAsString(content + blockEntries);

      final verifyContent = await hostsFile.readAsString();
      final wasAdded = verifyContent.contains('FOCUS_MODE_START');

      print(wasAdded ? '✅ Websites blocked' : '❌ Failed to block websites');
      return wasAdded;
    } catch (e) {
      print('❌ Error blocking websites: $e');
      return false;
    }
  }

  // Unblock social media websites
  Future<bool> _unblockSocialMedia() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return true; // Mobile doesn't use hosts file
      }

      String hostsPath;
      if (Platform.isWindows) {
        hostsPath = r'C:\Windows\System32\drivers\etc\hosts';
      } else if (Platform.isMacOS || Platform.isLinux) {
        hostsPath = '/etc/hosts';
      } else {
        return false;
      }

      final hostsFile = File(hostsPath);
      if (!await hostsFile.exists()) return false;

      String content = await hostsFile.readAsString();
      print('🔓 Unblocking websites');

      if (!content.contains('FOCUS_MODE_START')) {
        print('No blocks found');
        return true;
      }

      // Line-by-line removal
      final lines = content.split('\n');
      final newLines = <String>[];
      bool inFocusBlock = false;

      for (var line in lines) {
        if (line.contains('FOCUS_MODE_START')) {
          inFocusBlock = true;
          continue;
        }
        if (line.contains('FOCUS_MODE_END')) {
          inFocusBlock = false;
          continue;
        }
        if (!inFocusBlock) {
          newLines.add(line);
        }
      }

      await hostsFile.writeAsString(newLines.join('\n'));
      print('✅ Websites unblocked');
      return true;
    } catch (e) {
      print('❌ Error unblocking websites: $e');
      return false;
    }
  }

  // Block social media apps (platform-specific)
  Future<bool> _blockSocialMediaApps() async {
    try {
      if (Platform.isWindows) {
        return await _blockAppsWindows();
      } else if (Platform.isMacOS) {
        return await _blockAppsMacOS();
      } else if (Platform.isLinux) {
        return await _blockAppsLinux();
      } else if (Platform.isAndroid) {
        return await _blockAppsAndroid();
      } else if (Platform.isIOS) {
        return await _blockAppsIOS();
      }
      return false;
    } catch (e) {
      print('❌ Error blocking apps: $e');
      return false;
    }
  }

  // Unblock social media apps
  Future<bool> _unblockSocialMediaApps() async {
    try {
      if (Platform.isWindows) {
        return await _unblockAppsWindows();
      } else if (Platform.isMacOS) {
        return await _unblockAppsMacOS();
      } else if (Platform.isLinux) {
        return await _unblockAppsLinux();
      } else if (Platform.isAndroid) {
        return await _unblockAppsAndroid();
      } else if (Platform.isIOS) {
        return await _unblockAppsIOS();
      }
      return false;
    } catch (e) {
      print('❌ Error unblocking apps: $e');
      return false;
    }
  }

  // ============================================
  // WINDOWS: Block apps using firewall + kill
  // ============================================
  Future<bool> _blockAppsWindows() async {
    final appsToKill = [
      'WhatsApp.exe',
      'Discord.exe',
      'Slack.exe',
      'Telegram.exe',
      'Signal.exe',
      'Facebook.exe',
      'Instagram.exe',
      'Twitter.exe',
      'TikTok.exe',
    ];

    try {
      print('🔒 Blocking Windows apps...');
      int killedCount = 0;

      for (var app in appsToKill) {
        try {
          final result = await Process.run('taskkill', [
            '/F',
            '/IM',
            app,
          ], runInShell: true);
          if (result.exitCode == 0) {
            print('🔪 Killed: $app');
            killedCount++;
          }
        } catch (e) {
          // App not running, that's fine
        }
      }

      print('✅ Killed $killedCount Windows apps');
      return true;
    } catch (e) {
      print('❌ Error blocking Windows apps: $e');
      return false;
    }
  }

  Future<bool> _unblockAppsWindows() async {
    // Nothing to unblock on Windows (apps can be relaunched)
    print('✅ Windows apps unblocked (no action needed)');
    return true;
  }

  // ============================================
  // macOS: Block apps by killing + permissions
  // ============================================
  Future<bool> _blockAppsMacOS() async {
    final appsToBlock = ['WhatsApp', 'Discord', 'Slack', 'Telegram', 'Signal'];

    try {
      print('🔒 Blocking macOS apps...');
      int killedCount = 0;

      for (var app in appsToBlock) {
        try {
          await Process.run('killall', [app]);
          print('🔪 Killed: $app');
          killedCount++;
        } catch (e) {
          // App not running
        }
      }

      print('✅ Killed $killedCount macOS apps');
      return true;
    } catch (e) {
      print('❌ Error blocking macOS apps: $e');
      return false;
    }
  }

  Future<bool> _unblockAppsMacOS() async {
    print('✅ macOS apps unblocked');
    return true;
  }

  // ============================================
  // Linux: Block apps by killing
  // ============================================
  Future<bool> _blockAppsLinux() async {
    final appsToKill = [
      'whatsapp',
      'discord',
      'slack',
      'telegram-desktop',
      'signal-desktop',
    ];

    try {
      print('🔒 Blocking Linux apps...');
      int killedCount = 0;

      for (var app in appsToKill) {
        try {
          await Process.run('pkill', ['-9', app]);
          print('🔪 Killed: $app');
          killedCount++;
        } catch (e) {
          // App not running
        }
      }

      print('✅ Killed $killedCount Linux apps');
      return true;
    } catch (e) {
      print('❌ Error blocking Linux apps: $e');
      return false;
    }
  }

  Future<bool> _unblockAppsLinux() async {
    print('✅ Linux apps unblocked');
    return true;
  }

  // ============================================
  // ANDROID: Block apps using App Management
  // ============================================
  Future<bool> _blockAppsAndroid() async {
    final appsToBlock = [
      'com.whatsapp',
      'com.instagram.android',
      'com.facebook.katana',
      'com.twitter.android',
      'com.zhiliaoapp.musically', // TikTok
      'com.snapchat.android',
      'com.discord',
      'com.slack',
    ];

    try {
      print('🔒 Blocking Android apps...');

      // Method 1: Try to disable apps (requires root/admin)
      int blockedCount = 0;
      for (var packageName in appsToBlock) {
        try {
          final result = await Process.run('pm', [
            'disable-user',
            packageName,
          ], runInShell: true);
          if (result.exitCode == 0) {
            print('✅ Disabled: $packageName');
            blockedCount++;
          }
        } catch (e) {
          print('⚠️ Could not disable $packageName (requires root)');
        }
      }

      if (blockedCount == 0) {
        // Method 2: Use Android App Ops (no root needed)
        print('📱 Using App Ops method (non-root)...');
        for (var packageName in appsToBlock) {
          try {
            // Revoke network permission
            await Process.run('appops', [
              'set',
              packageName,
              'WIFI_SCAN',
              'deny',
            ], runInShell: true);
            await Process.run('appops', [
              'set',
              packageName,
              'COARSE_LOCATION',
              'deny',
            ], runInShell: true);
            print('✅ Restricted: $packageName');
            blockedCount++;
          } catch (e) {
            // Failed
          }
        }
      }

      print('✅ Blocked $blockedCount Android apps');
      return blockedCount > 0;
    } catch (e) {
      print('❌ Error blocking Android apps: $e');
      print(
        '💡 Tip: Root access or special permissions needed for full blocking',
      );
      return false;
    }
  }

  Future<bool> _unblockAppsAndroid() async {
    final appsToBlock = [
      'com.whatsapp',
      'com.instagram.android',
      'com.facebook.katana',
      'com.twitter.android',
      'com.zhiliaoapp.musically',
      'com.snapchat.android',
      'com.discord',
      'com.slack',
    ];

    try {
      print('🔓 Unblocking Android apps...');

      for (var packageName in appsToBlock) {
        try {
          // Re-enable apps
          await Process.run('pm', ['enable', packageName], runInShell: true);

          // Restore permissions
          await Process.run('appops', [
            'set',
            packageName,
            'WIFI_SCAN',
            'allow',
          ], runInShell: true);
          await Process.run('appops', [
            'set',
            packageName,
            'COARSE_LOCATION',
            'allow',
          ], runInShell: true);
        } catch (e) {
          // Ignore errors
        }
      }

      print('✅ Android apps unblocked');
      return true;
    } catch (e) {
      print('❌ Error unblocking Android apps: $e');
      return false;
    }
  }

  // ============================================
  // iOS: Block apps using Screen Time API
  // ============================================
  Future<bool> _blockAppsIOS() async {
    print('📱 iOS app blocking requires Screen Time API integration');
    print('💡 Showing user instructions instead...');

    // On iOS, we can't programmatically block apps without MDM or Screen Time entitlements
    // Instead, show user a guide
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📱 Block Apps on iOS'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'iOS requires manual app blocking via Screen Time:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('1. Open Settings → Screen Time'),
                SizedBox(height: 8),
                Text('2. Tap "App Limits"'),
                SizedBox(height: 8),
                Text('3. Add Limit → Social Networking'),
                SizedBox(height: 8),
                Text('4. Set time to 1 minute'),
                SizedBox(height: 16),
                Text(
                  'Apps to block:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• WhatsApp, Instagram, Facebook'),
                Text('• Twitter, TikTok, Snapchat'),
                Text('• Discord, Slack, Telegram'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }

    return true; // Return true since we showed instructions
  }

  Future<bool> _unblockAppsIOS() async {
    print('✅ iOS apps unblocked (manual via Screen Time)');
    return true;
  }

  // ============================================
  // Background process monitoring (Desktop only)
  // ============================================
  void _startProcessMonitoring() {
    _processMonitoringTimer?.cancel();

    if (Platform.isAndroid || Platform.isIOS) {
      return; // No monitoring on mobile
    }

    print('👁️ Starting process monitoring...');

    _processMonitoringTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      if (!mounted || !isFocusMode) {
        timer.cancel();
        return;
      }

      print('🔍 Checking for social media processes...');

      if (Platform.isWindows) {
        await _blockAppsWindows();
      } else if (Platform.isMacOS) {
        await _blockAppsMacOS();
      } else if (Platform.isLinux) {
        await _blockAppsLinux();
      }
    });
  }

  // Optional: Check permissions on startup
  Future<void> _checkHostsFilePermissions() async {
    try {
      String hostsPath;
      if (Platform.isWindows) {
        hostsPath = r'C:\Windows\System32\drivers\etc\hosts';
      } else if (Platform.isMacOS || Platform.isLinux) {
        hostsPath = '/etc/hosts';
      } else {
        return;
      }

      final hostsFile = File(hostsPath);

      final canRead = await hostsFile.exists();
      print('📄 Hosts file exists: $canRead');

      if (canRead) {
        final stat = await hostsFile.stat();
        print('📊 Hosts file size: ${stat.size} bytes');
        print('⏰ Last modified: ${stat.modified}');

        // Test write permission
        final testContent = await hostsFile.readAsString();
        await hostsFile.writeAsString(testContent);
        print('✅ Write permission: OK');
      }
    } catch (e) {
      print('❌ Hosts file permission check failed: $e');
      print('⚠️ You may need to run as Administrator');
    }
  }

  void _startPomodoro(Task task) {
    setState(() {
      currentPomodoroTask = task;
      pomodoroMinutesLeft = 25;
      isPomodoroRunning = true;
    });

    pomodoroTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        pomodoroMinutesLeft--;
        if (pomodoroMinutesLeft <= 0) {
          timer.cancel();
          isPomodoroRunning = false;
          task.pomodoroCount++;
          _showPomodoroComplete();
          _saveData();
        }
      });
    });
  }

  void _stopPomodoro() {
    pomodoroTimer?.cancel();
    setState(() {
      isPomodoroRunning = false;
      currentPomodoroTask = null;
      pomodoroMinutesLeft = 25;
    });
  }

  Future<void> _showPomodoroComplete() async {
    await _showSystemNotification(
      Task(
        id: 'pomodoro',
        title: '🍅 Pomodoro Complete! Take a 5-minute break.',
        category: 'Pomodoro',
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🍅 Pomodoro Complete! Take a 5-minute break.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  int _getPhaseFromDay(int day) {
    if (day <= 100) return 1;
    if (day <= 250) return 2;
    if (day <= 400) return 3;
    if (day <= 600) return 4;
    if (day <= 800) return 5;
    return 6;
  }

  void _initializeDefaultTasks() {
    if (todayTasks.isEmpty) {
      final defaultTasks = _getPhaseActivities(currentPhase);
      todayTasks = [];
      defaultTasks.forEach((category, activities) {
        for (var activity in activities) {
          todayTasks.add(
            Task(
              id: '${category}_$activity',
              title: activity,
              category: category,
            ),
          );
        }
      });
    }
  }

  Map<String, List<String>> _getPhaseActivities(int phase) {
    switch (phase) {
      case 1:
        return {
          'Technical (60%)': [
            'Focused coding (1 hour)',
            'Deployed project work',
            'Learned something new',
          ],
          'Product/Market (30%)': [
            'User interview conducted',
            'Problem validation work',
            'Prototype iteration',
          ],
          'Habits (10%)': [
            'Exercise (30 min)',
            'Journaling (10 min)',
            'Sleep 7+ hours',
          ],
        };
      case 2:
        return {
          'Technical (50%)': [
            'MVP development (90 min)',
            'CI/CD or infrastructure work',
            'Code quality improvement',
          ],
          'Product/Market (40%)': [
            'User feedback session',
            'Metrics tracking',
            'Feature iteration',
          ],
          'Communication (10%)': [
            'Weekly update written',
            'Product pitch practice',
            'Decision documented',
          ],
        };
      case 3:
        return {
          'Technical (40%)': [
            'Performance optimization',
            'Security improvement',
            'Infrastructure scaling',
          ],
          'Product/Growth (50%)': [
            'User acquisition work',
            'Onboarding improvement',
            'Monetization setup',
          ],
          'Business (10%)': [
            'Metrics reviewed',
            'Financial planning',
            'Customer conversation',
          ],
        };
      case 4:
        return {
          'Technical (30%)': [
            'Feature development',
            'Analytics implementation',
            'Integration work',
          ],
          'Business/Growth (50%)': [
            'Revenue growth activity',
            'Marketing execution',
            'Customer success work',
          ],
          'Team Building (20%)': [
            'Delegation or hiring work',
            'Process documentation',
            '1-on-1 or feedback session',
          ],
        };
      case 5:
        return {
          'Technical (20%)': [
            'Infrastructure scaling',
            'Open source contribution',
            'Internal tools work',
          ],
          'Business (40%)': [
            'Revenue optimization',
            'Partnership development',
            'Unit economics improvement',
          ],
          'Reputation (30%)': [
            'Content published',
            'Network building',
            'Community contribution',
          ],
          'Team (10%)': [
            'Team development',
            'Culture building',
            'Sprint execution',
          ],
        };
      case 6:
        return {
          'Strategic (40%)': [
            'Investor/advisor meeting',
            'Long-term planning',
            'Major decision made',
          ],
          'Execution (40%)': [
            'Revenue target progress',
            'Team leadership',
            'Process improvement',
          ],
          'Technical (20%)': [
            'System reliability work',
            'Security/compliance',
            'Technical roadmap',
          ],
        };
      default:
        return {};
    }
  }

  String _getPhaseName(int phase) {
    switch (phase) {
      case 1:
        return 'Foundation + Validation';
      case 2:
        return 'Build Real MVP';
      case 3:
        return 'Scale to 100 Users';
      case 4:
        return 'Profitability + Team';
      case 5:
        return 'Scale + Authority';
      case 6:
        return 'Venture-Scale';
      default:
        return 'Unknown';
    }
  }

  double _calculateDailyScore() {
    if (todayTasks.isEmpty) return 0;
    int completed = todayTasks.where((t) => t.isCompleted).length;
    return (completed / todayTasks.length) * 100;
  }

  void _completeDay() {
    final score = _calculateDailyScore();
    dailyLogs.add({
      'day': currentDay,
      'phase': currentPhase,
      'score': score,
      'date': selectedDate.toIso8601String(),
      'tasks': todayTasks.map((t) => t.toJson()).toList(),
    });

    setState(() {
      currentDay++;
      selectedDate = selectedDate.add(const Duration(days: 1));
      currentPhase = _getPhaseFromDay(currentDay);
      todayTasks.clear();
      _initializeDefaultTasks();
    });

    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Day ${currentDay - 1} completed with ${score.toStringAsFixed(0)}% score!',
        ),
        backgroundColor: score >= 80 ? Colors.green : Colors.orange,
      ),
    );
  }

  void _undoLastDay() {
    if (dailyLogs.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Last Day?'),
        content: const Text(
          'This will restore the previous day and its tasks. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final lastLog = dailyLogs.removeLast();
                currentDay--;
                selectedDate = DateTime.parse(lastLog['date']);
                currentPhase = _getPhaseFromDay(currentDay);

                final tasksList = (lastLog['tasks'] ?? []) as List<dynamic>;
                todayTasks = tasksList.map((t) => Task.fromJson(t)).toList();
              });

              _saveData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Day restored successfully'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '1000-Day Transformation Progress Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Current Day: $currentDay / 1000'),
            pw.Text(
              'Current Phase: Phase $currentPhase - ${_getPhaseName(currentPhase)}',
            ),
            pw.Text(
              'Progress: ${(currentDay / 1000 * 100).toStringAsFixed(1)}%',
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Recent History:',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            ...dailyLogs.reversed.take(20).map((log) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  'Day ${log['day']} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(log['date']))} - Score: ${log['score'].toStringAsFixed(0)}%',
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/transformation_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to: ${file.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyScore = _calculateDailyScore();

    return Scaffold(
      body: Row(
        children: [
          // Sidebar - Fixed overflow
          Container(
            width: 280,
            color: const Color(0xFF0D1129),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.rocket_launch,
                  size: 50,
                  color: Colors.deepPurpleAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  '1000-DAY\nTRANSFORMATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 30),

                // Stats - Scrollable if needed
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildStatCard('Day', currentDay.toString(), '/ 1000'),
                        _buildStatCard(
                          'Phase',
                          currentPhase.toString(),
                          _getPhaseName(currentPhase),
                        ),
                        _buildStatCard(
                          'Progress',
                          '${(currentDay / 1000 * 100).toStringAsFixed(1)}%',
                          'Complete',
                        ),

                        const SizedBox(height: 20),

                        // Pomodoro Timer
                        if (isPomodoroRunning) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'ðŸ… Pomodoro Running',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$pomodoroMinutesLeft min',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentPomodoroTask?.title ?? '',
                                    style: const TextStyle(fontSize: 11),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _stopPomodoro,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      minimumSize: const Size(
                                        double.infinity,
                                        35,
                                      ),
                                    ),
                                    child: const Text('Stop'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton.icon(
                            onPressed: _toggleFocusMode,
                            icon: Icon(
                              isFocusMode ? Icons.lock : Icons.lock_open,
                            ),
                            label: Text(isFocusMode ? 'Focus ON' : 'Focus OFF'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 45),
                              backgroundColor: isFocusMode
                                  ? Colors.green
                                  : Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Scrollable, collapsible sidebar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ===== Tracking Section =====
                        ExpansionTile(
                          title: const Text(
                            'Tracking',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: [
                            ElevatedButton.icon(
                              onPressed: _showHistoryDialog,
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text(
                                'History',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 38),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: _showAnalyticsDialog,
                              icon: const Icon(Icons.analytics, size: 18),
                              label: const Text(
                                'Analytics',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 38),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: _showWeekPlanDialog,
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text(
                                'Week Plan',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 38),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ===== Backup & Sync Section =====
                        ExpansionTile(
                          title: const Text(
                            'Backup & Sync',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isGoogleDriveConnected
                                  ? _syncToGoogleDrive
                                  : _setupGoogleDriveSync,
                              icon: Icon(
                                _isGoogleDriveConnected
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                size: 18,
                              ),
                              label: Text(
                                _isGoogleDriveConnected
                                    ? 'Sync Now'
                                    : 'Enable Sync',
                                style: const TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 38),
                                backgroundColor: _isGoogleDriveConnected
                                    ? Colors.blue[700]
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: _createManualBackup,
                              icon: const Icon(Icons.backup, size: 18),
                              label: const Text(
                                'Backup Now',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 38),
                                backgroundColor: Colors.green[700],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ===== Data Management Section =====
                        ExpansionTile(
                          title: const Text(
                            'Data Management',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showDataLocation,
                              icon: const Icon(Icons.folder_open, size: 18),
                              label: const Text(
                                'Data Location',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 38),
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: _undoLastDay,
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text(
                                'Undo Day',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 38),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Restore with popup menu
                            PopupMenuButton<String>(
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.restore, size: 18),
                                label: const Text(
                                  'Restore',
                                  style: TextStyle(fontSize: 14),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 38),
                                ),
                              ),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'local',
                                  child: Row(
                                    children: [
                                      Icon(Icons.folder),
                                      SizedBox(width: 8),
                                      Text('From Local Backup'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'drive',
                                  child: Row(
                                    children: [
                                      Icon(Icons.cloud),
                                      SizedBox(width: 8),
                                      Text('From Google Drive'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'local') {
                                  _restoreFromBackup();
                                } else if (value == 'drive') {
                                  _restoreFromGoogleDrive();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content - Fixed overflow
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'Day $currentDay',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 20),
                        InkWell(
                          onTap: () => _selectDate(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.deepPurpleAccent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.deepPurpleAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(selectedDate),
                                  style: const TextStyle(
                                    color: Colors.deepPurpleAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 32,
                          color: Colors.deepPurpleAccent,
                          onPressed: () => _addCustomTask(),
                          tooltip: 'Add Custom Task',
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          iconSize: 28,
                          color: Colors.deepPurpleAccent,
                          onPressed: () => _exportToPDF(),
                          tooltip: 'Export to PDF',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Phase $currentPhase: ${_getPhaseName(currentPhase)}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 30),

                  // Daily score card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurpleAccent.withOpacity(0.3),
                          Colors.purpleAccent.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.deepPurpleAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Today\'s Focus Score',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${todayTasks.where((t) => t.isCompleted).length} of ${todayTasks.length} tasks completed',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        _buildCircularScore(dailyScore),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Tasks list - WITH WEEKLY GOALS AT TOP
                  Expanded(
                    child: ListView(
                      children: [
                        // Weekly goals section appears ONCE at the top
                        _buildWeeklyGoalsSection(),

                        // Then all tasks below
                        ...todayTasks
                            .map((task) => _buildTaskCard(task))
                            .toList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Complete day button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: dailyScore >= 50 ? _completeDay : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: Colors.deepPurpleAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        dailyScore >= 50
                            ? 'Complete Day $currentDay →'
                            : 'Complete at least 50% to finish day',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleTask(Task task) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        task.scheduledTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          picked.hour,
          picked.minute,
        );
        task.notificationSent = false;
      });
      _saveData();
    }
  }

  void _editTaskNotes(Task task) {
    final controller = TextEditingController(text: task.notes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Notes'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Add notes or details...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                task.notes = controller.text;
              });
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addCustomTask() {
    final titleController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() {
                  todayTasks.add(
                    Task(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text,
                      category: categoryController.text.isEmpty
                          ? 'Custom'
                          : categoryController.text,
                    ),
                  );
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _saveData();
    }
  }

  void _showAnalyticsDialog() {
    // Calculate statistics
    final last30Days = dailyLogs.length > 30
        ? dailyLogs.sublist(dailyLogs.length - 30)
        : dailyLogs;
    final avgScore = last30Days.isEmpty
        ? 0.0
        : last30Days.map((l) => l['score'] as double).reduce((a, b) => a + b) /
              last30Days.length;

    final streak = _calculateStreak();
    final bestStreak = _calculateBestStreak();

    // Prepare chart data
    final chartData = last30Days.map((log) {
      return FlSpot((log['day'] as int).toDouble(), log['score'] as double);
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics Dashboard'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildStatRow('Current Streak', '$streak days'),
                _buildStatRow('Best Streak', '$bestStreak days'),
                _buildStatRow(
                  '30-Day Average',
                  '${avgScore.toStringAsFixed(1)}%',
                ),
                _buildStatRow('Total Days Logged', '${dailyLogs.length}'),
                _buildStatRow('Days Remaining', '${1000 - currentDay}'),
                _buildStatRow(
                  'Completion Rate',
                  '${((dailyLogs.where((l) => l['score'] >= 80).length / dailyLogs.length) * 100).toStringAsFixed(1)}%',
                ),

                const SizedBox(height: 30),
                const Text(
                  'Score Trend (Last 30 Days)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (chartData.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: chartData,
                            isCurved: true,
                            color: Colors.deepPurpleAccent,
                            barWidth: 3,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.deepPurpleAccent.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('Not enough data to show chart'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  for (int i = dailyLogs.length - 1; i >= 0; i--) {
   final logDate = DateTime.parse(dailyLogs[i]['date']);
   final expectedDate = DateTime.now().subtract(Duration(days: streak));

   if (DateFormat('yyyy-MM-dd').format(logDate) ==
          DateFormat('yyyy-MM-dd').format(expectedDate) &&
      dailyLogs[i]['score'] >= 50) {
    streak++;
   } else {
    break;
   }
  }

    return streak;
  }

  int _calculateBestStreak() {
    if (dailyLogs.isEmpty) return 0;

    int currentStreak = 0;
    int bestStreak = 0;

    for (var log in dailyLogs) {
      if (log['score'] >= 50) {
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }

    return bestStreak;
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete History'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: dailyLogs.isEmpty
              ? const Center(child: Text('No history yet'))
              : ListView.builder(
                  itemCount: dailyLogs.length,
                  itemBuilder: (context, index) {
                    final log = dailyLogs[dailyLogs.length - 1 - index];
                    final date = DateTime.parse(log['date']);
                    final tasks =
                        (log['tasks'] as List?)
                            ?.map((t) => Task.fromJson(t))
                            .toList() ??
                        [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          'Day ${log['day']} - ${DateFormat('MMM dd, yyyy').format(date)}',
                        ),
                        subtitle: Text(
                          'Phase ${log['phase']} • Score: ${log['score'].toStringAsFixed(0)}%',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: log['score'] >= 80
                                ? Colors.green.withOpacity(0.2)
                                : log['score'] >= 50
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${log['score'].toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: log['score'] >= 80
                                  ? Colors.green
                                  : log['score'] >= 50
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                          ),
                        ),
                        children: tasks.map((task) {
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              task.isCompleted
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: task.isCompleted
                                  ? Colors.green
                                  : Colors.grey,
                              size: 20,
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 13,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              task.category,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // UPDATE: _showWeekPlanDialog method
  void _showWeekPlanDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1129),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Weekly Plan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              // Sync and refresh when closing dialog
                              _syncWeeklyGoalsToTasks();
                              setState(() {});
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    // Weekly plan cards - SCROLLABLE
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: _buildWeeklyPlanCards(setDialogState),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // NEW: Separate method that builds weekly cards and accepts setDialogState
  List<Widget> _buildWeeklyPlanCards(StateSetter setDialogState) {
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

    currentWeekPlan =
        weeklyPlans[weekKey] ??
        WeeklyPlan(
          weekStart: weekStart,
          dayPlans: {
            'Monday': DayPlan(dayName: 'Monday'),
            'Tuesday': DayPlan(dayName: 'Tuesday'),
            'Wednesday': DayPlan(dayName: 'Wednesday'),
            'Thursday': DayPlan(dayName: 'Thursday'),
            'Friday': DayPlan(dayName: 'Friday'),
            'Saturday': DayPlan(dayName: 'Saturday'),
            'Sunday': DayPlan(dayName: 'Sunday'),
          },
        );

    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final cards = <Widget>[];

    for (int i = 0; i < days.length; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayKey = days[i];
      final dayPlan =
          currentWeekPlan!.dayPlans[dayKey] ?? DayPlan(dayName: dayKey);

      cards.add(
        _buildWeeklyDayCardForDialog(
          day,
          dayKey,
          dayPlan,
          i,
          setDialogState, // Pass setDialogState
        ),
      );
    }

    return cards;
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATE: _buildWeeklyDayCard to accept setDialogState for instant refresh
  Widget _buildWeeklyDayCardForDialog(
    DateTime day,
    String dayKey,
    DayPlan dayPlan,
    int index,
    StateSetter setDialogState, // Add this parameter
  ) {
    final isToday =
        DateFormat('yyyy-MM-dd').format(day) ==
        DateFormat('yyyy-MM-dd').format(selectedDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isToday ? Colors.deepPurpleAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              isToday
                  ? Colors.deepPurpleAccent.withOpacity(0.1)
                  : Colors.transparent,
              Colors.transparent,
            ],
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            title: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday ? Colors.deepPurpleAccent : Colors.grey[800],
                  ),
                  child: Center(
                    child: Text(
                      (index + 1).toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayKey,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(day),
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.deepPurpleAccent),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurpleAccent,
                      ),
                    ),
                  ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description field
                    TextFormField(
                      initialValue: dayPlan.description ?? '',
                      decoration: InputDecoration(
                        labelText: 'Day Theme/Focus',
                        hintText: 'e.g., "MVP Development Sprint"',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[900],
                      ),
                      maxLines: 2,
                      onChanged: (value) {
                        setDialogState(() {
                          // Use setDialogState instead of setState
                          dayPlan.description = value;
                          currentWeekPlan!.dayPlans[dayKey] = dayPlan;
                        });
                        _saveData();
                      },
                    ),

                    const SizedBox(height: 20),

                    // Focus Areas header
                    const Text(
                      'Focus Areas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Goal groups
                    if (dayPlan.goalGroups.isEmpty)
                      Text(
                        'No focus areas yet. Add one below.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      )
                    else
                      ...dayPlan.goalGroups
                          .map(
                            (group) => _buildGoalGroupCardForDialog(
                              dayKey,
                              group,
                              setDialogState,
                            ),
                          )
                          .toList(),

                    const SizedBox(height: 16),

                    // Add goal group
                    OutlinedButton.icon(
                      onPressed: () =>
                          _addGoalGroupDialog(dayKey, dayPlan, setDialogState),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Focus Area'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Day Notes
                    TextFormField(
                      initialValue: dayPlan.notes ?? '',
                      decoration: InputDecoration(
                        labelText: 'Day Notes',
                        hintText: 'Any additional notes or reminders...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[900],
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        setDialogState(() {
                          // Use setDialogState
                          dayPlan.notes = value;
                          currentWeekPlan!.dayPlans[dayKey] = dayPlan;
                        });
                        _saveData();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATE: _buildGoalGroupCard for dialog with setDialogState
  Widget _buildGoalGroupCardForDialog(
    String dayKey,
    GoalGroup group,
    StateSetter setDialogState,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with delete
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (group.categoryDescription != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            group.categoryDescription!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    setDialogState(() {
                      final dayPlan = currentWeekPlan!.dayPlans[dayKey];
                      dayPlan?.goalGroups.remove(group);
                    });
                    _saveData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Goals with interactive checkboxes
            ...group.goals.asMap().entries.map((entry) {
              int goalIndex = entry.key;
              Goal goal = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: goal.isCompleted,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setDialogState(() {
                          group.goals[goalIndex].isCompleted = value ?? false;
                          _syncWeeklyGoalsToTasks();
                        });
                        _saveData();
                      },
                    ),
                    Expanded(
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: goal.isCompleted ? Colors.grey : Colors.white,
                          decoration: goal.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setDialogState(() {
                          group.goals.removeAt(goalIndex);
                        });
                        _saveData();
                      },
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 8),
            InkWell(
              onTap: () => _addGoalToGroupDialog(dayKey, group, setDialogState),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.deepPurpleAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Goal',
                      style: TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Add goal group dialog with setDialogState
  void _addGoalGroupDialog(
    String dayKey,
    DayPlan dayPlan,
    StateSetter setDialogState,
  ) {
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Focus Area'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., "Technical Development"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this focus area about?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (categoryController.text.isNotEmpty) {
                setDialogState(() {
                  final newGroup = GoalGroup(
                    category: categoryController.text,
                    categoryDescription: descriptionController.text.isEmpty
                        ? null
                        : descriptionController.text,
                    goals: <Goal>[],
                  );
                  dayPlan.goalGroups.add(newGroup);
                  currentWeekPlan!.dayPlans[dayKey] = dayPlan;
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // NEW: Add goal to group dialog with setDialogState
  void _addGoalToGroupDialog(
    String dayKey,
    GoalGroup group,
    StateSetter setDialogState,
  ) {
    final goalController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Goal'),
        content: TextField(
          controller: goalController,
          decoration: const InputDecoration(
            labelText: 'Goal',
            hintText: 'What do you want to achieve?',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (goalController.text.isNotEmpty) {
                setDialogState(() {
                  group.goals = [...group.goals];
                  group.goals.add(
                    Goal(title: goalController.text, isCompleted: false),
                  );
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ADD THESE NEW METHODS HERE (right after _getWeekStart)
  // ============================================

  /// Calculate weekly progress for today
  ({int total, int completed}) _getWeeklyProgress() {
    final dayKey = DateFormat('EEEE').format(selectedDate);
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

    final weekPlan = weeklyPlans[weekKey];
    final dayPlan = weekPlan?.dayPlans[dayKey];

    if (dayPlan == null) {
      return (total: 0, completed: 0);
    }

    int total = 0;
    int completed = 0;

    for (var group in dayPlan.goalGroups) {
      total += group.goals.length;
      completed += group.goals.where((g) => g.isCompleted).length;
    }

    return (total: total, completed: completed);
  }

  /// Safely get today's day plan
  DayPlan? _getTodayDayPlan() {
    final dayKey = DateFormat('EEEE').format(selectedDate);
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

    return weeklyPlans[weekKey]?.dayPlans[dayKey];
  }

  /// Sync all weekly goals of the selected day into today's tasks
  void _syncWeeklyGoalsToTasks() {
    final dayKey = DateFormat('EEEE').format(selectedDate);
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

    final weekPlan = weeklyPlans[weekKey];
    final dayPlan = weekPlan?.dayPlans[dayKey];

    if (dayPlan == null || dayPlan.goalGroups.isEmpty) {
      return; // No weekly goals to sync
    }

    // For each goal group and goal, ensure a task exists
    for (var group in dayPlan.goalGroups) {
      for (var goal in group.goals) {
        // Check if task already exists (by title + category combo)
        final taskExists = todayTasks.any(
          (t) => t.title == goal.title && t.category == group.category,
        );

        if (!taskExists) {
          // Create new task from goal
          todayTasks.add(
            Task(
              id: '${group.category}_${goal.title}'.hashCode.toString(),
              title: goal.title,
              category: group.category,
              isCompleted: goal.isCompleted, // Sync completion state
            ),
          );
        } else {
          // Update existing task's completion state
          final task = todayTasks.firstWhere(
            (t) => t.title == goal.title && t.category == group.category,
          );
          task.isCompleted = goal.isCompleted;
        }
      }
    }
  }

  void _syncTasksBackToGoals() {
    final dayKey = DateFormat('EEEE').format(selectedDate);
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

    final weekPlan = weeklyPlans[weekKey];
    final dayPlan = weekPlan?.dayPlans[dayKey];

    if (dayPlan == null) return;

    // Update goal completion based on task status
    for (var group in dayPlan.goalGroups) {
      for (var goal in group.goals) {
        final matchingTask = todayTasks.firstWhereOrNull(
          (t) => t.title == goal.title && t.category == group.category,
        );

        if (matchingTask != null) {
          goal.isCompleted = matchingTask.isCompleted;
        }
      }
    }
  }

  // UPDATED: _buildWeeklyGoalsSection with instant refresh on changes
  Widget _buildWeeklyGoalsSection() {
    final dayPlan = _getTodayDayPlan();
    final hasWeeklyGoals = dayPlan != null && dayPlan.goalGroups.isNotEmpty;

    if (!hasWeeklyGoals) {
      return const SizedBox.shrink();
    }

    final progress = _getWeeklyProgress();

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(
                Icons.calendar_month,
                color: Colors.deepPurpleAccent,
              ),
              title: const Text(
                "This Week's Focus",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${progress.completed}/${progress.total} completed',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress.total > 0
                        ? progress.completed / progress.total
                        : 0,
                    color: Colors.deepPurpleAccent,
                    backgroundColor: Colors.deepPurpleAccent.withOpacity(0.2),
                    minHeight: 6,
                  ),
                ],
              ),
              children: [
                if (dayPlan.description != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dayPlan.description!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ...dayPlan.goalGroups
                    .map(
                      (group) =>
                          _buildGoalGroupCardForTaskList(group, setLocalState),
                    )
                    .toList(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // UPDATED: Goal group card for task list dropdown with FULL CRUD
  Widget _buildGoalGroupCardForTaskList(
    GoalGroup group,
    StateSetter setLocalState,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with delete button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (group.categoryDescription != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            group.categoryDescription!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    setLocalState(() {
                      final dayKey = DateFormat('EEEE').format(selectedDate);
                      final weekStart = _getWeekStart(selectedDate);
                      final weekKey = DateFormat(
                        'yyyy-MM-dd',
                      ).format(weekStart);
                      final dayPlan = weeklyPlans[weekKey]?.dayPlans[dayKey];

                      if (dayPlan != null) {
                        // Remove all tasks related to this group
                        for (var goal in group.goals) {
                          todayTasks.removeWhere(
                            (t) =>
                                t.title == goal.title &&
                                t.category == group.category,
                          );
                        }
                        // Remove the group itself
                        dayPlan.goalGroups.remove(group);
                      }
                    });
                    _saveData();
                    setState(() {}); // Refresh main page
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Goals with checkboxes and delete buttons
            ...group.goals.asMap().entries.map((entry) {
              int goalIndex = entry.key;
              Goal goal = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: goal.isCompleted,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setLocalState(() {
                          group.goals[goalIndex].isCompleted = value ?? false;

                          // Sync to matching task in todayTasks
                          final matchingTask = todayTasks.firstWhereOrNull(
                            (t) =>
                                t.title == goal.title &&
                                t.category == group.category,
                          );
                          if (matchingTask != null) {
                            matchingTask.isCompleted = value ?? false;
                          }
                        });
                        _saveData();
                        setState(() {}); // Refresh main page
                      },
                    ),
                    Expanded(
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: goal.isCompleted ? Colors.grey : Colors.white,
                          decoration: goal.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setLocalState(() {
                          group.goals.removeAt(goalIndex);

                          // Also remove from todayTasks
                          todayTasks.removeWhere(
                            (t) =>
                                t.title == goal.title &&
                                t.category == group.category,
                          );
                        });
                        _saveData();
                        setState(() {}); // Refresh main page
                      },
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                final dayKey = DateFormat('EEEE').format(selectedDate);
                _addGoalToGroupTaskList(dayKey, group, setLocalState);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.deepPurpleAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Goal',
                      style: TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Add goal dialog from task list dropdown
  void _addGoalToGroupTaskList(
    String dayKey,
    GoalGroup group,
    StateSetter setLocalState,
  ) {
    final goalController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Goal'),
        content: TextField(
          controller: goalController,
          decoration: const InputDecoration(
            labelText: 'Goal',
            hintText: 'What do you want to achieve?',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (goalController.text.isNotEmpty) {
                setLocalState(() {
                  group.goals = [...group.goals];
                  final newGoal = Goal(
                    title: goalController.text,
                    isCompleted: false,
                  );
                  group.goals.add(newGoal);

                  // Also add to todayTasks
                  todayTasks.add(
                    Task(
                      id: '${group.category}_${goalController.text}'.hashCode
                          .toString(),
                      title: goalController.text,
                      category: group.category,
                      isCompleted: false,
                    ),
                  );
                });
                _saveData();
                setState(() {}); // Refresh main page instantly
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // UPDATED: _buildTaskCard method with proper syncing
  Widget _buildTaskCard(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isCompleted
              ? Colors.green.withOpacity(0.5)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: Colors.green,
          onChanged: (value) {
            setState(() {
              task.isCompleted = value ?? false;

              // Sync to weekly goals
              final dayKey = DateFormat('EEEE').format(selectedDate);
              final weekStart = _getWeekStart(selectedDate);
              final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
              final weekPlan = weeklyPlans[weekKey];
              final dayPlan = weekPlan?.dayPlans[dayKey];

              if (dayPlan != null) {
                for (var group in dayPlan.goalGroups) {
                  for (var goal in group.goals) {
                    if (goal.title == task.title &&
                        group.category == task.category) {
                      goal.isCompleted = value ?? false;
                    }
                  }
                }
              }
            });
            _saveData();
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey[500] : Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.category,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.deepPurpleAccent,
              ),
            ),
            if (task.scheduledTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(task.scheduledTime!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            if (task.pomodoroCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '🍅 ${task.pomodoroCount} pomodoro${task.pomodoroCount > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'pomodoro',
              child: Row(
                children: [
                  Icon(Icons.timer),
                  SizedBox(width: 8),
                  Text('Start Pomodoro'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'schedule',
              child: Row(
                children: [
                  Icon(Icons.schedule),
                  SizedBox(width: 8),
                  Text('Set Time'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'notes',
              child: Row(
                children: [
                  Icon(Icons.note),
                  SizedBox(width: 8),
                  Text('Add Notes'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'pomodoro') {
              if (!isPomodoroRunning) {
                _startPomodoro(task);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stop current pomodoro first'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } else if (value == 'schedule') {
              _scheduleTask(task);
            } else if (value == 'notes') {
              _editTaskNotes(task);
            } else if (value == 'delete') {
              setState(() {
                todayTasks.remove(task);
              });
              _saveData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildCircularScore(double score) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 8,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 80
                    ? Colors.green
                    : score >= 50
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
