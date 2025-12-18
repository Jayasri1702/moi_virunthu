import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class MoiReceiptGenerator {

  // Format number with commas (Indian numbering system)
  static String _formatAmount(num amount) {
    final roundedAmount = amount.round();
    final str = roundedAmount.toString();

    if (str.length <= 3) return str;

    // Indian numbering: last 3 digits, then groups of 2
    final lastThree = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);

    String result = '';
    int count = 0;
    for (int i = remaining.length - 1; i >= 0; i--) {
      if (count == 2) {
        result = ',$result';
        count = 0;
      }
      result = remaining[i] + result;
      count++;
    }

    return '$result,$lastThree';
  }

  // Cache for base64 logo
  static String? _cachedLogoBase64;

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
      return ''; // Return empty string if logo fails to load
    }
  }

  // Cache for base64 font
  static String? _cachedFontBase64;

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

  // Add this method to MoiReceiptGenerator class (after generateSingleMoiReceipt)

  static Future<Map<String, dynamic>?> generateSingleMoiReceiptWithImage({
    required BuildContext context,
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? notes,
    String? person2Details,
    String? phone,
    required num amount,
    required String paymentMethod,
    Map<int, int>? denominations,
    String? customerName,
    String? city,
    String? customerPhone,
    bool isUncle = false,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      // Use different template based on payment method
      final htmlContent = paymentMethod == 'CASH'
          ? _generateSingleMoiHtml(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        denominations: denominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        isUncle: isUncle,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      )
          : _generateSingleMoiHtmlOthers(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        isUncle: isUncle,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,

      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_single_${serialNo}_$timestamp.pdf';
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
              print('Single receipt generated: PDF + Image');
            }
          } catch (e) {
            print('Error generating single receipt: $e');
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
      print('Error in generateSingleMoiReceiptWithImage: $e');
      return null;
    }
  }

