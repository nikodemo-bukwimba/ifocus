import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
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

  runApp(const FounderTrackerApp());
}

class FounderTrackerApp extends StatelessWidget {
  const FounderTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1000-Day Founder Transformation',
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

class WeeklyPlan {
  DateTime weekStart;
  Map<String, List<String>> goals;
  Map<String, String> notes;

  WeeklyPlan({
    required this.weekStart,
    required this.goals,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart.toIso8601String(),
    'goals': goals,
    'notes': notes,
  };

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) => WeeklyPlan(
    weekStart: DateTime.parse(json['weekStart']),
    goals: Map<String, List<String>>.from(
      json['goals'].map((k, v) => MapEntry(k, List<String>.from(v))),
    ),
    notes: Map<String, String>.from(json['notes']),
  );
}

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({Key? key}) : super(key: key);

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage> {
  int currentDay = 1;
  int currentPhase = 1;
  DateTime selectedDate = DateTime.now();
  List<Task> todayTasks = [];
  List<Map<String, dynamic>> dailyLogs = [];
  bool isFocusMode = false;
  WeeklyPlan? currentWeekPlan;
  Map<String, WeeklyPlan> weeklyPlans = {};
  Timer? notificationTimer;
  Timer? pomodoroTimer;
  int pomodoroMinutesLeft = 25;
  bool isPomodoroRunning = false;
  Task? currentPomodoroTask;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startNotificationChecker();
  }

  @override
  void dispose() {
    notificationTimer?.cancel();
    pomodoroTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentDay = prefs.getInt('currentDay') ?? 1;
      currentPhase = _getPhaseFromDay(currentDay);

      final dateStr = prefs.getString('selectedDate');
      if (dateStr != null) {
        selectedDate = DateTime.parse(dateStr);
      }

      final tasksJson = prefs.getString('todayTasks');
      if (tasksJson != null) {
        final tasksList = json.decode(tasksJson) as List;
        todayTasks = tasksList.map((t) => Task.fromJson(t)).toList();
      }

      final logsJson = prefs.getString('dailyLogs');
      if (logsJson != null) {
        dailyLogs = List<Map<String, dynamic>>.from(json.decode(logsJson));
      }

      final weeklyPlansJson = prefs.getString('weeklyPlans');
      if (weeklyPlansJson != null) {
        final plansMap = json.decode(weeklyPlansJson) as Map;
        weeklyPlans = plansMap.map(
          (k, v) => MapEntry(k, WeeklyPlan.fromJson(v)),
        );
      }

      _loadWeekPlan();
      _initializeDefaultTasks();
    });
  }

  void _loadWeekPlan() {
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
    currentWeekPlan = weeklyPlans[weekKey];
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentDay', currentDay);
    await prefs.setString('selectedDate', selectedDate.toIso8601String());
    await prefs.setString(
      'todayTasks',
      json.encode(todayTasks.map((t) => t.toJson()).toList()),
    );
    await prefs.setString('dailyLogs', json.encode(dailyLogs));
    await prefs.setString(
      'weeklyPlans',
      json.encode(weeklyPlans.map((k, v) => MapEntry(k, v.toJson()))),
    );
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

  Future<void> _toggleFocusMode() async {
    setState(() {
      isFocusMode = !isFocusMode;
    });

    if (isFocusMode) {
      await _blockSocialMedia();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎯 Focus Mode ON - Social media blocked'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      await _unblockSocialMedia();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Focus Mode OFF - Social media unblocked'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _blockSocialMedia() async {
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
    ];

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
      final content = await hostsFile.readAsString();

      if (!content.contains('# FOUNDER_FOCUS_MODE_START')) {
        final newContent =
            content +
            '\n# FOUNDER_FOCUS_MODE_START\n' +
            socialMediaHosts.join('\n') +
            '\n# FOUNDER_FOCUS_MODE_END\n';

        await hostsFile.writeAsString(newContent);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ Run app as administrator to block social media',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _unblockSocialMedia() async {
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
      final content = await hostsFile.readAsString();

      final regex = RegExp(
        r'# FOUNDER_FOCUS_MODE_START.*?# FOUNDER_FOCUS_MODE_END\n',
        multiLine: true,
        dotAll: true,
      );

      final newContent = content.replaceAll(regex, '');
      await hostsFile.writeAsString(newContent);
    } catch (e) {
      // Silently fail
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
                                    '🍅 Pomodoro Running',
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

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showHistoryDialog(),
                        icon: const Icon(Icons.history, size: 20),
                        label: const Text('History'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showAnalyticsDialog(),
                        icon: const Icon(Icons.analytics, size: 20),
                        label: const Text('Analytics'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showWeekPlanDialog(),
                        icon: const Icon(Icons.calendar_month, size: 20),
                        label: const Text('Week Plan'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _undoLastDay,
                        icon: const Icon(Icons.undo, size: 20),
                        label: const Text('Undo Day'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                        ),
                      ),
                    ],
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

                  // Tasks list - Fixed overflow
                  Expanded(
                    child: ListView.builder(
                      itemCount: todayTasks.length,
                      itemBuilder: (context, index) {
                        final task = todayTasks[index];
                        return _buildTaskCard(task);
                      },
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

  int _calculateStreak() {
    if (dailyLogs.isEmpty) return 0;

    int streak = 0;
    for (int i = dailyLogs.length - 1; i >= 0; i--) {
      if (dailyLogs[i]['score'] >= 50) {
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

  void _showWeekPlanDialog() {
    final weekStart = _getWeekStart(selectedDate);
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

    if (currentWeekPlan == null) {
      currentWeekPlan = WeeklyPlan(weekStart: weekStart, goals: {}, notes: {});
      weeklyPlans[weekKey] = currentWeekPlan!;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Week Plan: ${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('MMM dd').format(weekStart.add(const Duration(days: 6)))}',
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: ListView.builder(
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = weekStart.add(Duration(days: index));
              final dayKey = DateFormat('EEEE').format(day);
              final goals = currentWeekPlan!.goals[dayKey] ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(DateFormat('EEEE, MMM dd').format(day)),
                  subtitle: Text('${goals.length} goals'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...goals
                              .map(
                                (goal) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(goal)),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            goals.remove(goal);
                                          });
                                          _saveData();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _addWeekGoal(dayKey);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Goal'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addWeekGoal(String dayKey) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Goal for $dayKey'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Goal',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  if (currentWeekPlan!.goals[dayKey] == null) {
                    currentWeekPlan!.goals[dayKey] = [];
                  }
                  currentWeekPlan!.goals[dayKey]!.add(controller.text);
                });
                _saveData();
                Navigator.pop(context);
                _showWeekPlanDialog();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
