import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

class WithdrawalReceiptGenerator {
  static const platform = MethodChannel('com.example.moi_virunthu/whatsapp');
  // Cache for base64 logo
  static String? _cachedLogoBase64;

// Cache for base64 font
  static String? _cachedFontBase64;

// Load and cache logo as base64
  static Future<String> _getLogoBase64() async {
    if (_cachedLogoBase64 != null) {
      return _cachedLogoBase64!;
    }

    try {
      final ByteData data = await rootBundle.load('assets/images/money_transfer.png');
      final List<int> bytes = data.buffer.asUint8List();
      _cachedLogoBase64 = base64Encode(bytes);
      return _cachedLogoBase64!;
    } catch (e) {
      print('Error loading logo: $e');
      return '';
    }
  }

// Load and cache font as base64
  static Future<String> _getFontBase64() async {
    if (_cachedFontBase64 != null) {
      return _cachedFontBase64!;
    }

    try {
      final ByteData data = await rootBundle.load('assets/fonts/ALTRONED_Trial.ttf');
      final List<int> bytes = data.buffer.asUint8List();
      _cachedFontBase64 = base64Encode(bytes);
      return _cachedFontBase64!;
    } catch (e) {
      print('Error loading font: $e');
      return '';
    }
  }

  // Generate cash withdrawal receipt
  static Future<File?> generateWithdrawalReceipt({
    required BuildContext context,
    required String operatorName,
    required DateTime withdrawalDate,
    required TimeOfDay withdrawalTime,
    required String requestedBy,
    required String? requesterPhoneNumber,
    required num amount,
    required Map<int, int> denominations,
    String? reason,
    String? eventTitle,
    String? eventFor,
    String? eventTypeName,
    String? venue,
    String? customerName,
    String? city,
    String? customerPhone,

    bool showDialog = true,
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();
      final htmlContent = _generateWithdrawalHtml(
        operatorName: operatorName,
        withdrawalDate: withdrawalDate,
        withdrawalTime: withdrawalTime,
        requestedBy: requestedBy,
        requesterPhoneNumber: requesterPhoneNumber,
        amount: amount,
        denominations: denominations,
        reason: reason,
        eventTitle: eventTitle,
        eventFor: eventFor,
        eventTypeName: eventTypeName,
        venue: venue,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
logoBase64: logoBase64,  // ADD THIS
fontBase64: fontBase64,  // ADD THIS
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime
          .now()
          .millisecondsSinceEpoch;
      final fileName = 'withdrawal_receipt_$timestamp.pdf';
      final filePath = '${output.path}/$fileName';

      File? generatedFile;
      bool pdfGenerated = false;

      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        initialSize: Size(302, 800),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            // Get the actual content height
            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800; // default
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            // Resize to actual content
            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              // Calculate PDF height based on content
              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) *
                  pdfWidth; // Maintain aspect ratio

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pdfWidth, pdfHeight, marginAll: 0),
                  build: (pw.Context context) {
                    return pw.Image(image, fit: pw.BoxFit.fill);
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              generatedFile = file;
              pdfGenerated = true;
              print('Withdrawal receipt PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating withdrawal receipt PDF: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          print('WebView Console: ${consoleMessage.message}');
        },
      );

      await headlessWebView.run();

      int attempts = 0;
      while (attempts < 30 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (pdfGenerated) {
          final file = File(filePath);
          if (await file.exists() && await file.length() > 0) {
            generatedFile = file;
            break;
          }
        }
        attempts++;
      }

      // Show share dialog if PDF was generated successfully and showDialog is true
      final finalFile = generatedFile;
      if (finalFile != null && context.mounted && showDialog) {
        _showShareDialog(context, finalFile);
      }

      return generatedFile;
    } catch (e) {
      print('Error in generateWithdrawalReceipt: $e');
      return null;
    }
  }

  // Add this complete method after generateWithdrawalReceipt
  static Future<Map<String, dynamic>?> generateWithdrawalReceiptWithImage({
    required BuildContext context,
    required String operatorName,
    required DateTime withdrawalDate,
    required TimeOfDay withdrawalTime,
    required String requestedBy,
    required String? requesterPhoneNumber,
    required num amount,
    required Map<int, int> denominations,
    String? reason,
    String? eventTitle,
    String? eventFor,
    String? eventTypeName,
    String? venue,
    String? customerName,
    String? city,
    String? customerPhone,
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      final htmlContent = _generateWithdrawalHtml(
        operatorName: operatorName,
        withdrawalDate: withdrawalDate,
        withdrawalTime: withdrawalTime,
        requestedBy: requestedBy,
        requesterPhoneNumber: requesterPhoneNumber,
        amount: amount,
        denominations: denominations,
        reason: reason,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        eventTitle: eventTitle,
        eventFor: eventFor,
        eventTypeName: eventTypeName,
        venue: venue,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'withdrawal_receipt_with_image_$timestamp.pdf';
      final filePath = '${output.path}/$fileName';

      File? generatedFile;
      Uint8List? screenshotBytes;
      bool pdfGenerated = false;

      HeadlessInAppWebView? headlessWebView;

      headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: htmlContent),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        initialSize: Size(302, 800),
        onLoadStop: (controller, url) async {
          try {
            await Future.delayed(const Duration(milliseconds: 1500));

            final contentHeight = await controller.evaluateJavascript(
                source: "document.body.scrollHeight"
            );

            int height = 800;
            if (contentHeight != null) {
              height = int.tryParse(contentHeight.toString()) ?? 800;
            }

            await headlessWebView?.setSize(Size(302, height.toDouble()));
            await Future.delayed(const Duration(milliseconds: 500));

            final screenshot = await controller.takeScreenshot();

            if (screenshot != null) {
              // ✅ Save screenshot bytes for thermal printer
              screenshotBytes = screenshot;

              final pdf = pw.Document();
              final image = pw.MemoryImage(screenshot);

              final pdfWidth = 80 * PdfPageFormat.mm;
              final pdfHeight = (height / 302) * pdfWidth;

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pdfWidth, pdfHeight, marginAll: 0),
                  build: (pw.Context context) {
                    return pw.Image(image, fit: pw.BoxFit.fill);
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              generatedFile = file;
              pdfGenerated = true;
              print('Withdrawal receipt generated: PDF + Image');
            }
          } catch (e) {
            print('Error generating withdrawal receipt: $e');
          } finally {
            if (headlessWebView != null) {
              await headlessWebView.dispose();
            }
          }
        },
      );

      await headlessWebView.run();

      int attempts = 0;
      while (attempts < 30 && !pdfGenerated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (pdfGenerated) {
          final file = File(filePath);
          if (await file.exists() && await file.length() > 0) {
            generatedFile = file;
            break;
          }
        }
        attempts++;
      }

      // ✅ Return both PDF file and screenshot bytes
      if (generatedFile != null && screenshotBytes != null) {
        return {
          'pdf': generatedFile,
          'imageBytes': screenshotBytes,
        };
      }

      return null;
    } catch (e) {
      print('Error in generateWithdrawalReceiptWithImage: $e');
      return null;
    }
  }

  // Send withdrawal receipt to WhatsApp using MethodChannel
  static Future<void> sendToWhatsApp({
    required BuildContext context,
    required String phoneNumber,
    required String operatorName,
    required DateTime withdrawalDate,
    required TimeOfDay withdrawalTime,
    required String requestedBy,
    required num amount,
    required Map<int, int> denominations,
    String? reason,
    // ✅ ADD THESE NEW PARAMETERS:
    String? eventTitle,
    String? eventFor,
    String? eventTypeName,
    String? venue,
    String? customerName,
    String? city,
    String? customerPhone,
  }) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate the receipt PDF
      final receiptFile = await generateWithdrawalReceipt(
        context: context,
        operatorName: operatorName,
        withdrawalDate: withdrawalDate,
        withdrawalTime: withdrawalTime,
        requestedBy: requestedBy,
        requesterPhoneNumber: phoneNumber,
        amount: amount,
        denominations: denominations,
        reason: reason,
        showDialog: false,
        eventTitle: eventTitle,
        eventFor: eventFor,
        eventTypeName: eventTypeName,
        venue: venue,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
      );

      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (receiptFile == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate receipt'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Format phone number for WhatsApp
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

      // Add country code if not present (assuming India +91)
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      } else if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }

      // Create WhatsApp message
      final whatsappMessage = 'Cash Withdrawal Receipt\n\n'
          '💰 Amount: ₹${amount.round()}\n'
          '👤 Requested by: $requestedBy\n'
          '📅 Date: ${DateFormat('dd-MM-yyyy').format(withdrawalDate)}\n'
          '⏰ Time: ${withdrawalTime.hour.toString().padLeft(
          2, '0')}:${withdrawalTime.minute.toString().padLeft(2, '0')}\n\n'
          '${reason != null && reason.isNotEmpty ? 'Reason: $reason\n\n' : ''}'
          'Receipt attached below.\n\n'
          'நன்றி!\n'
          'பேச்சி மொய் டெக்';

      // Send via WhatsApp using MethodChannel
      try {
        final result = await platform.invokeMethod('sendToWhatsApp', {
          'phone': cleanPhone,
          'message': whatsappMessage,
          'filePath': receiptFile.path,
        });

        if (context.mounted) {
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening WhatsApp for $requestedBy'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'WhatsApp not installed. Please install WhatsApp.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Error invoking platform method: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening WhatsApp: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending to WhatsApp: $e');

      // Close loading indicator if still open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Show share dialog
  static void _showShareDialog(BuildContext context, File pdfFile) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Receipt Generated'),
            content: const Text(
                'Withdrawal receipt has been generated successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Share.shareXFiles(
                    [XFile(pdfFile.path)],
                    subject: 'Cash Withdrawal Receipt',
                  );
                },
                child: const Text('Share'),
              ),
            ],
          ),
    );
  }

  // HTML template for withdrawal receipt
  // HTML template for withdrawal receipt
  static String _generateWithdrawalHtml({
    required String operatorName,
    required DateTime withdrawalDate,
    required TimeOfDay withdrawalTime,
    required String requestedBy,
    required String? requesterPhoneNumber,
    required num amount,
    required Map<int, int> denominations,
    String? reason,
    required String logoBase64,
    required String fontBase64,
    // ✅ ADD THESE PARAMETERS:
    String? eventTitle,
    String? eventFor,
    String? eventTypeName,
    String? venue,
    String? customerName,
    String? city,
    String? customerPhone,
  }) {
    // ✅ Use current date/time
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    // Use proper operator name
    final displayOperatorName = (operatorName.isEmpty || operatorName == 'Unknown')
        ? 'Operator'
        : operatorName;

    // Build denomination table
    String denomTable = '';
    List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

    for (int denom in denomKeys) {
      int count = denominations[denom] ?? 0;
      if (count > 0) {
        int total = denom * count;
        denomTable += '''
        <tr>
          <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$denom</td>
          <td style="border: 2px solid black; padding: 4px; text-align: center;">x</td>
          <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$count</td>
          <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold;">$total</td>
        </tr>
      ''';
      }
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
  <style>
  @font-face {
    font-family: 'Altroned';
    src: url(data:font/truetype;charset=utf-8;base64,$fontBase64) format('truetype');
  }

  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  
  body {
    font-family: 'Noto Sans Tamil', sans-serif;
    width: 302px;
    padding: 0;
    text-align: center;
    background: white;
    font-weight: 700;
    overflow: hidden;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    text-rendering: optimizeLegibility;
  }
  
  .outer-box {
    border: 3px solid black;
    padding: 0;
    margin: 0;
    box-sizing: border-box;
    background: white;
    position: relative;
  }
  
  .logo-header {
    display: flex;
    align-items: center;
    padding: 8px;
    gap: 10px;
  }

  .logo {
    width: 85px;
    height: 85px;
    object-fit: contain;
  }

  .company-info {
    width: 100%;
    text-align: center;
  }

  .company-name {
    font-family: 'Altroned', sans-serif;
    font-size: 22px;
    font-weight: 700;
    color: #000;
    margin-bottom: 3px;
  }

  .tamil-heading {
    font-size: 17px;
    font-weight: 700;
    color: #000;
    margin-bottom: 4px;
  }

  .company-phone {
    font-size: 16px;
    font-weight: 700;
    color: #000;
  }
  
  .divider {
    border-top: 2px solid black;
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    height: 0;
    width: 100%;
    overflow: hidden;
  }
  
  .date-time-row {
    display: flex;
    justify-content: space-between;
    font-size: 14px;
    font-weight: 700;
    border-bottom: 2px solid black;
    box-sizing: border-box;
  }

  .left-section {
    text-align: left;
    padding: 8px;
    flex: 1;
    border-right: 2px solid black;
    box-sizing: border-box;
    font-weight: 700;
  }

  .right-section {
    text-align: right;
    padding: 8px;
    flex: 1;
    font-weight: 700;
  }
  
  .withdrawal-title {
    font-size: 18px;
    font-weight: 700;
    padding: 10px;
    background-color: #ffebee;
    border-bottom: 2px solid black;
    color: #c62828;
  }
  
  .info-box {
    border-bottom: 2px solid black;
    padding: 12px;
    text-align: center;
  }
  
  .info-label {
    font-size: 14px;
    font-weight: 700;
    margin-bottom: 4px;
  }
  
  .info-value {
    font-size: 16px;
    font-weight: 700;
    margin-bottom: 8px;
  }
  
  .amount-box {
    background-color: #ffebee;
    border-bottom: 2px solid black;
    padding: 12px;
  }
  
  .amount-label {
    font-size: 16px;
    font-weight: 700;
  }
  
  .amount {
    font-size: 28px;
    font-weight: 700;
    color: #d32f2f;
    margin: 8px 0;
  }
  
  .section-title {
    font-size: 16px;
    font-weight: 700;
    padding: 8px 0;
  }
  
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 0;
    font-weight: 700;
  }

  td {
    font-weight: 700;
  }
  
  .reason-box {
    border-bottom: 2px solid black;
    padding: 10px;
    text-align: left;
    min-height: 60px;
  }
  
  .reason-title {
    font-weight: 700;
    font-size: 14px;
    margin-bottom: 5px;
  }
  
  .reason-text {
    font-size: 13px;
    font-weight: 700;
    line-height: 1.4;
  }
  
  .footer {
    margin-top: 0;
    padding-top: 8px;
    font-size: 14px;
    font-weight: 700;
  }
  
  .thanks {
    margin: 6px 0;
    font-weight: 700;
  }
  
  .with-love {
    font-size: 12px;
    font-weight: 700;
    margin: 4px 0;
  }
  
  .footer-name {
    font-size: 15px;
    font-weight: 700;
    margin: 6px 0;
    word-wrap: break-word;
    line-height: 1.3;
  }
  
  .village-info {
    font-size: 14px;
    font-weight: 700;
    margin: 4px 0;
    word-wrap: break-word;
    line-height: 1.3;
  }
  
  .phone {
    font-size: 14px;
    font-weight: 700;
    margin: 6px 0;
  }
  </style>
</head>
<body>
  <div class="outer-box">
    <div class="logo-header">
      <img src="data:image/png;base64,$logoBase64" alt="Logo" class="logo">
      <div class="company-info">
        <div class="company-name">Hi Tech Moi</div>
        <div class="tamil-heading">ஹை-டெக் மொய்</div>
        <div class="company-phone">9043606296,9047556443</div>
      </div>
    </div>

    <div class="divider"></div>

    <div class="date-time-row">
      <div class="left-section">
        <div>$dateStr</div>
        <div>$timeStr</div>
      </div>
      <div class="right-section">
        <div>Typer</div>
        <div>$displayOperatorName</div>
      </div>
    </div>
    
    <div class="withdrawal-title">CASH WITHDRAWAL</div>
    
   <div class="info-box">
  <div class="info-label">Requested by</div>
  <div class="info-value">$requestedBy</div>
  ${requesterPhoneNumber != null && requesterPhoneNumber!.isNotEmpty
        ? '<div class="info-value" style="font-size: 14px; color: #666;">($requesterPhoneNumber)</div>'
        : ''}
</div>
    
    <div class="amount-box">
      <div class="amount-label">Withdrawal Amount</div>
      <div class="amount">₹${amount.round()}</div>
    </div>
    
    <div class="section-title">நோட்டு விபரம்</div>
    <table>
      $denomTable
    </table>
    
    ${reason != null && reason.isNotEmpty ? '''
    <div class="reason-box">
      <div class="reason-title">Reason:</div>
      <div class="reason-text">$reason</div>
    </div>
    ''' : '<div class="divider"></div>'}
    
    <div class="footer">
      <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
      <div class="with-love">அன்புடன்</div>
      ${eventTitle != null && eventTitle.isNotEmpty ? '<div class="footer-name">$eventTitle</div>' : ''}
      ${eventTypeName != null && eventTypeName.isNotEmpty ? '<div class="footer-name">$eventTypeName</div>' : ''}
      ${venue != null && venue.isNotEmpty ? '<div class="village-info">$venue</div>' : ''}
      ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
      ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="phone">$customerPhone</div>' : ''}
    </div>
  </div>
</body>
</html>
''';
  }
}