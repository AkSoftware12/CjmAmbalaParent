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

import '../../../../constants.dart';

class DateWiseAttendanceScreen extends StatefulWidget {
  final List classes;

  const DateWiseAttendanceScreen({
    super.key, required this.classes});

  @override
  State<DateWiseAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<DateWiseAttendanceScreen> {
  List<dynamic> students = [];
  List<String> dates = [];
  bool isLoading = false;

  List<dynamic> classes = [];
  String? selectedClass;
  String? selectedSection;

  DateTime? startDate;
  DateTime? endDate;
  bool isUserPicked = false;

  String selectedStatus = "all";

  @override
  void initState() {
    super.initState();
    // fetchClassesAndSections();
  }

  String _fmtApi(DateTime? d) =>
      d == null ? "" : DateFormat('yyyy-MM-dd').format(d);

  int? _getAttendanceStatus(dynamic student, String dateKey) {
    final att = student["attendance"];

    if (att is Map) {
      final v = att[dateKey];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

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

      String url =
          '${ApiRoutes.baseUrl}/monthly-attendance'
          '?class=$selectedClass'
          '&start_date=${_fmtApi(startDate)}'
          '&end_date=${_fmtApi(endDate)}';

      if (selectedStatus != "all") {
        url += '&status=$selectedStatus';
      }

      final uri = Uri.parse(url);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Monthly Attendance API => $uri");

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

  Future<void> generateAttendancePdf() async {
    if (selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a class first")),
      );
      return;
    }

    if (!isUserPicked || startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date first")),
      );
      return;
    }

    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available for PDF")),
      );
      return;
    }

    final pdf = pw.Document();

    String className = "";

    try {
      final selected = classes.firstWhere(
            (e) => e["id"].toString() == selectedClass.toString(),
      );

      final classTitle = _safeTitle(selected["academic_class"]);
      final secTitle = _safeTitle(selected["section"]);

      className = secTitle.isNotEmpty
          ? "$classTitle ($secTitle)"
          : classTitle;
    } catch (e) {
      className = "Selected Class";
    }

    final String reportDate = DateFormat('dd-MM-yyyy').format(startDate!);

