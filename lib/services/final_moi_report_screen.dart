import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:supabase_flutter/supabase_flutter.dart';
import '/utils/constants.dart';
import '../screens/admin/cover_image_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moi_virunthu/utils/cover_image_helper.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdf/pdf.dart' as pdf_pkg;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart'; // Add this dependency


Future<bool> _requestStoragePermission() async {
  if (Platform.isAndroid) {
    // For Android 13+ (API 33+), we need different permissions
    if (await Permission.photos.isGranted ||
        await Permission.videos.isGranted ||
        await Permission.audio.isGranted) {
      return true;
    }

    // Check Android version
    final androidInfo = await Permission.storage.status;

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

class FinalMoiReportScreen extends StatefulWidget {
  final String eventId;

  const FinalMoiReportScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<FinalMoiReportScreen> createState() => _FinalMoiReportScreenState();
}

class _FinalMoiReportScreenState extends State<FinalMoiReportScreen> {
  bool _isLoading = false;
  String? _generatedContent;
  String? _selectedFormat;
  File? _generatedFile;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const _serverUrl =
      'https://agmwcgxssorjwiinpknr.supabase.co/functions/v1/report-generator';
  static const _authToken =
      'Bearer 65d9708252d6947d42e757bc7558acce87b52c2067ef5663e1dc0b29843b1e2a';

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher');
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

  Future<void> _showDownloadNotification(String fileName,
      String filePath) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'File download notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        'Tap to open the file',
        contentTitle: 'Download Complete',
      ),
      actions: [
        const AndroidNotificationAction(
          'open',
          'Open',
          showsUserInterface: true,
        ),
      ],
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
      DateTime
          .now()
          .millisecondsSinceEpoch ~/ 1000,
      'Download Complete',
      fileName,
      notificationDetails,
      payload: filePath,
    );
  }

  Future<void> _showProgressNotification(String fileName,
      double progress) async {
    final androidDetails = AndroidNotificationDetails(
      'download_progress_channel',
      'Download Progress',
      channelDescription: 'Shows download progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).toInt(),
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0, // Use fixed ID for progress updates
      'Downloading',
      fileName,
      notificationDetails,
    );
  }

  Future<void> _generateReport(String returnType) async {
    setState(() {
      _isLoading = true;
      _selectedFormat = returnType;
      _generatedContent = null;
      _generatedFile = null;
    });

    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: json.encode({
          'event_id': widget.eventId,
          'return_type': returnType,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }

      if (returnType == 'html' || returnType == 'txt') {
        setState(() {
          _generatedContent = response.body;
        });
      } else if (returnType == 'excel' || returnType == 'csv') {
        // Should be changed to:
        final out = await getTemporaryDirectory();
        final extension = 'csv';  // Since you want CSV for excel button
        final fname = 'final_moi_report_${DateTime.now().millisecondsSinceEpoch}.$extension';

        final file = File('${out.path}/$fname');
        await file.writeAsBytes(response.bodyBytes);
        setState(() => _generatedFile = file);
      } else if (returnType == 'pdf') {
        final base64Pdf = base64Encode(response.bodyBytes);
        setState(() {
          _generatedContent = base64Pdf;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadReport() async {
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
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      String? savedFileName;
      String? savedFilePath;

      if (_selectedFormat == 'excel' || _selectedFormat == 'csv') {
        if (_generatedFile != null) {
          final fileName = 'final_moi_report_${DateTime.now().millisecondsSinceEpoch}.csv';
          if (Platform.isAndroid) {
            final downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            final savedFile = File('${downloadsDir.path}/$fileName');

            await _showProgressNotification(fileName, 0.5);
            await _generatedFile!.copy(savedFile.path);

            savedFileName = fileName;
            savedFilePath = savedFile.path;
          } else if (Platform.isIOS) {
            final appDir = await getApplicationDocumentsDirectory();
            final savedFile = File('${appDir.path}/$fileName');
            await _generatedFile!.copy(savedFile.path);

            savedFileName = fileName;
            savedFilePath = savedFile.path;
          }
        }
      } else if (_selectedFormat == 'pdf' && _generatedContent != null) {
        await _showProgressNotification('Generating PDF...', 0.3);

        final serverPdfBytes = base64Decode(_generatedContent!);
        final mergedPdfBytes = await _createMergedPdfWithImageFirst(
            serverPdfBytes);

        await _showProgressNotification('Saving PDF...', 0.7);

        final fileName = 'final_moi_report_${DateTime
            .now()
            .millisecondsSinceEpoch}.pdf';

        if (Platform.isAndroid) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final outFile = File('${downloadsDir.path}/$fileName');

          if (mergedPdfBytes != null) {
            await outFile.writeAsBytes(mergedPdfBytes);
          } else {
            await outFile.writeAsBytes(serverPdfBytes);
          }

          savedFileName = fileName;
          savedFilePath = outFile.path;
        } else if (Platform.isIOS) {
          final appDir = await getApplicationDocumentsDirectory();
          final outFile = File('${appDir.path}/$fileName');

          if (mergedPdfBytes != null) {
            await outFile.writeAsBytes(mergedPdfBytes);
          } else {
            await outFile.writeAsBytes(serverPdfBytes);
          }

          savedFileName = fileName;
          savedFilePath = outFile.path;
        }
      } else if (_selectedFormat == 'html' && _generatedContent != null) {
        final mergedHtml = await _createMergedHtmlWithImageFirst(
            _generatedContent!);
        final fileName = 'final_moi_report_${DateTime
            .now()
            .millisecondsSinceEpoch}.html';

        if (Platform.isAndroid) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final file = File('${downloadsDir.path}/$fileName');
          await file.writeAsString(mergedHtml, flush: true);

          savedFileName = fileName;
          savedFilePath = file.path;
        } else if (Platform.isIOS) {
          final appDir = await getApplicationDocumentsDirectory();
          final file = File('${appDir.path}/$fileName');
          await file.writeAsString(mergedHtml, flush: true);

          savedFileName = fileName;
          savedFilePath = file.path;
        }
      } else if (_selectedFormat == 'txt' && _generatedContent != null) {
        final fileName = 'final_moi_report_${DateTime
            .now()
            .millisecondsSinceEpoch}.txt';

        if (Platform.isAndroid) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final file = File('${downloadsDir.path}/$fileName');
          await file.writeAsString(_generatedContent!);

          savedFileName = fileName;
          savedFilePath = file.path;
        } else if (Platform.isIOS) {
          final appDir = await getApplicationDocumentsDirectory();
          final file = File('${appDir.path}/$fileName');
          await file.writeAsString(_generatedContent!);

          savedFileName = fileName;
          savedFilePath = file.path;
        }
      }

      // Cancel progress notification
      await _notificationsPlugin.cancel(0);

      if (savedFileName != null && savedFilePath != null) {
        await _showDownloadNotification(savedFileName, savedFilePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'File downloaded: $savedFileName\nTap notification to open'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  await OpenFile.open(savedFilePath);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      await _notificationsPlugin.cancel(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _shareReport() async {
    try {
      setState(() => _isLoading = true);

      if (_selectedFormat == 'excel' || _selectedFormat == 'csv') {
        if (_generatedFile != null) {
          await Share.shareXFiles(
            [XFile(
              _generatedFile!.path,
              mimeType: 'text/csv',
              name: 'final_moi_report.${_selectedFormat}',
            )
            ],
            text: 'Final Moi Report',
          );
        }
      } else if (_selectedFormat == 'pdf' && _generatedContent != null) {
        final serverPdfBytes = base64Decode(_generatedContent!);
        final mergedPdfBytes = await _createMergedPdfWithImageFirst(
            serverPdfBytes);
        final output = await getTemporaryDirectory();
        final outPath = '${output.path}/final_moi_report_${DateTime
            .now()
            .millisecondsSinceEpoch}.pdf';
        final outFile = File(outPath);

        if (mergedPdfBytes != null) {
          await outFile.writeAsBytes(mergedPdfBytes);
        } else {
          await outFile.writeAsBytes(serverPdfBytes);
        }

        await Share.shareXFiles(
          [
            XFile(outFile.path, mimeType: 'application/pdf',
                name: 'final_moi_report.pdf')
          ],
          text: 'Final Moi Report',
        );
      } else if (_selectedFormat == 'html' && _generatedContent != null) {
        final html = _generatedContent!;
        final mergedHtml = await _createMergedHtmlWithImageFirst(html);
        final output = await getTemporaryDirectory();
        final outPath = '${output.path}/final_moi_report_${DateTime
            .now()
            .millisecondsSinceEpoch}.html';
        final file = File(outPath);
        await file.writeAsString(mergedHtml, flush: true);

        await Share.shareXFiles(
          [
            XFile(
                file.path, mimeType: 'text/html', name: 'final_moi_report.html')
          ],
          text: 'Final Moi Report',
        );
      } else if (_selectedFormat == 'txt' && _generatedContent != null) {
        final output = await getTemporaryDirectory();
        final outPath = '${output.path}/final_moi_report_${DateTime
            .now()
            .millisecondsSinceEpoch}.txt';
        final file = File(outPath);
        await file.writeAsString(_generatedContent!);

        await Share.shareXFiles(
          [
            XFile(
                file.path, mimeType: 'text/plain', name: 'final_moi_report.txt')
          ],
          text: 'Final Moi Report',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _createReceiptPngBytes(Map<String, String> fields) async {
    final Uint8List imgBytes = await CoverImageHelper.getCoverImageBytes();
    final codec = await ui.instantiateImageCodec(imgBytes);
    final frame = await codec.getNextFrame();
    final ui.Image background = frame.image;

    final int width = background.width;
    final int height = background.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(background, Offset.zero, Paint());

    void drawText(String text,
        double x,
        double y,
        double fontSize, {
          TextAlign align = TextAlign.left,
          FontWeight fontWeight = FontWeight.normal,
          Color color = Colors.black,
          double maxWidth = 0, // ADD THIS PARAMETER
        }) {
      final textStyle = TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: 'NotoSerifTamil',
      );

      final textSpan = TextSpan(text: text, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: align,
        textDirection: TextDirection.ltr,
        maxLines: null, // CHANGE from no limit to allow wrapping
      );

      // UPDATE this line:
      final effectiveMaxWidth = maxWidth > 0 ? maxWidth : width.toDouble() - 40;
      textPainter.layout(minWidth: 0, maxWidth: effectiveMaxWidth);

      double xPos = x;
      if (align == TextAlign.center) {
        xPos = (width - textPainter.width) / 2;
      } else if (align == TextAlign.right) {
        xPos = width - textPainter.width - x;
      }

      textPainter.paint(canvas, Offset(xPos, y));
    }

    final titleFontSize = (width / 8).clamp(55.0, 110.0);
    final textFontSize = (width / 10).clamp(45.0, 95.0);
    final lineHeight = (height * 0.10).clamp(90.0, 170.0);

    double cursorY = height * 0.24;

// 1. TITLE (FIRST)
    final title = fields['Title'] ?? '';
    if (title.isNotEmpty) {
      drawText(
        title,
        0,
        cursorY,
        textFontSize,
        align: TextAlign.center,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0B4206),
        maxWidth: width * 0.9, // ADD: 90% of width for wrapping
      );
      cursorY += lineHeight * 2.7;
    }

// 2. EVENT TYPE (SECOND)
    final eventType = fields['Event Type'] ?? 'MOI EVENT';
    drawText(
      eventType,
      0,
      cursorY,
      titleFontSize,
      align: TextAlign.center,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF8B0000),
      maxWidth: width * 0.9, // ADD: 90% of width for wrapping
    );
    cursorY += lineHeight * 2.7;

// 3. EVENT FOR (THIRD)
    final eventFor = fields['Event For'] ?? '';
    if (eventFor.isNotEmpty) {
      drawText(
        eventFor,
        0,
        cursorY,
        textFontSize,
        align: TextAlign.center,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF000C8C),
        maxWidth: width * 0.9, // ADD: 90% of width for wrapping
      );
      cursorY += lineHeight * 3.2;
    }

// 4. VENUE (FOURTH)
    final venue = fields['Venue'] ?? '';
    final city = fields['City'] ?? '';

    if (venue.isNotEmpty || city.isNotEmpty) {
      final place = venue.isNotEmpty && city.isNotEmpty
          ? 'இடம் : $venue, $city'
          : 'இடம் : ${venue.isNotEmpty ? venue : city}';

      drawText(
        place,
        0,
        cursorY,
        textFontSize * 0.85,
        align: TextAlign.center,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0000FF),
        maxWidth: width * 0.9, // ADD: 90% of width for wrapping
      );
      cursorY += lineHeight * 1.6;
    }

