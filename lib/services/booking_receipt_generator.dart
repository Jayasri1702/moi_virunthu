import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class BookingReceiptGenerator {
  static Future<File?> generateBookingReceipt({
    required BuildContext context,
    required String customerName,
    required String contactNumber,
    required String eventTypeName,
    required DateTime selectedDate,
    TimeOfDay? selectedTime,
    String? venue,
    String? city,
    String? eventFor,
  }) async {
    try {
      final pdf = pw.Document();

      // Format date
      String formattedDate = DateFormat('dd-MM-yyyy').format(selectedDate);

      // Tamil labels
      const String tamilEventType = 'தேதி';  // Date
      const String tamilDate = 'மண்டபம்';    // Venue (Hall)
      const String tamilVenue = 'கம்ப்யூட்டர் எண்ணிக்கை';  // Computer Count
      const String tamilLocation = 'புக்கிங் தொகை';  // Booking Amount
      const String tamilAdvance = 'அட்வான்ஸ்';  // Advance
      const String tamilTime = 'மீதம்';  // Balance

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context pdfContext) {
            return pw.Column(
              children: [
                // Green Header with Logo and Company Details
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                  color: PdfColor.fromHex('#0B6623'),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo placeholder
                      pw.Container(
                        width: 100,
                        height: 100,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Center(
                          child: pw.Icon(
                            const pw.IconData(0xe0cd),  // phone icon
                            size: 50,
                            color: PdfColor.fromHex('#0B6623'),
                          ),
                        ),
                      ),

                      // Company Details
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Hi Tech Moi',
                            style: pw.TextStyle(
                              fontSize: 32,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Cheekanurani, Madurai - 625 514.',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Mobile: 9043606296, 9047556443',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Customer Details Section
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  color: PdfColors.white,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                'Customer Name : ',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Container(
                                width: 200,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    bottom: pw.BorderSide(width: 1),
                                  ),
                                ),
                                child: pw.Text(
                                  customerName,
                                  style: const pw.TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          pw.Text(
                            'Date : $formattedDate',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 15),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Contact Number : ',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Container(
                            width: 200,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(width: 1),
                              ),
                            ),
                            child: pw.Text(
                              contactNumber,
                              style: const pw.TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Booking Details Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 15),
                  color: PdfColor.fromHex('#0B6623'),
                  child: pw.Center(
                    child: pw.Text(
                      'Booking Details',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),

                // Booking Details Table
                pw.Container(
                  width: double.infinity,
                  child: pw.Table(
                    border: pw.TableBorder.all(width: 2),
                    children: [
                      // Row 1: Event Type (தேதி)
                      _buildTableRow(tamilEventType, formattedDate),

                      // Row 2: Venue (மண்டபம்)
                      _buildTableRow(tamilDate, venue ?? ''),

                      // Row 3: Computer Count (கம்ப்யூட்டர் எண்ணிக்கை)
                      _buildTableRow(tamilVenue, eventTypeName),

                      // Row 4: Location (புக்கிங் தொகை)
                      _buildTableRow(tamilLocation, city ?? ''),

                      // Row 5: Advance (அட்வான்ஸ்)
                      _buildTableRow(tamilAdvance, eventFor ?? ''),

                      // Row 6: Balance (மீதம்)
                      _buildTableRow(tamilTime, ''),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Footer Message
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 30),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'அன்பார்ந்த வாடிக்கையாளரே,',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        '1. பில்லுவரும் பொருட்களை விழா நாளன்று ஏற்பாடு செய்து வைக்கவும்.\n   (டேபிள், சேர், சிறிய நோட்டு, பேனா மற்றும் ரப்பர் போட்).',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        '2. எங்களது நேரம் காலை 9 மணி முதல் மாலை 3 மணி வரை.',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        '3. விழா முடிந்துவன்று மண்டபத்தில் கணக்கு முடித்தவரை உடனுக்குடன்\n   மொபைல் நோட்டு வழங்கப்படும். பின்பு 10 நாட்கள் குமிந்து வீட்டிற்கு வந்த மொய்\n   விவரங்களை நீங்கள் விரும்பும் பட்சத்தில் அவற்றையும் ஏற்றி 2வது நோட்டு\n   வழங்கப்படும். அதற்கு தனிக்கட்டணம்.',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        '4. எக்காரணத்தைக்கொண்டும் முன்பணம் திருப்பிக்கொடுக்கப்பட மாட்டாது.',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Center(
                        child: pw.Text(
                          'Thank you for booking us!',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/booking_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      print('Error generating booking receipt: $e');
      return null;
    }
  }

  static pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(15),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}