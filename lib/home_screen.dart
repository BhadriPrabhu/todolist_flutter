import 'dart:async';
// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:timezone/timezone.dart' as tz;
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'task_model.dart';
import 'notification_service.dart';


extension StringExtension on String {
  String capitalize() {
    return isEmpty ? this : this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

/// Configuration for theme-related constants.
class ThemeConfig {
  static const Color primaryColor = Color(0xFF0288D1); // Blue
  static const Color secondaryColor = Color(0xFFEF5350); // Red
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E293B);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightCardColor = Color(0xFFF5F5F5);
  static const Color primaryTextColor = Colors.white;
  static const Color secondaryTextColor = Color(0xFFB0BEC5);
  static const Color borderColor = Color(0xFF455A64);
  static const Color highPriorityColor = Color(0xFFEF5350);
  static const Color lowPriorityColor = Color(0xFF4CAF50);
  static const Color buttonSecondaryColor = Color(0xFF78909C);
  static const dialogAnimationDuration = Duration(milliseconds: 300);
  static const celebrationDuration = Duration(seconds: 3);
  static const debounceDuration = Duration(milliseconds: 300);
}

/// Main screen for the To-Do List app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // final NotificationService _notificationService = NotificationService();
  NotificationService _notificationService = NotificationService();
  List<Task> _tasks = [];
  String _filterCompletion = 'All';
  String _filterPriority = 'All';
  String _filterCategory = 'All';
  String _sortBy = 'DueDate';
  String _searchQuery = '';
  bool _isDarkTheme = false;
  bool _showCelebration = false;
  bool _isLoading = false;
  late AnimationController _lottieController;
  List<Task>? _cachedFilteredTasks;
  Timer? _debounce;
  Timer? _overdueTimer;
  final List<TextEditingController> _controllers = [];

@override
  void initState() {
    _notificationService.initialize().then((_) async {
      if (!await _notificationService.requestPermissions()) {
        showSnackBar('Please grant notification permissions in settings');
        debugPrint('[2025-05-30 01:22 IST] Notification permission denied');
      } else {
        await _loadTasks();
      }
    });
    _lottieController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _overdueTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _cachedFilteredTasks = null;
          debugPrint('[2025-05-30 01:22 IST] Overdue timer triggered');
        });
      }
    });
    debugPrint('[2025-05-30 01:22 IST] HomeScreen initialized');
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _debounce?.cancel();
    _overdueTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
    debugPrint('[2025-05-30 01:10 IST] HomeScreen disposed');
  }

  Future<void> _loadTasks() async {
  setState(() => _isLoading = true);
  try {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
      final taskList = prefs.getStringList('tasks') ?? [];
      _tasks = taskList.map((json) {
        try {
          return Task.fromJson(json);
        } catch (e) {
          debugPrint('[2025-05-30 01:22 IST] Error parsing task JSON: $e');
          return null;
        }
      }).where((task) => task != null).cast<Task>().toList();
      for (var i = 0; i < _tasks.length; i++) {
        var task = _tasks[i];
        if (!task.isComplete && task.dueDate != null) {
          try {
            final dueDateUtc = DateTime.parse(task.dueDate!);
            final dueDateIst = tz.TZDateTime.from(dueDateUtc, tz.getLocation('Asia/Kolkata'));
            final now = tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'));
            final gracePeriod = now.subtract(const Duration(minutes: 1));
            debugPrint(
                '[2025-05-30 01:22 IST] Checking task ${task.id}: due $dueDateIst, now $now, isAfter: ${dueDateIst.isAfter(gracePeriod)}');
            if (dueDateIst.isAfter(gracePeriod)) {
              _notificationService.scheduleNotification(task);
              debugPrint(
                  '[2025-05-30 01:22 IST] Scheduled notification for task: ${task.id}, ${task.title}, due: $dueDateIst (UTC: ${task.dueDate})');
            } else if (!task.isNotified) { // Check if notification was already sent
              debugPrint(
                  '[2025-05-30 01:22 IST] Task ${task.id} is overdue: due $dueDateIst, now $now');
              _notificationService.scheduleOverdueNotification(task);
              // Update task to mark as notified
              _tasks[i] = task.copyWith(isNotified: true);
              _saveTasks(); // Save updated task list
            }
          } catch (e) {
            debugPrint(
                '[2025-05-30 01:22 IST] Failed to schedule notification for task ID: ${task.id}, error: $e');
            showSnackBar('Failed to schedule notification for "${task.title}"');
          }
        }
      }
      _cachedFilteredTasks = null;
      debugPrint('[2025-05-30 01:22 IST] Loaded ${_tasks.length} tasks');
    });
  } catch (e) {
    debugPrint('[2025-05-30 01:22 IST] Error loading tasks: $e');
    showSnackBar('Failed to load tasks');
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final taskList = _tasks.map((task) => task.toJson()).toList();
      await prefs.setStringList('tasks', taskList);
      debugPrint('[2025-05-30 01:22 IST] Saved ${_tasks.length} tasks');
    } catch (e) {
      debugPrint('[2025-05-30 01:22 IST] Error saving tasks: $e');
      showSnackBar('Failed to save tasks');
    }
  }

  /// Shows a snackbar with the given message.
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: ThemeConfig.primaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: ThemeConfig.darkCardColor,
      ),
    );
  }