// 5. EVENT DATE (FIFTH)
    final eventDate = fields['Event Date'] ?? '';
    if (eventDate.isNotEmpty) {
      drawText(
        'நாள் : $eventDate',
        0,
        cursorY,
        textFontSize * 0.9,
        align: TextAlign.center,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF008000),
        maxWidth: width * 0.9,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData2 = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData2 == null) {
      throw Exception('Failed to convert edited receipt to PNG bytes');
    }

    return byteData2.buffer.asUint8List();
  }

  Future<Uint8List?> _createMergedPdfWithImageFirst(
      Uint8List serverPdfBytes) async {
    try {
      final eventData = await _fetchEventDetails(widget.eventId);
      final fields = <String, String>{
        'Event Type': eventData['event_type'] ?? '',
        'Title': eventData['title'] ?? '',
        'Event For': eventData['event_for'] ?? '',
        'Remarks': eventData['remark'] ?? '',
        'Event Date': eventData['event_date'] ?? '',
        'Venue': eventData['venue'] ?? '',
        'City': eventData['city'] ?? '',
      };

      final pngBytes = await _createReceiptPngBytes(fields);
      final PdfDocument mergedDocument = PdfDocument();
      final PdfPage firstPage = mergedDocument.pages.add();
      final PdfGraphics g = firstPage.graphics;

      final PdfBitmap bitmap = PdfBitmap(pngBytes);
      final Size pageSize = firstPage.getClientSize();

// Draw image to fill the entire page (no margins)
      g.drawImage(bitmap, Rect.fromLTWH(0, 0, pageSize.width, pageSize.height));

      final PdfDocument serverDoc = PdfDocument(inputBytes: serverPdfBytes);

      for (int i = 0; i < serverDoc.pages.count; i++) {
        final PdfPage sourcePage = serverDoc.pages[i];
        final PdfPage newPage = mergedDocument.pages.add();
        final template = sourcePage.createTemplate();
        newPage.graphics.drawPdfTemplate(
            template, Offset.zero, sourcePage.size);
      }

      final List<int> bytes = mergedDocument.saveSync();
      mergedDocument.dispose();
      serverDoc.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      if (kDebugMode) print('Error merging PDF: $e');
      return null;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day-$month-$year';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  Future<Uint8List?> _createMergedPdfForHtml(String htmlContent) async {
    try {
      final eventData = await _fetchEventDetails(widget.eventId);
      final fields = <String, String>{
        'Event Type': eventData['event_type'] ?? '',
        'Title': eventData['title'] ?? '',
        'Event For': eventData['event_for'] ?? '',
        'Remarks': eventData['remark'] ?? '',
        'Event Date': eventData['event_date'] ?? '',
        'Venue': eventData['venue'] ?? '',
        'City': eventData['city'] ?? '',
      };
      final pngBytes = await _createReceiptPngBytes(fields);

      Uint8List? htmlPdfBytes;
      try {
        htmlPdfBytes = await Printing.convertHtml(
          format: pdf_pkg.PdfPageFormat.a4,
          html: htmlContent,
        );
      } catch (e) {
        if (kDebugMode) print(
            'Printing.convertHtml failed: $e - falling back to text PDF');
        htmlPdfBytes = await _convertTextToPdf(htmlContent);
      }

      if (htmlPdfBytes == null) {
        throw Exception('Failed to convert HTML to PDF');
      }

      return await _createMergedPdfWithImageFirst(htmlPdfBytes);
    } catch (e) {
      if (kDebugMode) print('Error creating merged PDF for HTML: $e');
      return null;
    }
  }

  Future<Map<String, String>> _fetchEventDetails(String eventId) async {
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('*, event_types(name)')
          .eq('id', eventId)
          .single();

      return {
        'event_type': response['event_types']?['name'] ?? '',
        'title': response['title'] ?? '',
        'event_for': response['event_for'] ?? '',
        'remark': response['remark'] ?? '',
        'event_date': response['event_date'] != null
            ? _formatDate(response['event_date'])
            : '',
        'venue': response['venue'] ?? '',
        'city': response['city'] ?? '',
      };
    } catch (e) {
      if (kDebugMode) print('Error fetching event details: $e');
      return {};
    }
  }

  Future<String> _createMergedHtmlWithImageFirst(String serverHtml) async {
    final eventData = await _fetchEventDetails(widget.eventId);
    final fields = <String, String>{
      'Event Type': eventData['event_type'] ?? '',
      'Title': eventData['title'] ?? '',
      'Event For': eventData['event_for'] ?? '',
      'Remarks': eventData['remark'] ?? '',
      'Event Date': eventData['event_date'] ?? '',
      'Venue': eventData['venue'] ?? '',
      'City': eventData['city'] ?? '',
    };
    final pngBytes = await _createReceiptPngBytes(fields);
    final base64Image = base64Encode(pngBytes);

    final imgTag =
        '<div style="text-align:center; page-break-after:always; margin:0; padding:0;"><img src="data:image/png;base64,$base64Image" style="width:100%; height:auto; display:block;" /></div>';

    if (serverHtml.contains('<body')) {
      final updated = serverHtml.replaceFirstMapped(
        RegExp(r'(<body[^>]*>)', caseSensitive: false),
            (match) => '${match.group(1)}$imgTag',
      );
      return updated;
    } else {
      return imgTag + serverHtml;
    }
  }

  Future<Uint8List> _convertTextToPdf(String textContent) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    page.graphics.drawString(
      textContent,
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: Rect.fromLTWH(0, 0, page
          .getClientSize()
          .width, page
          .getClientSize()
          .height),
    );
    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
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
          'Final Moi Report',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_generatedContent == null && _generatedFile == null) ...[
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Select Report Format',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildFormatButton(
                          'HTML', 'html', Icons.code, const Color(0xFFE67E22)),
                      const SizedBox(height: 16),
                      _buildFormatButton('Excel', 'excel', Icons.table_chart,
                          const Color(0xFF217346)),
                      const SizedBox(height: 16),
                      _buildFormatButton('PDF', 'pdf', Icons.picture_as_pdf,
                          const Color(0xFFD32F2F)),
                      const SizedBox(height: 16),
                      _buildFormatButton('Text', 'txt', Icons.text_fields,
                          const Color(0xFF1976D2)),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            if (_isLoading) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Processing report...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              ...[
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
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
                    child: _buildReportPreview(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading || _isDownloading)
                              ? null
                              : _downloadReport,
                          icon: const Icon(Icons.download, size: 24),
                          label: const Text(
                            'Download',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB846D7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading || _isDownloading)
                              ? null
                              : _shareReport,
                          icon: const Icon(Icons.share, size: 24),
                          label: const Text(
                            'Share',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8F8F8F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
        ],
      ),
    );
  }

  Widget _buildFormatButton(String label, String format, IconData icon,
      Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _generateReport(format),
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildReportPreview() {
    if (_selectedFormat == 'html' && _generatedContent != null) {
      return InAppWebView(
        initialData: InAppWebViewInitialData(data: _generatedContent!),
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      );
    } else if ((_selectedFormat == 'excel' || _selectedFormat == 'csv') &&
        _generatedFile != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFormat == 'excel' ? Icons.table_rows : Icons.table_chart,
              size: 64,
              color: _selectedFormat == 'excel'
                  ? const Color(0xFF0E7C7B)
                  : const Color(0xFF217346),
            ),
            const SizedBox(height: 16),
            Text(
              '${_selectedFormat == 'excel' ? 'Excel' : 'Excel'} Report Generated',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'File: ${_generatedFile!
                  .path
                  .split('/')
                  .last}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              'Use the Download or Share button below',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'File will open in ${_selectedFormat == 'excel'
                  ? 'Excel/Sheets'
                  : 'Excel'}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_selectedFormat == 'txt' && _generatedContent != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          _generatedContent!,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      );
    } else if (_selectedFormat == 'pdf') {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'PDF Generated Successfully',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Use Download or Share to view the PDF',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return const Center(child: Text('No content available'));
  }
}