    final visibleStudents = students.where((student) {
      final attendance = student['attendance'];
      if (attendance is Map) return attendance.isNotEmpty;
      if (attendance is List) return attendance.isNotEmpty;
      return false;
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              "Attendance Report",
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Class : $className",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Date : $reportDate",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.center,
            headers: [
              "Sr. No.",
              "Roll No",
              "Adm. No.",
              "Student Name",
              ...dates.map((d) => AppDateTimeUtils.date(d)),
            ],
            data: visibleStudents.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final student = entry.value;

              return [
                index.toString(),
                (student['roll_no'] ?? "").toString(),
                (student['adm_no'] ?? "").toString(),
                (student['name'] ?? "Unknown").toString(),
                ...dates.map((d) {
                  final status = _getAttendanceStatus(student, d);
                  return _mapAttendanceStatus(status);
                }).toList(),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      "${dir.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );

    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
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

        if (tempStart != null) {
          pickerController.selectedDate = tempStart;
        } else {
          pickerController.selectedDate = null;
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.50,
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
                            "Select Date",
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
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(5.sp),
                      child: SfDateRangePicker(
                        controller: pickerController,
                        selectionMode: DateRangePickerSelectionMode.single,
                        selectionColor: Colors.red,
                        startRangeSelectionColor: Colors.red,
                        endRangeSelectionColor: Colors.red,
                        rangeSelectionColor: Colors.red.withOpacity(0.2),
                        todayHighlightColor: Colors.red,
                        onSelectionChanged:
                            (DateRangePickerSelectionChangedArgs args) {
                          if (args.value is DateTime) {
                            setModalState(() {
                              tempStart = args.value;
                              tempEnd = args.value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 10.sp, right: 10.sp),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 5),
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
                  const SizedBox(height: 50),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _safeTitle(dynamic obj) {
    if (obj is Map) return (obj["title"] ?? "").toString();
    if (obj is List && obj.isNotEmpty) {
      final first = obj.first;
      if (first is Map) return (first["title"] ?? "").toString();
    }
    return obj?.toString() ?? "";
  }

  Widget _statusFilterChip({
    required String title,
    required String value,
  }) {
    final bool isSelected = selectedStatus == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          if (selectedStatus == value) return;

          setState(() {
            selectedStatus = value;
          });

          fetchMonthlyAttendance();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 8.sp),
          decoration: BoxDecoration(
            color: isSelected ? Colors.red : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? Colors.red : Colors.grey.shade300,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: Colors.red.withOpacity(0.20),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
                : [],
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleStudents = students.where((student) {
      final attendance = student['attendance'];

      if (attendance is Map) return attendance.isNotEmpty;
      if (attendance is List) return attendance.isNotEmpty;

      return false;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors2.primary,
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40.h,
                    child: DropdownButtonFormField<String>(
                      value: selectedClass,
                      isExpanded: true,
                      items: widget.classes.map((item) {
                        final classTitle = _safeTitle(item["academic_class"]);
                        final secTitle = _safeTitle(item["section"]);

                        return DropdownMenuItem<String>(
                          value: item["id"].toString(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  secTitle.isNotEmpty
                                      ? "$classTitle ($secTitle)"
                                      : classTitle,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.sp),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClass = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Select Class",
                        hintStyle: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(Icons.class_, color: Colors.red),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.9),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.blue.shade100),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide:
                          const BorderSide(color: Colors.red, width: 0),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      icon: Container(
                        padding: const EdgeInsets.all(0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.red,
                        ),
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
                SizedBox(width: 5.sp),
                Expanded(
                  child: DateRangeSelector(
                    startDate: startDate,
                    endDate: endDate,
                    isUserPicked: isUserPicked,
                    onSelectDateRange: _selectDateRange,
                    selectedClass: selectedClass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.sp, vertical: 5.sp),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _statusFilterChip(title: "All", value: "all"),
                  SizedBox(width: 8.sp),
                  _statusFilterChip(title: "Present", value: "1"),
                  SizedBox(width: 8.sp),
                  _statusFilterChip(title: "Absent", value: "2"),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
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
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  children: [
                    SizedBox(width: 24.w),
                    Expanded(
                      child: Text(
                        'Attendance List',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // InkWell(
                    //   onTap: generateAttendancePdf,
                    //   child: Container(
                    //     padding: EdgeInsets.all(4.sp),
                    //     decoration: BoxDecoration(
                    //       color: Colors.red.withOpacity(0.1),
                    //       borderRadius: BorderRadius.circular(6.r),
                    //     ),
                    //     child: Icon(
                    //       Icons.picture_as_pdf,
                    //       color: Colors.red,
                    //       size: 18.sp,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: isLoading
                  ? const Center(child: WhiteCircularProgressWidget())
                  : visibleStudents.isEmpty
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
                  : Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      border: TableBorder.all(
                        color: Colors.black,
                        width: 1,
                      ),
                      columnSpacing: 10.w,
                      horizontalMargin: 5.w,
                      headingRowHeight: 40.h,
                      dataRowMinHeight: 0,
                      dataRowMaxHeight: 0,
                      headingRowColor: MaterialStateProperty.all(
                        Colors.blueAccent.shade100,
                      ),
                      columns: [
                        DataColumn(
                          label: SizedBox(
                            width: 35.w,
                            child: Center(
                              child: Text(
                                'Sr. No.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 40.w,
                            child: Center(
                              child: Text(
                                'Roll No',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 60.w,
                            child: Center(
                              child: Text(
                                'Adm. No.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 115.w,
                            child: Center(
                              child: Text(
                                'Student Name',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ...dates.map(
                              (date) => DataColumn(
                            label: SizedBox(
                              width: 60.w,
                              child: Center(
                                child: Text(
                                  AppDateTimeUtils.date(date),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      rows: const [],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            border: TableBorder.all(
                              color: Colors.black,
                              width: 1,
                            ),
                            columnSpacing: 10.w,
                            horizontalMargin: 5.w,
                            headingRowHeight: 0,
                            dataRowMinHeight: 30.h,
                            dataRowMaxHeight: 40.h,
                            columns: [
                              DataColumn(label: SizedBox(width: 35.w)),
                              DataColumn(label: SizedBox(width: 40.w)),
                              DataColumn(label: SizedBox(width: 60.w)),
                              DataColumn(label: SizedBox(width: 115.w)),
                              ...dates.map(
                                    (_) => DataColumn(
                                  label: SizedBox(width: 60.w),
                                ),
                              ),
                            ],
                            rows: visibleStudents
                                .asMap()
                                .entries
                                .map((entry) {
                              final index = entry.key + 1;
                              final student = entry.value;

                              return DataRow(
                                color: MaterialStateProperty
                                    .resolveWith<Color?>(
                                      (states) => index % 2 == 0
                                      ? Colors.grey.shade200
                                      : Colors.white,
                                ),
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 35.w,
                                      child: Center(
                                        child: Text(
                                          index.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 40.w,
                                      child: Center(
                                        child: Text(
                                          (student['roll_no'] ?? "")
                                              .toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 60.w,
                                      child: Center(
                                        child: Text(
                                          (student['adm_no'] ?? "")
                                              .toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 115.w,
                                      child: Center(
                                        child: Text(
                                          (student["name"] ??
                                              "Unknown")
                                              .toString(),
                                          textAlign: TextAlign.center,
                                          overflow:
                                          TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...dates.map((d) {
                                    final status =
                                    _getAttendanceStatus(
                                        student, d);

                                    return DataCell(
                                      SizedBox(
                                        width: 60.w,
                                        child: Center(
                                          child: Container(
                                            padding:
                                            EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                              _getAttendanceColor(
                                                  status),
                                              borderRadius:
                                              BorderRadius
                                                  .circular(8),
                                            ),
                                            child: Text(
                                              _mapAttendanceStatus(
                                                  status),
                                              textAlign:
                                              TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.sp,
                                                fontWeight:
                                                FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
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
          ],
        ),
      ),
    );
  }
}

class DateRangeSelector extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isUserPicked;
  final Function(BuildContext) onSelectDateRange;
  final String? selectedClass;

  const DateRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onSelectDateRange,
    required this.isUserPicked,
    this.selectedClass,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDate = isUserPicked && startDate != null;

    String dateText = "Select Date";
    if (hasDate) {
      dateText = DateFormat('dd-MM-yyyy').format(startDate!);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: () {
        if (selectedClass == null || selectedClass!.isEmpty) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Select Class First",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please select a class before choosing date.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: const Text(
                            "OK, Got it",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          return;
        }

        onSelectDateRange(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 40.h,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xffFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: hasDate ? Colors.red : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 15.sp,
              color: Colors.red,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: hasDate ? Colors.red : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20.sp,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}