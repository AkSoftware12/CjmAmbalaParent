import 'dart:convert';
import 'dart:io';

import 'package:avi/CommonCalling/progressbarWhite.dart';
import 'package:avi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../../constants.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() => _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  List<dynamic> students = [];
  List<String> dates = [];
  bool isLoading = false;

  List<dynamic> classes = [];
  String? selectedClass;
  String? selectedSection;

  DateTime? startDate;
  DateTime? endDate;
  bool isUserPicked = false; // ✅ start me false



  @override
  void initState() {
    super.initState();
    fetchClassesAndSections();
  }

  String _fmtApi(DateTime? d) => d == null ? "" : DateFormat('yyyy-MM-dd').format(d);

  // ✅ Robust: attendance can be Map OR List
  int? _getAttendanceStatus(dynamic student, String dateKey) {
    final att = student["attendance"];

    // Case 1: Map => {"2026-02-01":1, ...}
    if (att is Map) {
      final v = att[dateKey];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    // Case 2: List => [{"date":"2026-02-01","status":1}, ...]
    if (att is List) {
      for (final item in att) {
        if (item is Map) {
          final d = item["date"]?.toString();
          if (d == dateKey) {
            final v = item["status"] ?? item["attendance"] ?? item["value"];
            if (v is int) return v;
            if (v is String) return int.tryParse(v);
            return null;
          }
        }
      }
      return null;
    }

    return null;
  }

  String _mapAttendanceStatus(dynamic value) {
    switch (value) {
      case 1:
        return "P";
      case 2:
        return "A";
      case 3:
        return "L";
      case 4:
        return "H";
      default:
        return "-";
    }
  }

  Color _getAttendanceColor(dynamic value) {
    switch (value) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Fetch classes and sections dynamically from the API
  Future<void> fetchClassesAndSections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/monthly-attendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          classes = (data["data"]?["classes"] as List?) ?? [];
        });
      } else {
        throw Exception("Failed to load classes and sections");
      }
    } catch (e) {
      debugPrint("Error fetching classes and sections: $e");
    }
  }

  Future<void> fetchMonthlyAttendance() async {
    if (selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a class")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      final uri = Uri.parse(
        '${ApiRoutes.baseUrl}/monthly-attendance'
            '?class=$selectedClass'
            '&start_date=${_fmtApi(startDate)}'
            '&end_date=${_fmtApi(endDate)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          students = (data["data"]?["students"] as List?) ?? [];
          dates = List<String>.from((data["data"]?["dates"] as List?) ?? []);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        throw Exception("Failed to load attendance");
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching data: $e");
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        DateTime? tempStart = startDate;
        DateTime? tempEnd = endDate;

        final DateRangePickerController pickerController =
        DateRangePickerController();

        // ✅ Only preselect if BOTH are available
        if (tempStart != null && tempEnd != null) {
          pickerController.selectedRange = PickerDateRange(tempStart, tempEnd);
        } else {
          pickerController.selectedRange = null; // ✅ NOTHING SELECTED
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.all(0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10.sp),
                      child: Column(
                        children: [
                          Container(
                            height: 5,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Select Date Range",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 📅 Picker
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(10.sp),
                      child: SfDateRangePicker(
                        controller: pickerController,
                        selectionMode: DateRangePickerSelectionMode.range,

                        // ✅ RED THEME
                        selectionColor: Colors.red,
                        startRangeSelectionColor: Colors.red,
                        endRangeSelectionColor: Colors.red,
                        rangeSelectionColor: Colors.red.withOpacity(0.2),
                        todayHighlightColor: Colors.red,

                        onSelectionChanged:
                            (DateRangePickerSelectionChangedArgs args) {
                          if (args.value is PickerDateRange) {
                            final range = args.value as PickerDateRange;

                            setModalState(() {
                              tempStart = range.startDate;
                              tempEnd = range.endDate ?? range.startDate;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  // 🔘 Buttons Row
                  Padding(
                    padding: EdgeInsets.all(10.sp),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.red.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                // ✅ Apply only if user selected something
                                if (tempStart != null && tempEnd != null) {
                                  startDate = tempStart;
                                  endDate = tempEnd;
                                  isUserPicked = true;
                                } else {
                                  startDate = null;
                                  endDate = null;
                                  isUserPicked = false;
                                }
                              });

                              Navigator.pop(context);
                              fetchMonthlyAttendance();
                            },
                            child: const Text(
                              "Apply",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> generateAndOpenPdf(List<dynamic> students1, List<String> dates1) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Monthly Attendance Report",
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                "Total Students: ${students1.length}",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                headerHeight: 30,
                cellHeight: 22,
                headers: [
                  "Sr No.",
                  "Student ID",
                  "Roll No",
                  "Name",
                  ...dates1,
                  "P",
                  "A",
                  "L",
                  "H",
                  "%",
                ],
                data: students1.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final student = entry.value;

                  int totalP = 0, totalA = 0, totalL = 0, totalH = 0;
                  final totalDays = dates1.length;

                  final attendanceCells = dates1.map((d) {
                    final status = _getAttendanceStatus(student, d);
                    if (status == 1) totalP++;
                    if (status == 2) totalA++;
                    if (status == 3) totalL++;
                    if (status == 4) totalH++;
                    return _mapAttendanceStatus(status);
                  }).toList();

                  final pct = totalDays > 0 ? (totalP / totalDays) * 100 : 0;

                  return [
                    idx.toString(),
                    (student['student_id'] ?? "").toString(),
                    (student['roll_no'] ?? "").toString(),
                    (student["name"] ?? "Unknown").toString(),
                    ...attendanceCells,
                    totalP.toString(),
                    totalA.toString(),
                    totalL.toString(),
                    totalH.toString(),
                    "${pct.toStringAsFixed(1)}%",
                  ];
                }).toList(),
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              ),
            ],
          );
        },
      ),
    );

    final output = await getExternalStorageDirectory();
    final filePath = "${output!.path}/attendance_report.pdf";
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }

    await file.writeAsBytes(await pdf.save());
    OpenFilex.open(filePath);
  }

  // ✅ Safe helper: academic_class / section can be Map or List
  String _safeTitle(dynamic obj) {
    if (obj is Map) return (obj["title"] ?? "").toString();
    if (obj is List && obj.isNotEmpty) {
      final first = obj.first;
      if (first is Map) return (first["title"] ?? "").toString();
    }
    return obj?.toString() ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors2.primary,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // ✅ Dropdown card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                // ✅ Expanded removed (Expanded only inside Row/Column/Flex)
                child: DropdownButtonFormField<String>(
                  value: selectedClass,
                  items: classes.map((item) {
                    final classTitle = _safeTitle(item["academic_class"]);
                    final secTitle = _safeTitle(item["section"]);
                    return DropdownMenuItem<String>(
                      value: item["id"].toString(),
                      child: Text(
                        secTitle.isNotEmpty ? "$classTitle ($secTitle)" : classTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedClass = value;
                      // agar aapko section chahiye:
                      // selectedSection = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Select Class",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                  dropdownColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Date selector
            DateRangeSelector(
              startDate: startDate,
              endDate: endDate,
              isUserPicked: isUserPicked,
              onSelectDateRange: _selectDateRange,
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child:  Padding(
                padding: EdgeInsets.all(0.0),
                child: Text(
                  'Attendance List',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.black),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 5),

            Expanded(
              child: isLoading
                  ? const Center(child: WhiteCircularProgressWidget())
                  : students.isEmpty
                  ? Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.red.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔴 Icon with gradient background
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade400,
                              Colors.red.shade700,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.event_busy,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 5),

                      // 📌 Title
                      Text(
                        "No Attendance Found",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),

                       SizedBox(height: 5.sp),

                      // 📌 Subtitle
                      Text(
                        "Attendance records are not available yet.\nPlease check back later.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),


                    ],
                  ),
                ),
              )
                  : Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      border: TableBorder.all(color: Colors.black, width: 1),
                      headingRowColor: MaterialStateProperty.all(Colors.blueAccent.shade100),
                      columns: [
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Sr No.',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Roll No',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Admission No.',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Student Name",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                        ...dates.map(
                              (date) => DataColumn(
                            label: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                AppDateTimeUtils.date(date),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Working Days",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Total Present",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Total Absent",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                        const DataColumn(
                          label: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Total Leave",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          ),
                        ),
                      ],
                      rows: students.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final student = entry.value;

                        int totalP = 0, totalA = 0, totalL = 0, totalH = 0;

                        for (final d in dates) {
                          final status = _getAttendanceStatus(student, d);
                          if (status == 1) totalP++;
                          if (status == 2) totalA++;
                          if (status == 3) totalL++;
                          if (status == 4) totalH++;
                        }

                        return DataRow(
                          color: MaterialStateProperty.resolveWith<Color?>((states) {
                            return index % 2 == 0 ? Colors.grey.shade200 : Colors.white;
                          }),
                          cells: [
                            DataCell(Center(
                              child: Text(index.toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            )),
                            DataCell(Center(
                              child: Text((student['roll_no'] ?? "").toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            )),
                            DataCell(Center(
                              child: Text((student['adm_no'] ?? "").toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            )),
                            DataCell(Center(
                              child: Text((student["name"] ?? "Unknown").toString(),
                                  style: const TextStyle(fontSize: 15)),
                            )),
                            ...dates.map((d) {
                              final status = _getAttendanceStatus(student, d);
                              return DataCell(
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getAttendanceColor(status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _mapAttendanceStatus(status),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),

                            DataCell(Center(
                              child: Text((student["summary"]['working_days'] ?? "Unknown").toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                            )),
                            DataCell(Center(
                              child: Text(totalP.toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                            )),
                            DataCell(Center(
                              child: Text(totalA.toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                            )),
                            DataCell(Center(
                              child: Text(totalL.toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateRangeSelector extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isUserPicked; // ✅ NEW
  final Function(BuildContext) onSelectDateRange;

  const DateRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onSelectDateRange,
    required this.isUserPicked,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFE53935);
    const bg = Color(0xFFF8FAFC);

    final bool showRange = isUserPicked && startDate != null && endDate != null;

    String dateText = "Select Date Range";
    if (showRange) {
      dateText =
      "${DateFormat('dd-MM-yyyy').format(startDate!)} → ${DateFormat('dd-MM-yyyy').format(endDate!)}";
    }

    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => onSelectDateRange(context),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dateText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}