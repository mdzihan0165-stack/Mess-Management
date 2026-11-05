import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text, Colors;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class MessPdfHelper {
  /// Generate the complete monthly statement PDF document
  static Future<pw.Document> generateReport({
    required String messName,
    required String messCode,
    required String month,
    required String managerName,
    required double totalBazaar,
    required int totalMeals,
    required double mealRate,
    required List memberSummaries,
    String? notice,
  }) async {
    final doc = pw.Document(
      title: 'Mess Report - $messName ($month)',
      author: 'Smart Mess Management System',
    );

    // Collect all distinct dates from member dailyMeals
    Set<String> allDatesSet = {};
    for (var m in memberSummaries) {
      Map daily = m['dailyMeals'] ?? {};
      daily.forEach((k, v) {
        if (v is Map) {
          int count = (int.tryParse((v['lunch'] ?? 0).toString()) ?? 0) +
              (int.tryParse((v['dinner'] ?? 0).toString()) ?? 0);
          if (count > 0) {
            allDatesSet.add(k.toString());
          }
        }
      });
    }
    List<String> sortedDates = allDatesSet.toList()..sort();

    // Collect all bazaar entries with date & time
    List<Map<String, dynamic>> allBazaarEntries = [];
    for (var m in memberSummaries) {
      List entries = m['bazaar_entries'] ?? [];
      for (var e in entries) {
        allBazaarEntries.add({
          'date': (e['date'] ?? '').toString(),
          'time': (e['time'] ?? '').toString(),
          'member_name': (m['name'] ?? 'Member').toString(),
          'amount': double.tryParse((e['amount'] ?? 0).toString()) ?? 0.0,
          'note': (e['note'] ?? '').toString(),
        });
      }
    }
    allBazaarEntries.sort((a, b) =>
        '${a['date']} ${a['time']}'.compareTo('${b['date']} ${b['time']}'));

    // Primary Colors
    const primaryColor = PdfColor.fromInt(0xFF1B5E20); // Dark Green
    const secondaryColor = PdfColor.fromInt(0xFF2E7D32); // Medium Green
    const accentColor = PdfColor.fromInt(0xFFFFA000); // Amber

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        messName.isNotEmpty ? messName.toUpperCase() : 'SMART MESS MANAGEMENT',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Monthly Meal & Expense Report - $month',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Mess Code: $messCode | Manager: $managerName',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: secondaryColor,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'OFFICIAL STATEMENT',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: primaryColor, thickness: 1.5),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Smart Mess Management System',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. FINANCIAL HIGHLIGHTS SUMMARY BOX
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: secondaryColor, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBox('Total Mess Bazaar', '${totalBazaar.toStringAsFixed(2)} Tk', primaryColor),
                  _buildStatBox('Total Mess Meals', '$totalMeals Meals', primaryColor),
                  _buildStatBox('Meal Rate', '${mealRate.toStringAsFixed(2)} Tk', accentColor),
                  _buildStatBox('Active Members', '${memberSummaries.length}', primaryColor),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 2. MEMBER FINANCIAL SUMMARY TABLE
            pw.Text(
              '1. MEMBER ACCOUNTS SUMMARY',
              style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(24), // #
                1: const pw.FlexColumnWidth(3),   // Name & Email
                2: const pw.FlexColumnWidth(1.5), // Total Meals
                3: const pw.FlexColumnWidth(2),   // Bazaar Given
                4: const pw.FlexColumnWidth(2),   // Meal Cost
                5: const pw.FlexColumnWidth(2),   // Balance
                6: const pw.FlexColumnWidth(1.5), // Status
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: primaryColor),
                  children: [
                    _tableHeaderCell('#'),
                    _tableHeaderCell('Member Name'),
                    _tableHeaderCell('Meals'),
                    _tableHeaderCell('Bazaar (Tk)'),
                    _tableHeaderCell('Cost (Tk)'),
                    _tableHeaderCell('Balance (Tk)'),
                    _tableHeaderCell('Status'),
                  ],
                ),
                ...memberSummaries.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var m = entry.value;
                  double b = double.tryParse((m['bazaar'] ?? 0).toString()) ?? 0.0;
                  int meals = int.tryParse((m['meals'] ?? 0).toString()) ?? 0;
                  double cost = double.tryParse((m['cost'] ?? 0).toString()) ?? (meals * mealRate);
                  double balance = double.tryParse((m['balance'] ?? 0).toString()) ?? (b - cost);

                  String statusText = balance >= 0 ? 'RETURN' : 'DUE';
                  PdfColor statusColor = balance >= 0 ? PdfColors.green800 : PdfColors.red800;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx.isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      _tableBodyCell('${idx + 1}', align: pw.TextAlign.center),
                      _tableBodyCell('${m['name'] ?? ''}\n(${m['email'] ?? ''})'),
                      _tableBodyCell('$meals', align: pw.TextAlign.center),
                      _tableBodyCell(b.toStringAsFixed(2), align: pw.TextAlign.right),
                      _tableBodyCell(cost.toStringAsFixed(2), align: pw.TextAlign.right),
                      _tableBodyCell(
                        '${balance >= 0 ? '+' : ''}${balance.toStringAsFixed(2)}',
                        align: pw.TextAlign.right,
                        color: statusColor,
                        bold: true,
                      ),
                      _tableBodyCell(statusText, align: pw.TextAlign.center, color: statusColor, bold: true),
                    ],
                  );
                }),
                // Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableBodyCell('', align: pw.TextAlign.center),
                    _tableBodyCell('TOTAL', bold: true),
                    _tableBodyCell('$totalMeals', align: pw.TextAlign.center, bold: true),
                    _tableBodyCell(totalBazaar.toStringAsFixed(2), align: pw.TextAlign.right, bold: true),
                    _tableBodyCell((totalMeals * mealRate).toStringAsFixed(2), align: pw.TextAlign.right, bold: true),
                    _tableBodyCell('0.00', align: pw.TextAlign.right, bold: true),
                    _tableBodyCell('BALANCED', align: pw.TextAlign.center, bold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // 3. DAY-BY-DAY MEAL BREAKDOWN
            pw.Text(
              '2. DAY-BY-DAY MEAL RECORD',
              style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Whose meals were active on which dates day-by-day:',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),

            if (sortedDates.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text('No daily meals recorded for this month.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              )
            else
              _buildDayByDayMealTable(sortedDates, memberSummaries, primaryColor),

            pw.SizedBox(height: 16),

            // 4. BAZAAR DATE & TIME RECORDS
            pw.Text(
              '3. BAZAAR EXPENSE LOG',
              style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Detailed record of all bazaar expenses with exact date, time, and member:',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),

            if (allBazaarEntries.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  totalBazaar > 0
                      ? 'Total Bazaar: ${totalBazaar.toStringAsFixed(2)} Tk (Detailed date-wise entries were not logged individually).'
                      : 'No bazaar expenses recorded.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(24), // #
                  1: const pw.FlexColumnWidth(2),   // Date
                  2: const pw.FlexColumnWidth(1.8), // Time
                  3: const pw.FlexColumnWidth(2.5), // Member Name
                  4: const pw.FlexColumnWidth(2),   // Amount (Tk)
                  5: const pw.FlexColumnWidth(3),   // Note / Details
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: secondaryColor),
                    children: [
                      _tableHeaderCell('#'),
                      _tableHeaderCell('Bazaar Date'),
                      _tableHeaderCell('Time'),
                      _tableHeaderCell('Member'),
                      _tableHeaderCell('Amount (Tk)'),
                      _tableHeaderCell('Item Note / Details'),
                    ],
                  ),
                  ...allBazaarEntries.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var item = entry.value;
                    double amt = item['amount'] as double;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: idx.isEven ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: [
                        _tableBodyCell('${idx + 1}', align: pw.TextAlign.center),
                        _tableBodyCell(item['date'] ?? '-', align: pw.TextAlign.center),
                        _tableBodyCell(item['time'] ?? '-', align: pw.TextAlign.center),
                        _tableBodyCell(item['member_name'] ?? '-'),
                        _tableBodyCell(amt.toStringAsFixed(2), align: pw.TextAlign.right, bold: true),
                        _tableBodyCell(item['note']?.toString().isNotEmpty == true ? item['note'].toString() : '-'),
                      ],
                    );
                  }),
                  // Total row for bazaar
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableBodyCell('', align: pw.TextAlign.center),
                      _tableBodyCell('TOTAL', bold: true),
                      _tableBodyCell(''),
                      _tableBodyCell(''),
                      _tableBodyCell(totalBazaar.toStringAsFixed(2), align: pw.TextAlign.right, bold: true),
                      _tableBodyCell(''),
                    ],
                  ),
                ],
              ),

            pw.SizedBox(height: 20),

            // 5. NOTICE & SIGNATURE SECTION
            if (notice != null && notice.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: accentColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Manager Notice:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown900)),
                    pw.SizedBox(height: 2),
                    pw.Text(notice, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),
            ] else ...[
              pw.SizedBox(height: 20),
            ],

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text('Mess Manager Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text('Member Representative', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc;
  }

  /// Builds day-by-day meal matrix table
  static pw.Widget _buildDayByDayMealTable(
    List<String> dates,
    List memberSummaries,
    PdfColor primaryColor,
  ) {
    // If fewer than or equal to 5 members, display in a neat matrix table:
    // Date | M1 (L/D) | M2 (L/D) | ... | Total
    if (memberSummaries.length <= 5) {
      Map<int, pw.TableColumnWidth> colWidths = {
        0: const pw.FixedColumnWidth(60), // Date
      };
      for (int i = 0; i < memberSummaries.length; i++) {
        colWidths[i + 1] = const pw.FlexColumnWidth(2);
      }
      colWidths[memberSummaries.length + 1] = const pw.FixedColumnWidth(40); // Day total

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: colWidths,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
            children: [
              _tableHeaderCell('Date'),
              ...memberSummaries.map((m) => _tableHeaderCell('${m['name']}\n(L/D)')),
              _tableHeaderCell('Total'),
            ],
          ),
          ...dates.asMap().entries.map((entry) {
            int dIdx = entry.key;
            String dt = entry.value;
            int dayTotal = 0;

            List<pw.Widget> cells = [
              _tableBodyCell(dt, align: pw.TextAlign.center),
            ];

            for (var m in memberSummaries) {
              Map daily = m['dailyMeals'] ?? {};
              var dayData = daily[dt];
              int l = 0;
              int d = 0;
              if (dayData is Map) {
                l = int.tryParse((dayData['lunch'] ?? 0).toString()) ?? 0;
                d = int.tryParse((dayData['dinner'] ?? 0).toString()) ?? 0;
              }
              int count = l + d;
              dayTotal += count;

              String text = count > 0 ? '$l / $d' : '-';
              cells.add(_tableBodyCell(text, align: pw.TextAlign.center));
            }

            cells.add(_tableBodyCell('$dayTotal', align: pw.TextAlign.center, bold: true));

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: dIdx.isEven ? PdfColors.white : PdfColors.grey50,
              ),
              children: cells,
            );
          }),
        ],
      );
    } else {
      // More than 5 members: display member-wise breakdown list with active dates
      return pw.Column(
        children: memberSummaries.map<pw.Widget>((m) {
          String name = (m['name'] ?? '').toString();
          Map daily = m['dailyMeals'] ?? {};

          List<String> memberActiveDates = [];
          daily.forEach((k, v) {
            if (v is Map) {
              int total = (int.tryParse((v['lunch'] ?? 0).toString()) ?? 0) +
                  (int.tryParse((v['dinner'] ?? 0).toString()) ?? 0);
              if (total > 0) {
                memberActiveDates.add('$k: L=${v['lunch'] ?? 0}, D=${v['dinner'] ?? 0} (Total: $total)');
              }
            }
          });

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('$name (Total: ${m['meals']} meals)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: primaryColor)),
                    pw.Text('${memberActiveDates.length} days active',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 3),
                if (memberActiveDates.isEmpty)
                  pw.Text('No meals active this month',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))
                else
                  pw.Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: memberActiveDates.map((item) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Text(item, style: const pw.TextStyle(fontSize: 7.5)),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }

  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _tableBodyCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = PdfColors.black,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Trigger PDF download in browser / on mobile
  static Future<void> downloadPdf({
    required pw.Document document,
    required String filename,
    BuildContext? context,
  }) async {
    try {
      final bytes = await document.save();
      await Printing.sharePdf(bytes: bytes, filename: filename);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Download Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Open browser print / preview dialog
  static Future<void> printOrPreview({
    required pw.Document document,
    required String filename,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => document.save(),
      name: filename,
    );
  }
}
