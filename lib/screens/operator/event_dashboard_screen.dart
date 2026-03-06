import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'collect_moi_screen.dart';
import 'correct_village_name.dart';
import 'uncle_reorder_screen.dart';
import 'denomination_screen.dart';
import 'user_wise_collection.dart';
import 'similar_entries_screen.dart';
import 'double_entries_screen.dart';
import 'modified_report_screen.dart';
import 'cash_managements_screen.dart';
import '../../services/receipt_generator.dart';
import 'package:printing/printing.dart';
import '../../services/final_moi_report_screen.dart';
import '../../utils/network_utils.dart';
import '../../services/session_manager.dart'; // ✅ ADD THIS
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../../services/thermal_printer_service.dart';
import 'dart:async';

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({super.key});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  Map<String, dynamic>? eventData;
  String operatorName = '';
  String? operatorId;
  bool _isAdminView = false;
  int _noOfDownloads = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        eventData = args;
        operatorName = args['_operator_name'] ?? '';
        operatorId = args['_operator_id'];
        _isAdminView = args['_is_admin_view'] == true;
        _noOfDownloads = args['no_of_downloads'] ?? 0;
      });

      // ✅ DEBUG: Print session info
      _debugPrintSessionInfo();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
        if (details.payload != null) {
          await OpenFile.open(details.payload);
        }
      },
    );

    // Request notification permission for Android 13+
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need different permissions
      if (await Permission.photos.isGranted ||
          await Permission.videos.isGranted ||
          await Permission.audio.isGranted) {
        return true;
      }

      if (Platform.isAndroid) {
        // For Android 13+ (API 33+)
        final photoStatus = await Permission.photos.request();
        if (photoStatus.isGranted) return true;
      }

      // For Android 11-12
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return true;

      // For Android 10 and below
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  Future<void> _showDownloadNotification(String fileName, String folderPath) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'File download notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        'Tap to open the folder',
        contentTitle: 'Download Complete',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Download Complete',
      fileName,
      notificationDetails,
      payload: folderPath,
    );
  }

  /// ✅ UPDATED: Check authentication from SharedPreferences too
  Future<bool> _ensureAuthenticated() async {
    var session = Supabase.instance.client.auth.currentSession;
    var authToken = session?.accessToken;

    // If no Supabase session, try SharedPreferences
    if (authToken == null || authToken.isEmpty) {
      print('⚠️ No Supabase session, checking SharedPreferences...');
      authToken = await SessionManager.getStoredAuthToken();
    }

    if (authToken == null || authToken.isEmpty) {
      print('❌ NO AUTH TOKEN FOUND - User not authenticated');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text('Your session has expired. Please login again.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                        (route) => false,
                  );
                },
                child: const Text('Login Again'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    print('✅ SESSION VALID - Token present');
    return true;
  }

  /// ✅ NEW: Debug method to print session info
  void _debugPrintSessionInfo() {
    final session = Supabase.instance.client.auth.currentSession;
    print('📱 ===== SESSION DEBUG INFO =====');
    print('📱 Session exists: ${session != null}');
    if (session != null) {
      print('📱 User ID: ${session.user.id}');
      print('📱 Email: ${session.user.email}');
      print('📱 Token exists: ${session.accessToken != null}');
      print('📱 Token length: ${session.accessToken?.length ?? 0}');
      print('📱 Expires at: ${session.expiresAt}');
    }
    print('📱 ===============================');
  }

  /// ✅ UPDATED: Get auth headers with token AND event_id
  /// First tries Supabase session, then falls back to SharedPreferences
  Future<Map<String, String>> _getAuthHeaders() async {
    // First, try to get token from Supabase session
    var authToken = Supabase.instance.client.auth.currentSession?.accessToken;

    // If no Supabase session, get from SharedPreferences
    if (authToken == null || authToken.isEmpty) {
      print('⚠️ No Supabase session, trying SharedPreferences...');
      authToken = await SessionManager.getStoredAuthToken();

      if (authToken != null) {
        print('✅ Auth token restored from SharedPreferences');
      }
    }

    final eventId = eventData?['id'];

    final headers = {
      'Content-Type': 'application/json',
    };

    // ✅ ADD EVENT_ID TO HEADERS
    if (eventId != null) {
      headers['X-Event-ID'] = eventId.toString();
      print('✅ Added Event ID to header: $eventId');
    }

    // ✅ ADD AUTHORIZATION TOKEN
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
      print('✅ Added Auth token to header');
    } else {
      print('❌ WARNING: No auth token available!');
    }

    print('📋 Headers being sent: ${headers.keys.toList()}');
    return headers;
  }

  /// Fetches the file tree structure from the cloud endpoint (receipts_list only)
  Future<Map<String, dynamic>> _fetchFileTree() async {
    final eventId = eventData!['id'];

    print('🌳 Fetching file tree for event: $eventId');

    // ✅ Get auth headers (includes token AND event_id)
    final headers = await _getAuthHeaders();

    // Only call receipts_list endpoint
    final response = await http.post(
      Uri.parse(
          'https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/receipts_list'),
      headers: headers,
      body: json.encode({'event_id': eventId}),
    );

    print('🌳 Response status: ${response.statusCode}');
    print('🌳 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('🌳 File tree fetched successfully');
      return data['tree'] ?? {};
    } else {
      print('🌳 Error: ${response.body}');
      throw Exception(
          'Failed to fetch file tree: ${response.statusCode} - ${response.body}');
    }
  }

  /// ✅ Downloads a single file with auth headers
  Future<void> _downloadFile(
      String fileUrl,
      String destinationPath,
      Map<String, String> authHeaders,
      ) async {
    try {
      final response = await http.get(
        Uri.parse(fileUrl),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final file = File(destinationPath);
        await file.writeAsBytes(response.bodyBytes);
        print('✅ Downloaded: $destinationPath');
      } else {
        throw Exception(
            'Failed to download file: ${response.statusCode} - $fileUrl');
      }
    } catch (e) {
      print('❌ Error downloading file: $e');
      rethrow;
    }
  }

  /// Recursively processes the file tree and downloads all files
  Future<void> _processFileTree(
      Map<String, dynamic> tree,
      String baseDir,
      List<Map<String, dynamic>> downloadTasks,
      ) async {
    for (final key in tree.keys) {
      final item = tree[key];

      if (item['type'] == 'folder') {
        // Create folder directory
        final folderPath = '$baseDir/$key';
        final folder = Directory(folderPath);

        if (!await folder.exists()) {
          await folder.create(recursive: true);
          print('📁 Created folder: $folderPath');
        }

        // Recursively process children
        if (item['children'] != null) {
          await _processFileTree(item['children'], folderPath, downloadTasks);
        }
      } else if (item['type'] == 'file') {
        // Add file to download queue
        downloadTasks.add({
          'url': item['url'],
          'path': '$baseDir/$key',
          'name': key,
        });
      }
    }
  }

  /// ✅ Downloads multiple files concurrently with auth
  Future<void> _downloadFilesParallel(
      List<Map<String, dynamic>> downloadTasks,
      Map<String, String> authHeaders,
      {
        int maxConcurrent = 5,
      }) async {
    print('📥 Starting parallel downloads: ${downloadTasks.length} files');

    // Create chunks of tasks to download concurrently
    for (int i = 0; i < downloadTasks.length; i += maxConcurrent) {
      final chunk = downloadTasks.sublist(
        i,
        (i + maxConcurrent > downloadTasks.length)
            ? downloadTasks.length
            : i + maxConcurrent,
      );

      // Download all files in this chunk in parallel
      await Future.wait(
        chunk.map((task) => _downloadFile(
          task['url'],
          task['path'],
          authHeaders,
        )),
        eagerError: true,
      );

      print('📥 Completed chunk ${(i ~/ maxConcurrent) + 1}');
    }

    print('📥 All files downloaded successfully');
  }

  Future<void> _downloadReceipts() async {
    // ✅ STEP 0: Check if user is authenticated
    if (!await _ensureAuthenticated()) {
      return; // User will be redirected to login
    }

    // Step 1: Request storage permission
    if (!await _requestStoragePermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to download files'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Step 2: Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final eventId = eventData!['id'];
      final eventTitle = eventData!['title'];

      print('📥 ========== DOWNLOAD STARTED ==========');
      print('📥 Event ID: $eventId');
      print('📥 Event Title: $eventTitle');

      // ✅ Get auth headers (which now includes event_id)
      final authHeaders = await _getAuthHeaders();
      print('📥 Auth Headers: $authHeaders');

      // Step 3: Fetch file tree structure
      final fileTree = await _fetchFileTree();

      // Step 4: Prepare download directory
      String? saveDirPath;

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        if (downloadsDir == null) {
          throw Exception('Cannot access storage directory');
        }

        final eventFolder = Directory('${downloadsDir.path}/receipts');
        if (!await eventFolder.exists()) {
          await eventFolder.create(recursive: true);
        }

        saveDirPath = eventFolder.path;

        print('✅ Save directory: $saveDirPath');
      } else if (Platform.isIOS) {
        final appDir = await getApplicationDocumentsDirectory();
        final eventFolder = Directory('${appDir.path}/receipts');
        if (!await eventFolder.exists()) {
          await eventFolder.create(recursive: true);
        }

        saveDirPath = eventFolder.path;

        print('✅ Save directory: $saveDirPath');
      }

      // Step 5: Build list of download tasks
      final List<Map<String, dynamic>> downloadTasks = [];
      await _processFileTree(fileTree, saveDirPath!, downloadTasks);

      if (downloadTasks.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ No files to download'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('📥 Total files to download: ${downloadTasks.length}');

      // Step 6: Download all files with parallel execution and auth headers
      await _downloadFilesParallel(
        downloadTasks,
        authHeaders,
        maxConcurrent: 5,
      );

      // Step 7: Close loading dialog
      if (mounted) Navigator.pop(context);

      // Step 8: Update download count in database
      await Supabase.instance.client
          .from('events')
          .update({
        'no_of_downloads': _noOfDownloads + 1,
      }).eq('id', eventId);

      // Step 9: Update local state
      setState(() {
        _noOfDownloads += 1;
        if (eventData != null) {
          eventData!['no_of_downloads'] = _noOfDownloads;
        }
      });

      // Step 10: Show notification and success message
      if (saveDirPath != null) {
        await _showDownloadNotification('All receipts', saveDirPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ ${downloadTasks.length} files downloaded successfully\nLocation: $eventTitle'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () async {
                  final result = await OpenFile.open(saveDirPath);
                  print('Open folder result: ${result.message}');

                  if (result.type == ResultType.noAppToOpen) {
                    if (mounted && saveDirPath != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Folder location: $saveDirPath'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 7),
                          action: SnackBarAction(
                            label: 'COPY PATH',
                            textColor: Colors.white,
                            onPressed: () {
                              if (saveDirPath != null) {
                                Clipboard.setData(
                                    ClipboardData(text: saveDirPath));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Path copied to clipboard')),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
      }

      print('📥 =====================================');
    } catch (e) {
      print('❌ Error downloading receipts: $e');

      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading receipts: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _downloadReceipts,
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteReceipts() async {
    // ✅ Check authentication first
    if (!await _ensureAuthenticated()) {
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipts'),
        content: const Text(
          'Are you sure you want to delete all receipts for this event? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final eventId = eventData!['id'];

      print('🗑️ ========== DELETE STARTED ==========');
      print('🗑️ Event ID: $eventId');

      // ✅ Get auth headers
      final authHeaders = await _getAuthHeaders();
      print('🗑️ Auth token present: ${authHeaders.containsKey('Authorization')}');

      // Make DELETE request to the API
      final response = await http.delete(
        Uri.parse(
            'https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/delete_receipts'),
        headers: authHeaders,
        body: json.encode({
          'event_id': eventId,
        }),
      );

      print('🗑️ Response status: ${response.statusCode}');
      print('🗑️ Response body: ${response.body}');
      print('🗑️ =====================================');

      if (mounted) Navigator.pop(context);

      // Check for success (200-299 status codes)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Reset the download count in the database
        await Supabase.instance.client
            .from('events')
            .update({
          'no_of_downloads': 0,
        }).eq('id', eventId);

        // Update local state
        setState(() {
          _noOfDownloads = 0;
          if (eventData != null) {
            eventData!['no_of_downloads'] = 0;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Receipts deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Parse error message from response
        String errorMessage =
            'Failed to delete receipts (Status: ${response.statusCode})';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody['error'] != null) {
            errorMessage = errorBody['error'];
          } else if (errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          }
        } catch (e) {
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error deleting receipts: $e');

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting receipts: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _deleteReceipts,
            ),
          ),
        );
      }
    }
  }

  void _showExportReceiptsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Receipts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_noOfDownloads > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Downloads: $_noOfDownloads',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _downloadReceipts();
              },
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8F8F8F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _noOfDownloads >= 1
                  ? () {
                Navigator.pop(context);
                _deleteReceipts();
              }
                  : null,
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    if (eventData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Event Dashboard'),
        ),
        body: const Center(
          child: Text('No event data available'),
        ),
      );
    }

    final eventTypeName = eventData!['event_types']?['name'] ?? 'N/A';
    final title = eventData!['title'] ?? 'N/A';
    final venue = eventData!['venue'] ?? 'N/A';
    final city = eventData!['city'] ?? 'N/A';
    final eventDate = _formatDate(eventData!['event_date']);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hi Tech Moi',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dashboard Header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Event Details
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eventTypeName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    city,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Operator : $operatorName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Section
                  const Text(
                    'Transaction',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Collect Moi', Icons.add, () {
                          final eventDataWithOperator =
                          Map<String, dynamic>.from(eventData!);
                          eventDataWithOperator['operator_id'] = operatorId;
                          eventDataWithOperator['skip_denomination'] =
                              eventData!['skip_denomination'] ?? false;
                          eventDataWithOperator['skip_print'] =
                              eventData!['skip_print'] ?? false;
                          eventDataWithOperator['skip_whatsapp'] =
                              eventData!['skip_whatsapp'] ?? false;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const CollectMoiScreen(),
                              settings: RouteSettings(
                                  arguments: eventDataWithOperator),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton('Collection Details',
                            Icons.person, () {
                              final eventDataWithOperator =
                              Map<String, dynamic>.from(eventData!);
                              eventDataWithOperator['operator_id'] = operatorId;

                              Navigator.pushNamed(
                                context,
                                '/operator/collection-details',
                                arguments: eventDataWithOperator,
                              );
                            }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Cash Withdrawal',
                            Icons.money_off, () {
                              Navigator.pushNamed(
                                context,
                                '/operator/cash_withdrawal',
                                arguments: {
                                  'id': eventData!['id'],
                                  'operator_id': operatorId
                                },
                              );
                            }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                        _buildGridButton('Exchange Deno', Icons.swap_horiz,
                                () {
                              Navigator.pushNamed(
                                context,
                                '/operator/exchange-denomination',
                                arguments: {
                                  'id': eventData!['id'],
                                  'operator_id': operatorId
                                },
                              );
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Uncle Re-order',
                            Icons.sort_by_alpha, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const UncleReorderScreen(),
                                  settings: RouteSettings(arguments: eventData),
                                ),
                              );
                            }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton('Correct Village',
                            Icons.location_city, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CorrectVillageNamesScreen(
                                          eventId: eventData!['id']),
                                ),
                              );
                            }),
                      ),
                    ],
                  ),
                  if (_isAdminView) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGridButton('Correct Person',
                              Icons.person_search, () {
                                Navigator.pushNamed(
                                  context,
                                  '/admin/correct-person-data',
                                  arguments: {
                                    'event_id': eventData!['id'],
                                    'operator_id': operatorId,
                                  },
                                );
                              }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Report Section
                  const Text(
                    'Report',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Similar Entries',
                            Icons.content_copy, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SimilarEntriesScreen(
                                    eventId: eventData!['id'],
                                  ),
                                ),
                              );
                            }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton('Cash Deno',
                            Icons.currency_rupee, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DenominationScreen(
                                    eventId: eventData!['id'],
                                  ),
                                ),
                              );
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Double Entries',
                            Icons.filter_2, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DoubleEntriesScreen(
                                    eventId: eventData!['id'],
                                  ),
                                ),
                              );
                            }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton('User Wise', Icons.group, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserWiseCollectionScreen(
                                    eventId: eventData!['id'],
                                  ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Cash Management',
                            Icons.account_balance_wallet, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CashManagementScreen(
                                    eventId: eventData!['id'],
                                    operatorId: operatorId,
                                  ),
                                ),
                              );
                            }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridButton('Modified Report',
                            Icons.edit_note, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ModifiedReportScreen(
                                    eventId: eventData!['id'],
                                  ),
                                ),
                              );
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Sample Receipt Button - Always visible
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridButton('Sample Receipt',
                            Icons.receipt, () {
                              _showSampleReceipt();
                            }),
                      ),
                      const SizedBox(width: 12),
                      // Final Moi Report Button - Only for Admin
                      if (_isAdminView)
                        Expanded(
                          child: _buildGridButton('Final Moi Report',
                              Icons.assessment, () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FinalMoiReportScreen(
                                          eventId: eventData!['id'],
                                        ),
                                  ),
                                );
                              }),
                        )
                      else
                        Expanded(
                          child: Container(),
                        ),
                    ],
                  ),
                  // Export Receipts Button - Only for Admin
                  if (_isAdminView) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGridButton('Export Receipts',
                              Icons.file_download, () {
                                _showExportReceiptsDialog();
                              }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridButton(String label, IconData icon, VoidCallback onPressed) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF8F8F8F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSampleReceipt() async {
    try {
      final eventTypeName = eventData!['event_types']?['name'] ?? 'Event';
      final customerName = eventData!['customer_name'] ?? 'N/A';
      final venue = eventData!['venue'] ?? 'N/A';
      final city = eventData!['city'] ?? 'N/A';
      final contactNumber = eventData!['customer_phone'] ?? '';

      DateTime eventDate;
      try {
        eventDate = DateTime.parse(eventData!['event_date']);
      } catch (e) {
        eventDate = DateTime.now();
      }

      TimeOfDay? eventTime;
      if (eventData!['event_time'] != null) {
        final timeParts = eventData!['event_time'].split(':');
        eventTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await ReceiptGenerator.generateReceiptPDFWithImage(
        context: context,
        customerName: customerName,
        venue: venue,
        city: city,
        contactNumber: contactNumber,
        eventTypeName: eventTypeName,
        selectedDate: eventDate,
        selectedTime: eventTime,
      );

      if (mounted) Navigator.pop(context);

      if (result != null && mounted) {
        final printerService = ThermalPrinterService();
        await printerService.connectAndPrintImage(context, result['imageBytes']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receipt sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate receipt'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _showSampleReceipt,
          customMessage: 'Error generating receipt',
        );
      }
    }
  }
}