void _addTask(Task task) async {
  setState(() => _isLoading = true);
  try {
    setState(() {
      _tasks.add(task);
      _cachedFilteredTasks = null;
    });
    debugPrint('[2025-05-30 02:10 IST] Added task: ${task.id}, ${task.title}, due: ${task.dueDate}');
    await Future.wait([
      _saveTasks(),
      _notificationService.scheduleNotification(task).catchError((e) {
        debugPrint('[2025-05-30 02:10 IST] Failed to schedule notification for task ID: ${task.id}, error: $e');
        throw e;
      }),
    ]);
    showSnackBar('Task "${task.title}" added');
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  } catch (e) {
    debugPrint('[2025-05-30 02:10 IST] Error adding task or scheduling notification: $e');
    showSnackBar('Failed to add task "${task.title}"');
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _editTask(int index, Task task) async {
  setState(() => _isLoading = true);
  try {
    setState(() {
      _tasks[index] = task;
      _cachedFilteredTasks = null; // Invalidate the cache immediately
    });
    debugPrint('[2025-05-30 02:13 IST] Edited task: ${task.id}, ${task.title}, due: ${task.dueDate}');
    await Future.wait([
      _saveTasks(),
      _notificationService.scheduleNotification(task).catchError((e) {
        debugPrint('[2025-05-30 02:13 IST] Failed to schedule notification for task ID: ${task.id}, error: $e');
        throw e;
      }),
    ]);
    showSnackBar('Task "${task.title}" updated');
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  } catch (e) {
    debugPrint('[2025-05-30 02:13 IST] Error editing task or scheduling notification: $e');
    showSnackBar('Failed to update task "${task.title}"');
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _deleteTask(int index) async {
    final task = _tasks[index];
    setState(() => _isLoading = true);
    try {
      setState(() {
        _tasks.removeAt(index);
        _cachedFilteredTasks = null;
      });
      debugPrint('[2025-05-30 11:02 IST] Deleted task: ${task.id}, ${task.title}, due: ${task.dueDate}');
      await Future.wait([
        _saveTasks(),
        _notificationService.cancelNotification(task.id).catchError((e) {
          debugPrint('[2025-05-30 11:02 IST] Failed to cancel notification for task ID: ${task.id}, error: $e');
          throw e;
        }),
      ]);
      showSnackBar('Task "${task.title}" deleted');
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      debugPrint('[2025-05-30 11:02 IST] Error deleting task or cancelling notification: $e');
      showSnackBar('Failed to delete task "${task.title}"');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleTaskCompletion(int index) async {
  setState(() => _isLoading = true);
  final task = _tasks[index];
  try {
    final updatedTask = task.copyWith(
      isComplete: !task.isComplete,
      isNotified: false, // Reset isNotified to allow rescheduling overdue notifications
    );
    setState(() {
      _tasks[index] = updatedTask;
      _cachedFilteredTasks = null; // Invalidate the cache immediately
    });
    debugPrint(
        '[2025-05-30 10:51 IST] Toggled task: ${_tasks[index].id}, ${_tasks[index].title}, isComplete: ${_tasks[index].isComplete}');
    await _saveTasks();
    if (updatedTask.isComplete) {
      debugPrint('[2025-05-30 10:51 IST] Cancelled notification for task ID: ${task.id}');
      await _notificationService.cancelNotification(task.id.hashCode.toString());
      if (_tasks.isNotEmpty && _tasks.every((t) => t.isComplete)) {
        setState(() {
          _showCelebration = true;
          debugPrint('[2025-05-30 10:51 IST] All tasks completed, showing celebration');
        });
        _lottieController
          ..reset()
          ..forward().whenComplete(() {
              if (mounted) {
                setState(() {
                  _showCelebration = false;
                  debugPrint('[2025-05-30 10:51 IST] Celebration completed');
                });
              }
            });
      }
    } else if (updatedTask.dueDate != null) {
      try {
        final dueDateUtc = DateTime.parse(updatedTask.dueDate!);
        final dueDateIst = tz.TZDateTime.from(dueDateUtc, tz.getLocation('Asia/Kolkata'));
        final now = tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'));
        debugPrint(
            '[2025-05-30 10:51 IST] Task ID: ${task.id}, raw dueDate: ${task.dueDate}, dueDate IST: $dueDateIst, now: $now, formatted: ${DateFormat.yMMMEd().add_jm().format(dueDateIst)}');
        if (dueDateIst.isAfter(now)) {
          debugPrint(
              '[2025-05-30 10:51 IST] Scheduled notification for task ID: ${task.id}, due: $dueDateIst');
          await _notificationService.scheduleNotification(updatedTask);
        } else {
          debugPrint(
              '[2025-05-30 10:51 IST] Not scheduling notification for task ID: ${task.id}, dueDate is not in the future');
        }
      } catch (e) {
        debugPrint('[2025-05-30 10:51 IST] Error handling notification for task ID: ${task.id}, error: $e');
        showSnackBar('Failed to schedule notification for "${updatedTask.title}"');
      }
    }
  } catch (e) {
    debugPrint('[2025-05-30 10:51 IST] Error toggling task completion: $e');
    showSnackBar('Failed to update task "${task.title}"');
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _shareTask(Task task) async {
    final dueDate = task.dueDate != null ? DateTime.parse(task.dueDate!) : null;
    final dueDateIst = dueDate != null ? tz.TZDateTime.from(dueDate, tz.getLocation('Asia/Kolkata')) : null;
    final message = '${task.title}\n${task.description}'
        '${task.notes != null && task.notes!.isNotEmpty ? '\nNotes: ${task.notes}' : ''}'
        '${dueDateIst != null ? '\nDue: ${DateFormat.yMMMMd().add_jm().format(dueDateIst)}' : ''}'
        '${task.category != null ? '\nCategory: ${task.category}' : ''}';
    await Share.share(message);
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
    debugPrint('[2025-05-30 11:02 IST] Shared task: ${task.title}');
  }

  /// Returns filtered and sorted tasks.
  List<Task> get filteredTasks {
    if (_cachedFilteredTasks != null) {
      return _cachedFilteredTasks!;
    }

    var filtered = _tasks.where((task) {
      final matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCompletion = _filterCompletion == 'All' ||
          (_filterCompletion == 'Completed' && task.isComplete) ||
          (_filterCompletion == 'Pending' && !task.isComplete) ||
          (_filterCompletion == 'Overdue' &&
              task.dueDate != null &&
              tz.TZDateTime.from(DateTime.parse(task.dueDate!), tz.getLocation('Asia/Kolkata')).isBefore(tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'))) &&
              !task.isComplete) ||
          (_filterCompletion == 'Due Today' &&
              task.dueDate != null &&
              tz.TZDateTime.from(DateTime.parse(task.dueDate!), tz.getLocation('Asia/Kolkata')).day == tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')).day);
      final matchesPriority = _filterPriority == 'All' || (task.priority?.toLowerCase() ?? '') == _filterPriority.toLowerCase();
      final matchesCategory = _filterCategory == 'All' ? true : task.category == _filterCategory;
      return matchesSearch && matchesCompletion && matchesPriority && matchesCategory;
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'Priority') {
        const priorityOrder = {'high': 0, 'low': 1};
        return (priorityOrder[a.priority] ?? 1).compareTo(priorityOrder[b.priority] ?? 1);
      } else if (_sortBy == 'DueDate') {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return tz.TZDateTime.from(DateTime.parse(a.dueDate!), tz.getLocation('Asia/Kolkata'))
            .compareTo(tz.TZDateTime.from(DateTime.parse(b.dueDate!), tz.getLocation('Asia/Kolkata')));
      }
      return 0;
    });

    _cachedFilteredTasks = filtered;
    return filtered;
  }

  /// Creates a reusable TextField widget.
  Widget _buildTextField({
    required String label,
    required Function(String) onChanged,
    String? initialValue,
    int? maxLines,
    int? maxLength,
    bool isRequired = false,
    bool isValid = true,
  }) {
    final controller = initialValue != null ? TextEditingController(text: initialValue) : null;
    if (controller != null) {
      _controllers.add(controller);
    }
    return Semantics(
      label: 'Enter $label',
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _isDarkTheme ? ThemeConfig.borderColor : Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _isDarkTheme ? ThemeConfig.borderColor : Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThemeConfig.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: _isDarkTheme ? ThemeConfig.darkCardColor : ThemeConfig.lightCardColor,
          errorText: isRequired && !isValid ? 'Required' : null,
          errorStyle: GoogleFonts.poppins(color: ThemeConfig.secondaryColor, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.poppins(
          color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        maxLines: maxLines,
        maxLength: maxLength,
        controller: controller,
        onChanged: onChanged,
      ),
    );
  }

  /// Creates a reusable Dropdown widget.
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    Color? fillColor,
  }) {
    return Semantics(
      label: 'Select $label',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            label: Text(
              label,
              style: GoogleFonts.poppins(
                color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _isDarkTheme ? ThemeConfig.borderColor : Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _isDarkTheme ? ThemeConfig.borderColor : Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ThemeConfig.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: fillColor ?? (_isDarkTheme ? ThemeConfig.darkCardColor : ThemeConfig.lightCardColor),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            prefixIconConstraints: const BoxConstraints(minWidth: 16),
          ),
          style: GoogleFonts.poppins(
            color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          dropdownColor: _isDarkTheme ? ThemeConfig.darkCardColor : Colors.white,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }

  /// Creates a consistent ThemeData for dialogs.
  ThemeData _buildDialogTheme() {
    return _isDarkTheme
        ? ThemeData.dark().copyWith(
            primaryColor: ThemeConfig.primaryColor,
            scaffoldBackgroundColor: ThemeConfig.darkBackground,
            cardColor: ThemeConfig.darkCardColor,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
              bodyColor: ThemeConfig.primaryTextColor,
              displayColor: ThemeConfig.primaryTextColor,
            ),
            colorScheme: const ColorScheme.dark(
              primary: ThemeConfig.primaryColor,
              onPrimary: Colors.white,
              surface: ThemeConfig.darkCardColor,
              onSurface: ThemeConfig.primaryTextColor,
            ),
            dialogBackgroundColor: ThemeConfig.darkCardColor,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.primaryColor,
              ),
            ),
          )
        : ThemeData.light().copyWith(
            primaryColor: ThemeConfig.primaryColor,
            scaffoldBackgroundColor: ThemeConfig.lightBackground,
            cardColor: ThemeConfig.lightCardColor,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
            colorScheme: const ColorScheme.light(
              primary: ThemeConfig.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.primaryColor,
              ),
            ),
          );
  }

  /// Builds a dialog with consistent theming and transitions.
  Widget _buildDialog({required Widget content}) {
    return Theme(
      data: _buildDialogTheme(),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _isDarkTheme ? ThemeConfig.darkCardColor : ThemeConfig.lightCardColor,
        child: FractionallySizedBox(
          widthFactor: 0.9,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ),
      ),
    );
  }

  /// Shows dialog to add a new task.
  void _showAddTaskDialog() {
    final dialogState = {
      'title': '',
      'description': '',
      'notes': '',
      'priority': 'low',
      'category': null as String?,
      'dueDate': null as tz.TZDateTime?,
      'isValid': true,
    };

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: ThemeConfig.dialogAnimationDuration,
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildDialog(
              content: _buildAddTaskDialogContent(setDialogState, dialogState),
            );
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }


  /// Builds content for the Add Task dialog.
  Widget _buildAddTaskDialogContent(StateSetter setDialogState, Map<String, dynamic> dialogState) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Add Task',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Task Title',
            onChanged: (value) => setDialogState(() {
              dialogState['title'] = value;
              debugPrint('Title: $value');
            }),
            maxLength: 50,
            isRequired: true,
            isValid: dialogState['isValid'] || (dialogState['title'] as String).isNotEmpty,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Description',
            onChanged: (value) => setDialogState(() {
              dialogState['description'] = value;
              debugPrint('Description: $value');
            }),
            maxLines: 3,
            isRequired: true,
            isValid: dialogState['isValid'] || (dialogState['description'] as String).isNotEmpty,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Notes',
            onChanged: (value) => setDialogState(() {
              dialogState['notes'] = value;
              debugPrint('Notes: $value');
            }),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Select Due Date and Time',
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              title: Text(
                dialogState['dueDate'] != null
                    ? DateFormat.yMd().add_jm().format(dialogState['dueDate'] as DateTime)
                    : 'Select Due Date & Time',
                style: GoogleFonts.poppins(
                  color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              trailing: const Icon(Icons.calendar_today, color: ThemeConfig.primaryColor, size: 24),
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')),
                  firstDate: tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')),
                  lastDate: tz.TZDateTime(tz.getLocation('Asia/Kolkata'), 2100),
                  builder: (context, child) => Theme(
                    data: _buildDialogTheme(),
                    child: child!,
                  ),
                );
                if (selectedDate != null) {
                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) => Theme(
                      data: _buildDialogTheme(),
                      child: child!,
                    ),
                  );
                  if (selectedTime != null) {
                    final dueDate = tz.TZDateTime(
                      tz.getLocation('Asia/Kolkata'),
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    if (dueDate.isBefore(tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')))) {
                      showSnackBar('Due date must be in the future');
                      debugPrint('Invalid dueDate: $dueDate is in the past');
                      return;
                    }
                    setDialogState(() {
                      dialogState['dueDate'] = dueDate;
                    });
                    setState(() {}); // Force dialog UI refresh
                    debugPrint('Set due date: $dueDate');
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Priority',
            value: dialogState['priority'],
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'high', child: Text('High')),
            ],
            onChanged: (value) => setDialogState(() {
              dialogState['priority'] = value;
              debugPrint('Priority: $value');
            }),
            fillColor: dialogState['priority'] == 'high'
                ? ThemeConfig.highPriorityColor.withOpacity(0.2)
                : ThemeConfig.lowPriorityColor.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Category',
            value: dialogState['category'],
            items: const [
              DropdownMenuItem(value: null, child: Text('None')),
              DropdownMenuItem(value: 'Work', child: Text('Work')),
              DropdownMenuItem(value: 'Personal', child: Text('Personal')),
              DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
            ],
            onChanged: (value) => setDialogState(() {
              dialogState['category'] = value;
              debugPrint('Category: $value');
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Cancel adding task',
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    debugPrint('Add cancelled');
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? ThemeConfig.buttonSecondaryColor : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Add task',
                child: ElevatedButton(
                  onPressed: () {
                    if (dialogState['title'].trim().isEmpty || dialogState['description'].trim().isEmpty) {
                      setDialogState(() {
                        dialogState['isValid'] = false;
                      });
                      debugPrint('Validation failed: title or description empty');
                      return;
                    }
                    final newTask = Task(
                      id: const Uuid().v4(),
                      title: dialogState['title'],
                      description: dialogState['description'],
                      notes: dialogState['notes'],
                      priority: dialogState['priority'],
                      createdTime: DateFormat('hh:mm a').format(tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'))),
                      createdDate: tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')).toIso8601String(),
                      dueDate: dialogState['dueDate'] != null ? (dialogState['dueDate'] as tz.TZDateTime).toUtc().toIso8601String() : null,
                      category: dialogState['category'],
                    );
                    debugPrint('Task created: ${newTask.title}, dueDate: ${newTask.dueDate}');
                    _addTask(newTask);
                    Navigator.pop(context);
                    debugPrint('Task added: ${newTask.title}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text('Add', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows dialog to edit an existing task.
  void _showEditTaskDialog(int index) {
    final task = _tasks[index];
    final dialogState = {
      'index': index,
      'title': task.title,
      'description': task.description,
      'notes': task.notes,
      'priority': task.priority,
      'category': task.category,
      'dueDate': task.dueDate != null ? tz.TZDateTime.from(DateTime.parse(task.dueDate!), tz.getLocation('Asia/Kolkata')) : null as tz.TZDateTime?,
      'isValid': true,
    };
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: ThemeConfig.dialogAnimationDuration,
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildDialog(
              content: _buildEditTaskDialogContent(setDialogState, dialogState),
            );
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }

  /// Builds content for the Edit Task dialog.
  Widget _buildEditTaskDialogContent(StateSetter setDialogState, Map<String, dynamic> dialogState) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Edit Task',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Task Title',
            initialValue: dialogState['title'],
            onChanged: (value) => setDialogState(() {
              dialogState['title'] = value;
              debugPrint('Title: $value');
            }),
            maxLength: 50,
            isRequired: true,
            isValid: dialogState['isValid'] || (dialogState['title'] as String).isNotEmpty,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Description',
            initialValue: dialogState['description'],
            onChanged: (value) => setDialogState(() {
              dialogState['description'] = value;
              debugPrint('Description: $value');
            }),
            maxLines: 3,
            isRequired: true,
            isValid: dialogState['isValid'] || (dialogState['description'] as String).isNotEmpty,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Notes',
            initialValue: dialogState['notes'],
            onChanged: (value) => setDialogState(() {
              dialogState['notes'] = value;
              debugPrint('Notes: $value');
            }),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Select Due Date and Time',
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              title: Text(
                dialogState['dueDate'] != null
                    ? DateFormat.yMd().add_jm().format(dialogState['dueDate'] as DateTime)
                    : 'Select Due Date & Time',
                style: GoogleFonts.poppins(
                  color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              trailing: const Icon(Icons.calendar_today, color: ThemeConfig.primaryColor, size: 24),
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: dialogState['dueDate'] ?? tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')),
                  firstDate: tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')),
                  lastDate: tz.TZDateTime(tz.getLocation('Asia/Kolkata'), 2100),
                  builder: (context, child) => Theme(
                    data: _buildDialogTheme(),
                    child: child!,
                  ),
                );
                if (selectedDate != null) {
                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: dialogState['dueDate'] != null
                        ? TimeOfDay.fromDateTime(dialogState['dueDate'] as DateTime)
                        : TimeOfDay.now(),
                    builder: (context, child) => Theme(
                      data: _buildDialogTheme(),
                      child: child!,
                    ),
                  );
                  if (selectedTime != null) {
                    final dueDate = tz.TZDateTime(
                      tz.getLocation('Asia/Kolkata'),
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    if (dueDate.isBefore(tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')))) {
                      showSnackBar('Due date must be in the future');
                      debugPrint('Invalid dueDate: $dueDate is in the past');
                      return;
                    }
                    setDialogState(() {
                      dialogState['dueDate'] = dueDate;
                    });
                    setState(() {}); // Force dialog UI refresh
                    debugPrint('Set due date: $dueDate');
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Priority',
            value: dialogState['priority'],
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'high', child: Text('High')),
            ],
            onChanged: (value) => setDialogState(() {
              dialogState['priority'] = value;
              debugPrint('Priority: $value');
            }),
            fillColor: dialogState['priority'] == 'high'
                ? ThemeConfig.highPriorityColor.withOpacity(0.2)
                : ThemeConfig.lowPriorityColor.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Category',
            value: dialogState['category'],
            items: const [
              DropdownMenuItem(value: null, child: Text('None')),
              DropdownMenuItem(value: 'Work', child: Text('Work')),
              DropdownMenuItem(value: 'Personal', child: Text('Personal')),
              DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
            ],
            onChanged: (value) => setDialogState(() {
              dialogState['category'] = value;
              debugPrint('Category: $value');
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Cancel editing task',
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    debugPrint('Edit cancelled');
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? ThemeConfig.buttonSecondaryColor : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Save task',
                child: ElevatedButton(
                  onPressed: () {
                    if (dialogState['title'].trim().isEmpty || dialogState['description'].trim().isEmpty) {
                      setDialogState(() {
                        dialogState['isValid'] = false;
                      });
                      debugPrint('Validation failed: title or description empty');
                      return;
                    }
                    final updatedTask = Task(
                      id: _tasks[dialogState['index']].id,
                      title: dialogState['title'],
                      description: dialogState['description'],
                      notes: dialogState['notes'],
                      isComplete: _tasks[dialogState['index']].isComplete,
                      priority: dialogState['priority'],
                      createdTime: _tasks[dialogState['index']].createdTime,
                      createdDate: _tasks[dialogState['index']].createdDate,
                      dueDate: dialogState['dueDate'] != null ? (dialogState['dueDate'] as tz.TZDateTime).toUtc().toIso8601String() : null,
                      category: dialogState['category'],
                    );
                    debugPrint('Task updated: ${updatedTask.title}, dueDate: ${updatedTask.dueDate}');
                    _editTask(dialogState['index'], updatedTask);
                    Navigator.pop(context);
                    debugPrint('Task saved: ${updatedTask.title}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds content for the Task Details dialog.
  Widget _buildTaskDetailsContent(int index) {
    final task = _tasks[index];
    final dueDate = task.dueDate != null ? DateTime.parse(task.dueDate!) : null;
    final dueDateIst = dueDate != null ? tz.TZDateTime.from(dueDate, tz.getLocation('Asia/Kolkata')) : null;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Details',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Task: ${task.title}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Description: ${task.description ?? 'None'}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Notes: ${task.notes != null && task.notes!.isNotEmpty ? task.notes : 'None'}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Priority: ${task.priority?.capitalize() ?? 'None'}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: task.priority == 'high' ? ThemeConfig.highPriorityColor : ThemeConfig.lowPriorityColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Due Date: ${dueDateIst != null ? DateFormat.yMMMMd().add_jm().format(dueDateIst) : 'N/A'}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Category: ${task.category ?? 'None'}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Created: ${task.createdTime}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 18,
            children: [
              Semantics(
                label: 'Edit task',
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditTaskDialog(index);
                    debugPrint('Edit from details');
                  },
                  child: Text(
                    'Edit',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? ThemeConfig.buttonSecondaryColor : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: 'Delete task',
                child: TextButton(
                  onPressed: () {
                    _deleteTask(index);
                    Navigator.pop(context);
                    debugPrint('Deleted from details: ${task.title}');
                  },
                  child: Text(
                    'Delete',
                    style: GoogleFonts.poppins(
                      color: ThemeConfig.secondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: 'Share task',
                child: TextButton(
                  onPressed: () {
                    _shareTask(task);
                    debugPrint('Shared from details: ${task.title}');
                  },
                  child: Text(
                    'Share',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? ThemeConfig.buttonSecondaryColor : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: 'Close details',
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    debugPrint('Details closed');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows task details dialog.
  void _showTaskDetails(int index) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: ThemeConfig.dialogAnimationDuration,
      pageBuilder: (context, anim1, anim2) {
        return _buildDialog(content: _buildTaskDetailsContent(index));
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }

  /// Builds a task card for the ReorderableListView.
  Widget _buildTaskCard(int index) {
    final task = filteredTasks[index];
    final dueDate = task.dueDate != null ? DateTime.parse(task.dueDate!) : null;
    final dueDateIst = dueDate != null ? tz.TZDateTime.from(dueDate, tz.getLocation('Asia/Kolkata')) : null;
    final isOverdue = dueDateIst != null && dueDateIst.isBefore(tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'))) && !task.isComplete;
    return Dismissible(
      key: ValueKey(task.id),
      background: Container(
        color: ThemeConfig.primaryColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'Edit',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      secondaryBackground: Container(
        color: ThemeConfig.secondaryColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'Delete',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
          if (taskIndex != -1) {
            setState(() {
              _deleteTask(taskIndex);
              debugPrint('Dismissed delete: ${task.title}');
            });
          }
        }
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
          if (taskIndex != -1) {
            _showEditTaskDialog(taskIndex);
            debugPrint('Dismissed edit: ${task.title}');
          }
          return false;
        }
        return await showDialog(
          context: context,
          builder: (context) => Theme(
            data: _buildDialogTheme(),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: _isDarkTheme ? ThemeConfig.darkCardColor : ThemeConfig.lightCardColor,
              title: Text(
                'Confirm Delete',
                style: GoogleFonts.poppins(
                  color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              content: Text(
                'Are you sure you want to delete "${task.title}"?',
                style: GoogleFonts.poppins(
                  color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
                  fontWeight: FontWeight.w400,
                ),
              ),
              actions: [
                Semantics(
                  label: 'Cancel deletion',
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: _isDarkTheme ? ThemeConfig.buttonSecondaryColor : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  label: 'Confirm deletion',
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        color: ThemeConfig.secondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Card(
        key: ValueKey(task.id),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isOverdue
              ? const BorderSide(color: ThemeConfig.secondaryColor, width: 2)
              : BorderSide(color: _isDarkTheme ? ThemeConfig.borderColor : Colors.transparent),
        ),
        elevation: 4,
        color: task.priority == 'high'
            ? ThemeConfig.highPriorityColor.withOpacity(0.2)
            : _isDarkTheme
                ? ThemeConfig.darkCardColor
                : ThemeConfig.lightCardColor,
        child: Semantics(
          label: 'Task ${task.title}',
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Checkbox(
              value: task.isComplete,
              onChanged: (value) {
                final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
                if (taskIndex != -1) {
                  _toggleTaskCompletion(taskIndex);
                  debugPrint('Toggled: ${task.title}');
                }
              },
              activeColor: ThemeConfig.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            title: Text(
              task.title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: _isDarkTheme ? ThemeConfig.primaryTextColor : Colors.black87,
                fontWeight: FontWeight.w600,
                decoration: task.isComplete ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.description ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dueDateIst != null)
                  Text(
                    'Due: ${DateFormat.yMMMMd().add_jm().format(dueDateIst)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isOverdue ? ThemeConfig.secondaryColor : (_isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                if (task.category != null)
                  Text(
                    'Category: ${task.category}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline, color: ThemeConfig.primaryColor),
              tooltip: 'View task details',
              onPressed: () {
                final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
                if (taskIndex != -1) {
                  _showTaskDetails(taskIndex);
                  debugPrint('Details: ${task.title}');
                }
              },
            ),
            onTap: () {
              final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
              if (taskIndex != -1) {
                _showTaskDetails(taskIndex);
                debugPrint('Tapped: ${task.title}');
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building HomeScreen, tasks=${_tasks.length}');
    return Theme(
      data: _isDarkTheme
          ? ThemeData.dark().copyWith(
              primaryColor: ThemeConfig.primaryColor,
              scaffoldBackgroundColor: ThemeConfig.darkBackground,
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
                bodyColor: ThemeConfig.primaryTextColor,
                displayColor: ThemeConfig.primaryTextColor,
              ),
              cardColor: ThemeConfig.darkCardColor,
              appBarTheme: const AppBarTheme(
                backgroundColor: ThemeConfig.primaryColor,
                elevation: 0,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          : ThemeData.light().copyWith(
              primaryColor: ThemeConfig.primaryColor,
              scaffoldBackgroundColor: ThemeConfig.lightBackground,
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
                bodyColor: Colors.black87,
                displayColor: Colors.black87,
              ),
              cardColor: ThemeConfig.lightCardColor,
              appBarTheme: const AppBarTheme(
                backgroundColor: ThemeConfig.primaryColor,
                elevation: 0,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
      child: Scaffold(
        backgroundColor: _isDarkTheme ? ThemeConfig.darkBackground : ThemeConfig.lightBackground,
        appBar: AppBar(
          backgroundColor: ThemeConfig.primaryColor,
          elevation: 0,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/image/logo.png',
                  height: 40,
                  width: 40,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Failed to load logo.png: $error');
                    return const Icon(Icons.error, color: Colors.white);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'To-Do List',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            DropdownButton<String>(
              value: _sortBy,
              items: const [
                DropdownMenuItem(value: 'DueDate', child: Text('Due Date')),
                DropdownMenuItem(value: 'Priority', child: Text('Priority')),
              ],
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _cachedFilteredTasks = null;
                  debugPrint('Sort: $value');
                });
              },
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.sort, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: 'Toggle theme',
              child: IconButton(
                icon: Icon(
                  _isDarkTheme ? Icons.wb_sunny : Icons.nightlight_round,
                  color: Colors.white,
                ),
                tooltip: 'Toggle theme',
                onPressed: () {
                  setState(() {
                    _isDarkTheme = !_isDarkTheme;
                    debugPrint('Theme: ${_isDarkTheme ? 'Dark' : 'Light'}');
                  });
                  _saveTasks();
                },
              ),
            ),
            Semantics(
              label: 'Open settings',
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: 'Open settings',
                onPressed: () {
                  showSnackBar('Open device settings');
                  debugPrint('Settings opened');
                }
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: _buildDropdown(
                            label: 'Completion',
                            value: _filterCompletion,
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All')),
                              DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                              DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'Overdue', child: Text('Overdue')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filterCompletion = value!;
                                _cachedFilteredTasks = null;
                                debugPrint('Filter completion: $value');
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 140,
                          child: _buildDropdown(
                            label: 'Priority',
                            value: _filterPriority,
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All')),
                              DropdownMenuItem(value: 'high', child: Text('High')),
                              DropdownMenuItem(value: 'low', child: Text('Low')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filterPriority = value!;
                                _cachedFilteredTasks = null;
                                debugPrint('Filter priority: $value');
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 140,
                          child: _buildDropdown(
                            label: 'Category',
                            value: _filterCategory,
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All')),
                              DropdownMenuItem(value: 'Work', child: Text('Work')),
                              DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                              DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filterCategory = value!;
                                _cachedFilteredTasks = null;
                                debugPrint('Filter category: $value');
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTextField(
                    label: 'Search tasks',
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(ThemeConfig.debounceDuration, () {
                        setState(() {
                          _searchQuery = value;
                          _cachedFilteredTasks = null;
                          debugPrint('Search: $value');
                        });
                      });
                    },
                    maxLength: 50,
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: ThemeConfig.primaryColor))
                      : filteredTasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _tasks.isEmpty ? 'Yet to Add Tasks' : 'No tasks found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: _isDarkTheme ? ThemeConfig.secondaryTextColor : Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  // const SizedBox(height: 16),
                                  // Semantics(
                                  //   label: 'Test notification',
                                  //   child: ElevatedButton(
                                  //     onPressed: () async {
                                  //       await _notificationService.showTestNotification();
                                  //       showSnackBar('Test notification sent');
                                  //       debugPrint('Test notification triggered');
                                  //     },
                                  //     style: ElevatedButton.styleFrom(
                                  //       backgroundColor: ThemeConfig.primaryColor,
                                  //       foregroundColor: Colors.white,
                                  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  //     ),
                                  //     child: Text('Test Notification', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                  //   ),
                                  // ),
                                ],
                              ),
                            )
                          : ReorderableListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredTasks.length,
                              itemBuilder: (context, index) => _buildTaskCard(index),
                              onReorder: (oldIndex, newIndex) async {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex--;
                                  final task = filteredTasks.removeAt(oldIndex);
                                  filteredTasks.insert(newIndex, task);
                                  final reorderedTasks = <Task>[];
                                  final filteredIds = filteredTasks.map((t) => t.id).toList();
                                  reorderedTasks.addAll(filteredTasks);
                                  reorderedTasks.addAll(_tasks.where((t) => !filteredIds.contains(t.id)));
                                  _tasks = reorderedTasks;
                                  _cachedFilteredTasks = null;
                                  debugPrint('Reordered task: ${task.title} from $oldIndex to $newIndex');
                                });
                                await _saveTasks();
                                if (await Vibration.hasVibrator() ?? false) {
                                  Vibration.vibrate(duration: 100);
                                }
                              },
                            ),
                ),
              ],
            ),
            if (_showCelebration)
              SizedBox.expand(
                child: Lottie.asset(
                  'assets/animations/confetti.json',
                  controller: _lottieController,
                  fit: BoxFit.fill,
                  onLoaded: (composition) {
                    _lottieController
                      ..duration = composition.duration
                      ..forward().whenComplete(() {
                          if (mounted) {
                            setState(() {
                              _showCelebration = false;
                              debugPrint('Celebration animation completed');
                            });
                          }
                        });
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Failed to load confetti.json: $error');
                  debugPrint('Failed to show celebration animation');
                    return const SizedBox();
                  },
                ),
              ),
          ],
        ),
        floatingActionButton: Semantics(
          label: 'Add new task',
          child: FloatingActionButton(
            onPressed: _showAddTaskDialog,
            backgroundColor: ThemeConfig.primaryColor,
            tooltip: 'Add new task',
            child: const Icon(Icons.add, size: 30, color: Colors.white),
          ),
        ),
      )
    );
  }
}