// ✅ Also add method for split group receipts with images
  static Future<List<Map<String, dynamic>>> generateSplitGroupReceiptsWithImages({
    required BuildContext context,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    String? customerName,
    String? city,
    String? notes,
    String? customerPhone,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
  }) async {
    List<Map<String, dynamic>> generatedReceipts = [];

    for (var entry in groupEntries) {
      String? person1Name;
      String? person1Job;
      String? person2Details;

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          person1Name = personsList[0]['name'];
          person1Job = personsList[0]['job'];
        }
        if (personsList.length > 1) {
          person2Details = personsList[1]['details'];
        }
      }

      Map<int, int>? denominations;
      if (entry['payment_method'] == 'CASH' && entry['denominations'] != null) {
        denominations = {
          500: entry['denominations']['denom_500'] ?? 0,
          200: entry['denominations']['denom_200'] ?? 0,
          100: entry['denominations']['denom_100'] ?? 0,
          50: entry['denominations']['denom_50'] ?? 0,
          20: entry['denominations']['denom_20'] ?? 0,
          10: entry['denominations']['denom_10'] ?? 0,
          5: entry['denominations']['denom_5'] ?? 0,
          1: entry['denominations']['denom_1'] ?? 0,
        };
      }

      final result = await generateSingleMoiReceiptWithImage(
        context: context,
        serialNo: entry['serial_no'],
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: entry['village_name'],
        livingPlace: entry['living_place'],
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: entry['phone'],
        amount: entry['amount'],
        paymentMethod: entry['payment_method'],
        denominations: denominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        isUncle: entry['is_uncle'] ?? false,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      if (result != null) {
        generatedReceipts.add(result);
      }
    }

    return generatedReceipts;
  }

  // ✅ NEW: Generate group receipt with image for thermal printing
  static Future<Map<String, dynamic>?> generateGroupMoiReceiptWithImage({
    required BuildContext context,
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    Map<int, int>? totalDenominations,
    String? customerName,
    String? city,
    String? customerPhone,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    String? notes,
  }) async {
    try {
      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      bool hasOthersPayment = groupEntries.any((entry) => entry['payment_method'] != 'CASH');

      final htmlContent = hasOthersPayment
          ? _generateGroupMoiHtmlOthers(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      )
          : _generateGroupMoiHtml(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
        totalDenominations: totalDenominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_group_${groupId}_$timestamp.pdf';
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
              print('Group receipt generated: PDF + Image');
            }
          } catch (e) {
            print('Error generating group receipt: $e');
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
      print('Error in generateGroupMoiReceiptWithImage: $e');
      return null;
    }
  }

  // Generate single MOI receipt
  static Future<File?> generateSingleMoiReceipt({
    required BuildContext context,
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? person2Details,
    String? phone,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    String? notes,
    required num amount,
    required String paymentMethod,
    Map<int, int>? denominations,
    // ✅ NEW: Event details for footer
    String? customerName,
    String? city,
    String? customerPhone,
    bool isUncle = false,  // ✅ ADD THIS LINE
  }) async {
    try {

      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      // Use different template based on payment method
      final htmlContent = paymentMethod == 'CASH'
          ? _generateSingleMoiHtml(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        denominations: denominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,  // ADD THIS
        fontBase64: fontBase64,
        isUncle: isUncle,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      )
          : _generateSingleMoiHtmlOthers(
        serialNo: serialNo,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: villageName,
        livingPlace: livingPlace,
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: phone,
        amount: amount,
        paymentMethod: paymentMethod,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,  // ADD THIS
        fontBase64: fontBase64,
        isUncle: isUncle,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_single_${serialNo}_$timestamp.pdf';
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
              print('Single receipt PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating single receipt PDF: $e');
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

      return generatedFile;
    } catch (e) {
      print('Error in generateSingleMoiReceipt: $e');
      return null;
    }
  }

  // HTML template for single MOI receipt (CASH)
  static String _generateSingleMoiHtml({
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? person2Details,
    String? phone,
    String? notes,
    required num amount,
    required String paymentMethod,
    Map<int, int>? denominations,
    String? customerName,
    String? city,
    String? customerPhone,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    required String logoBase64,
    required String fontBase64,
    bool isUncle = false,
  }) {
    // ✅ FIXED: Use current date/time for receipt generation
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    // Build person display
    String personDisplay = '';
    if (person1Name != null && person1Name.isNotEmpty) {
      personDisplay += '$person1Name\n';
      if (person1Job != null && person1Job.isNotEmpty) {
        personDisplay += '$person1Job\n';
      }
    }
    if (person2Details != null && person2Details.isNotEmpty) {
      personDisplay += person2Details;
    }

    // ✅ FIXED: Build denomination table with received/return logic
    String denomTable = '';
    num receivedAmount = 0;
    num returnAmount = 0;

    if (paymentMethod == 'CASH' && denominations != null) {
      List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

      // Separate positive (received) and negative (return) denominations
      Map<int, int> receivedDenoms = {};
      Map<int, int> returnDenoms = {};

      for (int denom in denomKeys) {
        int count = denominations[denom] ?? 0;
        if (count > 0) {
          receivedDenoms[denom] = count;
          receivedAmount += denom * count;
        } else if (count < 0) {
          returnDenoms[denom] = count.abs();
          returnAmount += denom * count.abs();
        }
      }

      // ✅ Build received table
      if (receivedDenoms.isNotEmpty) {
        for (int denom in denomKeys) {
          if (receivedDenoms.containsKey(denom)) {
            int count = receivedDenoms[denom]!;
            num total = denom * count;
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

        denomTable += '''
          <tr>
            <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">Received</td>
            <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">$receivedAmount</td>
          </tr>
        ''';
      }

      // ✅ Build return table
      if (returnDenoms.isNotEmpty) {
        denomTable += '''
          <tr>
            <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">Return</td>
            <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">$returnAmount</td>
          </tr>
        ''';

        for (int denom in denomKeys) {
          if (returnDenoms.containsKey(denom)) {
            int count = returnDenoms[denom]!;
            num total = denom * count;
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
  .notes-section {
  margin: 8px 0;
  padding: 8px;
  background-color: #fff9c4;
  border: 1px solid #f57f17;
  border-radius: 4px;
}

.notes-label {
  font-size: 12px;
  font-weight: 700;
  color: #f57f17;
  margin-bottom: 4px;
}

.notes-text {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.4;
  white-space: pre-wrap;
}
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
    
    .header {
      background-color: #1976D2;
      color: white;
      font-size: 20px;
      font-weight: bold;
      padding: 8px;
      margin-bottom: 10px;
    }
   .outer-box {
  border: 3px solid black;
  padding: 0;
  margin: 0;
  box-sizing: border-box;
  background: white;
  position: relative;
}

.uncle-indicator {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 6px 0 4px 0;
    text-align: center;
    color: #000;
  }
    
.logo-header {
  display: flex;
  align-items: center;
  padding: 8px;
  gap: 10px;
}

.logo {
  width: 65px;
  height: 65px;
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
  font-size: 13px;
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
    
   .serial-no {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 8px 0;
    text-align: center;
  }
    
    .person-details {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 6px 0;
    white-space: pre-line;
    line-height: 1.4;
  }
    
    .village-info {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
  }
    
   .phone {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 6px 0;
  }
    
   .amount-label {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin-top: 10px;
  }
    
  .amount {
    font-size: 24px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 8px 0;
  }
    
   .table-title {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 0;
    padding: 8px 0;
  }
    
   table {
    width: 100%;
    border-collapse: collapse;
    margin: 0;
    font-weight: 700;  /* ✅ NEW: Make table text bold */
  }

 td {
    font-weight: 700;  /* ✅ NEW: Make all cells bold */
  }
    
     .footer {
    margin-top: 0;
    padding-top: 8px;
    font-size: 14px;
    font-weight: 700;  /* ✅ NEW */
  }
    
     .thanks {
    margin: 6px 0;
    font-weight: 700;  /* ✅ NEW */
  }
    
    .with-love {
    font-size: 12px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  <div class="serial-no">வ.எண் : $serialNo</div>
  
${(villageName != null && villageName.isNotEmpty) || (livingPlace != null && livingPlace.isNotEmpty)
        ? '<div class="village-info">${villageName ?? ''}${(villageName != null && villageName.isNotEmpty && livingPlace != null && livingPlace.isNotEmpty) ? ' (இ) ' : ''}${livingPlace ?? ''}</div>'
        : ''}

<div class="person-details">$personDisplay</div>

${isUncle ? '<div class="uncle-indicator">தாய்மாமன்</div>' : ''}

${phone != null && phone.isNotEmpty ? '<div class="phone">($phone)</div>' : ''}
${notes != null && notes.isNotEmpty ? '<div class="notes-section"><div class="notes-label">குறிப்பு:</div><div class="notes-text">$notes</div></div>' : ''}


<div class="amount-label">தொகை</div>
<div class="amount">₹${_formatAmount(amount)}</div>
  
  ${denomTable.isNotEmpty ? '<div class="table-title">நோட்டு விபரம்</div>' : ''}
  ${denomTable.isNotEmpty ? '<table>$denomTable</table>' : ''}
  
  <div class="divider"></div>
  
 <div class="footer">
  <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
  <div class="with-love">அன்புடன்</div>
  ${customerName != null && customerName.isNotEmpty ? '<div class="person-details">$customerName</div>' : ''}
  ${eventTitle != null && eventTitle.isNotEmpty ? '<div class="person-details">$eventTitle</div>' : ''}
${eventTypeName != null && eventTypeName.isNotEmpty ? '<div class="person-details">$eventTypeName</div>' : ''}
${venue != null && venue.isNotEmpty ? '<div class="village-info">$venue</div>' : ''}
  ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
  ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="phone">$customerPhone</div>' : ''}
</div>
  </div>
</body>
</html>
''';
  }

  // HTML template for single MOI receipt (OTHERS - Cheque/Advance/UPI)
  static String _generateSingleMoiHtmlOthers({
    required int serialNo,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    String? villageName,
    String? livingPlace,
    String? person1Name,
    String? person1Job,
    String? person2Details,
    String? phone,
    String? notes,
    required num amount,
    required String paymentMethod,
    String? customerName,
    String? city,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    String? customerPhone,
    required String logoBase64,
    required String fontBase64,
    bool isUncle = false,
  }) {
    // ✅ FIXED: Use current date/time
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    // Build person display
    String personDisplay = '';
    if (person1Name != null && person1Name.isNotEmpty) {
      personDisplay += '$person1Name\n';
      if (person1Job != null && person1Job.isNotEmpty) {
        personDisplay += '$person1Job\n';
      }
    }
    if (person2Details != null && person2Details.isNotEmpty) {
      personDisplay += person2Details;
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
  <style>
  .notes-section {
  margin: 8px 0;
  padding: 8px;
  background-color: #fff9c4;
  border: 1px solid #f57f17;
  border-radius: 4px;
}

.notes-label {
  font-size: 12px;
  font-weight: 700;
  color: #f57f17;
  margin-bottom: 4px;
}

.notes-text {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.4;
  white-space: pre-wrap;
}
  
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
    
    .header {
      background-color: #1976D2;
      color: white;
      font-size: 18px;
      font-weight: bold;
      padding: 10px;
      margin-bottom: 10px;
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
  width: 65px;
  height: 65px;
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
  font-size: 13px;
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
.uncle-indicator {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 6px 0 4px 0;
    text-align: center;
    color: #000;
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
    
    .serial-no {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 8px 0;
    text-align: center;
  }
    
    .person-details {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 6px 0;
    white-space: pre-line;
    line-height: 1.4;
  }
    
    .village-info {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
  }
    
   .phone {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 6px 0;
  }
    
    .amount-label {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin-top: 10px;
  }
    
    .amount {
    font-size: 24px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 8px 0;
  }
    
    .payment-method-box {
  border: 2px solid black;
  padding: 12px;
  margin: 0;  // Changed from margin: 15px 0;
  font-size: 16px;
  font-weight: bold;
  background-color: #f5f5f5;
}

    
     .footer {
    margin-top: 0;
    padding-top: 8px;
    font-size: 14px;
    font-weight: 700;  /* ✅ NEW */
  }
    
   .thanks {
    margin: 6px 0;
    font-weight: 700;  /* ✅ NEW */
  }
    
   .with-love {
    font-size: 12px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
  }
    
    .footer-person {
      font-size: 16px;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  <div class="serial-no">வ.எண் : $serialNo</div>
  
${(villageName != null && villageName.isNotEmpty) || (livingPlace != null && livingPlace.isNotEmpty)
        ? '<div class="village-info">${villageName ?? ''}${(villageName != null && villageName.isNotEmpty && livingPlace != null && livingPlace.isNotEmpty) ? ' (இ) ' : ''}${livingPlace ?? ''}</div>'
        : ''}

<div class="person-details">$personDisplay</div>

${isUncle ? '<div class="uncle-indicator">தாய்மாமன்</div>' : ''}

${phone != null && phone.isNotEmpty ? '<div class="phone">($phone)</div>' : ''}
${notes != null && notes.isNotEmpty ? '<div class="notes-section"><div class="notes-label">குறிப்பு:</div><div class="notes-text">$notes</div></div>' : ''}

<div class="amount-label">தொகை</div>
<div class="amount">₹${_formatAmount(amount)}</div>
  
  <div class="payment-method-box">Cheque / Advance / UPI</div>
  
 <div class="footer">
  <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
  <div class="with-love">அன்புடன்</div>
  ${customerName != null && customerName.isNotEmpty ? '<div class="person-details">$customerName</div>' : ''}
  ${eventTitle != null && eventTitle.isNotEmpty ? '<div class="person-details">$eventTitle</div>' : ''}
${eventTypeName != null && eventTypeName.isNotEmpty ? '<div class="person-details">$eventTypeName</div>' : ''}
${venue != null && venue.isNotEmpty ? '<div class="village-info">$venue</div>' : ''}
  ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
  ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="phone">$customerPhone</div>' : ''}
</div>
  </div>
</body>
</html>
''';
  }

  static Future<List<File>> generateSplitGroupReceipts({
    required BuildContext context,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    String? customerName,
    String? city,
    String? customerPhone,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    String? notes,
  }) async {
    List<File> generatedFiles = [];

    for (var entry in groupEntries) {
      // ✅ FIXED: Parse persons data correctly
      String? person1Name;
      String? person1Job;
      String? person2Details;

      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          person1Name = personsList[0]['name'];
          person1Job = personsList[0]['job'];
        }
        if (personsList.length > 1) {
          person2Details = personsList[1]['details'];
        }
      }

      // Parse denominations if payment is CASH
      Map<int, int>? denominations;
      if (entry['payment_method'] == 'CASH' && entry['denominations'] != null) {
        denominations = {
          500: entry['denominations']['denom_500'] ?? 0,
          200: entry['denominations']['denom_200'] ?? 0,
          100: entry['denominations']['denom_100'] ?? 0,
          50: entry['denominations']['denom_50'] ?? 0,
          20: entry['denominations']['denom_20'] ?? 0,
          10: entry['denominations']['denom_10'] ?? 0,
          5: entry['denominations']['denom_5'] ?? 0,
          1: entry['denominations']['denom_1'] ?? 0,
        };
      }

      final file = await generateSingleMoiReceipt(
        context: context,
        serialNo: entry['serial_no'],
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        villageName: entry['village_name'],
        livingPlace: entry['living_place'],
        person1Name: person1Name,
        person1Job: person1Job,
        person2Details: person2Details,
        phone: entry['phone'],
        amount: entry['amount'],
        paymentMethod: entry['payment_method'],
        denominations: denominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        isUncle: entry['is_uncle'] ?? false,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      if (file != null) {
        generatedFiles.add(file);
      }
    }

    return generatedFiles;
  }

  // Generate consolidated group MOI receipt
  static Future<File?> generateGroupMoiReceipt({
    required BuildContext context,
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    Map<int, int>? totalDenominations,
    String? customerName,
    String? city,
    String? customerPhone,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    String? notes,
  }) async {
    try {

      final logoBase64 = await _getLogoBase64();
      final fontBase64 = await _getFontBase64();

      bool hasOthersPayment = groupEntries.any((entry) => entry['payment_method'] != 'CASH');

      final htmlContent = hasOthersPayment
          ? _generateGroupMoiHtmlOthers(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,

      )
          : _generateGroupMoiHtml(
        groupId: groupId,
        operatorName: operatorName,
        eventDate: eventDate,
        eventTime: eventTime,
        groupEntries: groupEntries,
        totalAmount: totalAmount,
        totalDenominations: totalDenominations,
        customerName: customerName,
        city: city,
        customerPhone: customerPhone,
        logoBase64: logoBase64,
        fontBase64: fontBase64,
        eventTitle: eventTitle,
        eventTypeName: eventTypeName,
        venue: venue,
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'moi_group_${groupId}_$timestamp.pdf';
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
              final pdfHeight = (height / 302) * pdfWidth; // Maintain aspect ratio

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat(pdfWidth, pdfHeight, marginAll: 0),
                  build: (pw.Context context) {
                    return pw.Center(
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    );
                  },
                ),
              );

              final file = File(filePath);
              await file.writeAsBytes(await pdf.save());
              generatedFile = file;
              pdfGenerated = true;
              print('Group MOI PDF generated: $filePath');
            }
          } catch (e) {
            print('Error generating group MOI PDF: $e');
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

      return generatedFile;
    } catch (e) {
      print('Error in generateGroupMoiReceipt: $e');
      return null;
    }
  }

  static String _generateGroupMoiHtml({
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    Map<int, int>? totalDenominations,
    String? customerName,
    String? city,
    String? customerPhone,
    required String logoBase64,
    required String fontBase64,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    String? notes,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    String entriesHtml = '';
    for (var entry in groupEntries) {
      // Build full person display like single receipt
      String personDisplay = '';
      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          String name = personsList[0]['name'] ?? '';
          String job = personsList[0]['job'] ?? '';
          if (name.isNotEmpty) {
            personDisplay += '$name\n';
            if (job.isNotEmpty) {
              personDisplay += '$job\n';
            }
          }
        }
        if (personsList.length > 1) {
          String details = personsList[1]['details'] ?? '';
          if (details.isNotEmpty) {
            personDisplay += details;
          }
        }
      }

      String villageName = entry['village_name'] ?? '';
      String livingPlace = entry['living_place'] ?? '';
      String phone = entry['phone'] ?? '';
      bool isUncle = entry['is_uncle'] ?? false;

      var amountValue = entry['amount'];
      int amount = 0;
      if (amountValue is int) {
        amount = amountValue;
      } else if (amountValue is double) {
        amount = amountValue.round();
      } else if (amountValue is num) {
        amount = amountValue.round();
      }

      entriesHtml += '''
    <div class="entry-block">
      <div class="serial-no">வ.எண் : ${entry['serial_no']}</div>
      ${(villageName != null && villageName.isNotEmpty) || (livingPlace != null && livingPlace.isNotEmpty)
          ? '<div class="village-info">${villageName ?? ''}${(villageName != null && villageName.isNotEmpty && livingPlace != null && livingPlace.isNotEmpty) ? ' (இ) ' : ''}${livingPlace ?? ''}</div>'
          : ''}
      ${personDisplay.isNotEmpty ? '<div class="person-details" style="font-size: 14px; margin: 6px 0; white-space: pre-line;">$personDisplay</div>' : ''}
      ${isUncle ? '<div class="uncle-indicator" style="font-size: 12px; margin: 4px 0;">தாய்மாமன்</div>' : ''}
      ${phone.isNotEmpty ? '<div class="phone" style="font-size: 12px; margin: 4px 0;">($phone)</div>' : ''}
      ${notes != null && notes.isNotEmpty ? '<div class="notes-section"><div class="notes-label">குறிப்பு:</div><div class="notes-text">$notes</div></div>' : ''}
      <div class="amount-label">தொகை</div>
      <div class="entry-amount">₹${_formatAmount(amount)}</div>
    </div>
    <div class="divider"></div>
  ''';
    }

    String denomTable = '';
    if (totalDenominations != null) {
      List<int> denomKeys = [500, 200, 100, 50, 20, 10, 5, 1];

      Map<int, int> receivedDenoms = {};
      Map<int, int> returnDenoms = {};
      num receivedAmount = 0;
      num returnAmount = 0;

      for (int denom in denomKeys) {
        int count = totalDenominations[denom] ?? 0;
        if (count > 0) {
          receivedDenoms[denom] = count;
          receivedAmount += denom * count;
        } else if (count < 0) {
          returnDenoms[denom] = count.abs();
          returnAmount += denom * count.abs();
        }
      }

      if (receivedDenoms.isNotEmpty) {
        for (int denom in denomKeys) {
          if (receivedDenoms.containsKey(denom)) {
            int count = receivedDenoms[denom]!;
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

        denomTable += '''
        <tr>
          <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">Received</td>
          <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #e8f5e9;">$receivedAmount</td>
        </tr>
      ''';
      }

      if (returnDenoms.isNotEmpty) {
        denomTable += '''
        <tr>
          <td colspan="3" style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">Return</td>
          <td style="border: 2px solid black; padding: 4px; text-align: center; font-weight: bold; background-color: #fff3e0;">$returnAmount</td>
        </tr>
      ''';

        for (int denom in denomKeys) {
          if (returnDenoms.containsKey(denom)) {
            int count = returnDenoms[denom]!;
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
      }
    }

    int displayTotal = totalAmount.round();

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
  <style>
  
  .notes-section {
  margin: 8px 0;
  padding: 8px;
  background-color: #fff9c4;
  border: 1px solid #f57f17;
  border-radius: 4px;
}

.notes-label {
  font-size: 12px;
  font-weight: 700;
  color: #f57f17;
  margin-bottom: 4px;
}

.notes-text {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.4;
  white-space: pre-wrap;
}
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
    
    .header {
      background-color: #1976D2;
      color: white;
      font-size: 20px;
      font-weight: bold;
      padding: 8px;
      margin-bottom: 10px;
    }
   .outer-box {
  border: 3px solid black;
  padding: 0;
  margin: 0;
  box-sizing: border-box;
  background: white;
  position: relative;
}

.uncle-indicator {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 6px 0 4px 0;
    text-align: center;
    color: #000;
  }
    
.logo-header {
  display: flex;
  align-items: center;
  padding: 8px;
  gap: 10px;
}

.logo {
  width: 65px;
  height: 65px;
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
  font-size: 13px;
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
    
    .serial-no {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 8px 0;
    text-align: center;
  }
    
    .person-name {
      font-size: 16px;
      font-weight: bold;
      margin: 6px 0;
    }
    
    .village-info {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
  }
    
    .amount-label {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin-top: 10px;
  }
    
    .entry-amount {
      font-size: 20px;
      font-weight: bold;
      margin: 4px 0;
    }
    
   .total-section {
  background-color: #f5f5f5;
  padding: 10px;
  margin: 0;  // Changed from margin: 15px 0;
  border: 2px solid black;
}
    
    .total-label {
      font-size: 18px;
      font-weight: bold;
    }
    
    .total-amount {
      font-size: 26px;
      font-weight: bold;
      color: #1976D2;
      margin: 8px 0;
    }
    
   .table-title {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 0;
    padding: 8px 0;
  }
    
    table {
    width: 100%;
    border-collapse: collapse;
    margin: 0;
    font-weight: 700;  /* ✅ NEW: Make table text bold */
  }

 td {
    font-weight: 700;  /* ✅ NEW: Make all cells bold */
  }
    
    .footer {
    margin-top: 0;
    padding-top: 8px;
    font-size: 14px;
    font-weight: 700;  /* ✅ NEW */
  }
    
    .thanks {
    margin: 6px 0;
    font-weight: 700;  /* ✅ NEW */
  }
    
   .with-love {
    font-size: 12px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
  }
    
    .footer-name {
      font-size: 16px;
       font-weight: 700;
      margin: 4px 0;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  $entriesHtml
  
  <div class="total-section">
    <div class="total-label">மொத்த தொகை</div>
    <div class="total-amount">₹${_formatAmount(totalAmount)}</div>
  </div>
  
  ${denomTable.isNotEmpty ? '<div class="table-title">நோட்டு விபரம்</div>' : ''}
  ${denomTable.isNotEmpty ? '<table>$denomTable</table>' : ''}
  
  <div class="divider"></div>
  
 <div class="footer">
  <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
  <div class="with-love">அன்புடன்</div>
  ${customerName != null && customerName.isNotEmpty ? '<div class="person-details">$customerName</div>' : ''}
  ${eventTitle != null && eventTitle.isNotEmpty ? '<div class="person-details">$eventTitle</div>' : ''}
${eventTypeName != null && eventTypeName.isNotEmpty ? '<div class="person-details">$eventTypeName</div>' : ''}
${venue != null && venue.isNotEmpty ? '<div class="village-info">$venue</div>' : ''}
  ${city != null && city.isNotEmpty ? '<div class="village-info">$city</div>' : ''}
  ${customerPhone != null && customerPhone.isNotEmpty ? '<div class="phone">$customerPhone</div>' : ''}
</div>
  </div>
</body>
</html>
''';
  }

  static String _generateGroupMoiHtmlOthers({
    required int groupId,
    required String operatorName,
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required List<Map<String, dynamic>> groupEntries,
    required num totalAmount,
    String? customerName,
    String? city,
    String? customerPhone,
    required String logoBase64,
    required String fontBase64,
    String? eventTitle,
    String? eventTypeName,
    String? venue,
    String? notes,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final timeStr = DateFormat('hh.mm a').format(now);

    String entriesHtml = '';
    for (var entry in groupEntries) {
      // Build full person display like single receipt
      String personDisplay = '';
      if (entry['persons'] != null) {
        List<dynamic> personsList = entry['persons'] as List;
        if (personsList.isNotEmpty) {
          String name = personsList[0]['name'] ?? '';
          String job = personsList[0]['job'] ?? '';
          if (name.isNotEmpty) {
            personDisplay += '$name\n';
            if (job.isNotEmpty) {
              personDisplay += '$job\n';
            }
          }
        }
        if (personsList.length > 1) {
          String details = personsList[1]['details'] ?? '';
          if (details.isNotEmpty) {
            personDisplay += details;
          }
        }
      }

      String villageName = entry['village_name'] ?? '';
      String livingPlace = entry['living_place'] ?? '';
      String phone = entry['phone'] ?? '';
      bool isUncle = entry['is_uncle'] ?? false;

      var amountValue = entry['amount'];
      int amount = 0;
      if (amountValue is int) {
        amount = amountValue;
      } else if (amountValue is double) {
        amount = amountValue.round();
      } else if (amountValue is num) {
        amount = amountValue.round();
      }

      entriesHtml += '''
    <div class="entry-block">
      <div class="serial-no">வ.எண் : ${entry['serial_no']}</div>
     ${(villageName != null && villageName.isNotEmpty) || (livingPlace != null && livingPlace.isNotEmpty)
          ? '<div class="village-info">${villageName ?? ''}${(villageName != null && villageName.isNotEmpty && livingPlace != null && livingPlace.isNotEmpty) ? ' (இ) ' : ''}${livingPlace ?? ''}</div>'
          : ''}
      ${personDisplay.isNotEmpty ? '<div class="person-details" style="font-size: 14px; margin: 6px 0; white-space: pre-line;">$personDisplay</div>' : ''}
      ${isUncle ? '<div class="uncle-indicator" style="font-size: 12px; margin: 4px 0;">தாய்மாமன்</div>' : ''}
      ${phone.isNotEmpty ? '<div class="phone" style="font-size: 12px; margin: 4px 0;">($phone)</div>' : ''}
      ${notes != null && notes.isNotEmpty ? '<div class="notes-section"><div class="notes-label">குறிப்பு:</div><div class="notes-text">$notes</div></div>' : ''}
      <div class="amount-label">தொகை</div>
      <div class="entry-amount">₹${_formatAmount(amount)}</div>
    </div>
    <div class="divider"></div>
  ''';
    }

    int displayTotal = totalAmount.round();

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
  <style>
  
  .notes-section {
  margin: 8px 0;
  padding: 8px;
  background-color: #fff9c4;
  border: 1px solid #f57f17;
  border-radius: 4px;
}

.notes-label {
  font-size: 12px;
  font-weight: 700;
  color: #f57f17;
  margin-bottom: 4px;
}

.notes-text {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.4;
  white-space: pre-wrap;
}
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
    
    .header {
      background-color: #1976D2;
      color: white;
      font-size: 18px;
      font-weight: bold;
      padding: 10px;
      margin-bottom: 10px;
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
  width: 65px;
  height: 65px;
  object-fit: contain;
}

.company-info {
  width: 100%;
  text-align: center;
}
.uncle-indicator {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 6px 0 4px 0;
    text-align: center;
    color: #000;
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
  font-size: 13px;
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
    
    .entry-block {
  margin: 0;  // Changed from margin: 10px 0;
  padding: 8px 0;
}
    
    .serial-no {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin: 8px 0;
    text-align: center;
  }
    
    .person-name {
      font-size: 16px;
      font-weight: bold;
      margin: 6px 0;
    }
    
    .village-info {
    font-size: 14px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
  }
    
    .amount-label {
    font-size: 16px;
    font-weight: 700;  /* ✅ CHANGED: Keep bold */
    margin-top: 10px;
  }
    
    .entry-amount {
      font-size: 20px;
      font-weight: bold;
      margin: 4px 0;
    }
    
    .total-section {
  background-color: #f5f5f5;
  padding: 10px;
  margin: 0;  // Changed from margin: 15px 0;
  border: 2px solid black;
}
    
    .total-label {
      font-size: 18px;
      font-weight: bold;
    }
    
    .total-amount {
      font-size: 26px;
      font-weight: bold;
      color: #1976D2;
      margin: 8px 0;
    }
    
   .payment-method-box {
  border: 2px solid black;
  padding: 12px;
  margin: 0;  // Changed from margin: 15px 0;
  font-size: 16px;
  font-weight: bold;
  background-color: #f5f5f5;
}

    
    .footer {
    margin-top: 0;
    padding-top: 8px;
    font-size: 14px;
    font-weight: 700;  /* ✅ NEW */
  }
    
    .thanks {
    margin: 6px 0;
    font-weight: 700;  /* ✅ NEW */
  }
    
    .with-love {
    font-size: 12px;
    font-weight: 700;  /* ✅ CHANGED: Make bold */
    margin: 4px 0;
  }
    
    .footer-name {
      font-size: 16px;
      font-weight: 700;
      margin: 4px 0;
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
        <div class="company-phone">9043606296, 9047556443</div>
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
      <div>$operatorName</div>
    </div>
  </div>
  
  $entriesHtml
  
  <div class="total-section">
    <div class="total-label">மொத்த தொகை</div>
   <div class="total-amount">₹${_formatAmount(totalAmount)}</div>
  </div>
  
  <div class="payment-method-box">Cheque / Advance / UPI</div>
  
  <div class="divider"></div>
  
 <div class="footer">
  <div class="thanks">தங்கள் வருகைக்கு நன்றி!</div>
  <div class="with-love">அன்புடன்</div>
  ${customerName != null && customerName.isNotEmpty ? '<div class="person-details">$customerName</div>' : ''}
 ${eventTitle != null && eventTitle.isNotEmpty ? '<div class="person-details">$eventTitle</div>' : ''}
${eventTypeName != null && eventTypeName.isNotEmpty ? '<div class="person-details">$eventTypeName</div>' : ''}
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