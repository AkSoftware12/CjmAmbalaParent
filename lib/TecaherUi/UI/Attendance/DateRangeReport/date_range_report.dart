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

class DateRangeAttendanceScreen extends StatefulWidget {
  const DateRangeAttendanceScreen({super.key});

  @override
  State<DateRangeAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<DateRangeAttendanceScreen> {
  List<dynamic> students = [];
  List<String> dates = [];
  bool isLoading = false;

  List<dynamic> classes = [];
  String? selectedClass;
  String? selectedSection;

  DateTime? startDate;
  DateTime? endDate;
  bool isUserPicked = false;

  @override
  void initState() {
    super.initState();
    fetchClassesAndSections();
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

      final url =
          '${ApiRoutes.baseUrl}/monthly-attendance'
          '?class=$selectedClass'
          '&start_date=${_fmtApi(startDate)}'
          '&end_date=${_fmtApi(endDate)}';

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

        if (tempStart != null && tempEnd != null) {
          pickerController.selectedRange = PickerDateRange(tempStart, tempEnd);
        } else {
          pickerController.selectedRange = null;
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
                            "Select Date ",
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
                        selectionMode: DateRangePickerSelectionMode.range,
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
            SizedBox(
              height: 30.h,
              child: DropdownButtonFormField<String>(
                value: selectedClass,
                isExpanded: true,
                items: classes.map((item) {
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
            const SizedBox(height: 8),

            DateRangeSelector(
              startDate: startDate,
              endDate: endDate,
              isUserPicked: isUserPicked,
              onSelectDateRange: _selectDateRange,
              selectedClass: selectedClass,
            ),

            const SizedBox(height: 8),
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
              child: Padding(
                padding: EdgeInsets.all(0.0),
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
            ),
            const SizedBox(height: 5),
            Expanded(
              child: isLoading
                  ? const Center(child: WhiteCircularProgressWidget())
                  : (() {
                final visibleStudents = students.where((student) {
                  final attendance = student['attendance'];

                  if (attendance is Map) return attendance.isNotEmpty;
                  if (attendance is List) return attendance.isNotEmpty;

                  return false;
                }).toList();

                return visibleStudents.isEmpty
                    ? Center(
                  child: Container(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 20),
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
                    : Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        border: TableBorder.all(
                            color: Colors.black, width: 1),
                        headingRowColor: MaterialStateProperty.all(
                          Colors.blueAccent.shade100,
                        ),
                        columns: [
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Sr No.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Roll No',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Admission No.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Student Name",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          ...dates.map(
                                (date) => DataColumn(
                              label: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  AppDateTimeUtils.date(date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Working Days",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Total Present",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Total Absent",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Total Leave",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                        rows: visibleStudents.asMap().entries.map(
                              (entry) {
                            final index = entry.key + 1;
                            final student = entry.value;

                            int totalP = 0,
                                totalA = 0,
                                totalL = 0,
                                totalH = 0;

                            for (final d in dates) {
                              final status =
                              _getAttendanceStatus(student, d);
                              if (status == 1) totalP++;
                              if (status == 2) totalA++;
                              if (status == 3) totalL++;
                              if (status == 4) totalH++;
                            }

                            return DataRow(
                              color: MaterialStateProperty
                                  .resolveWith<Color?>(
                                    (states) {
                                  return index % 2 == 0
                                      ? Colors.grey.shade200
                                      : Colors.white;
                                },
                              ),
                              cells: [
                                DataCell(
                                  Center(
                                    child: Text(
                                      index.toString(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      (student['roll_no'] ?? "")
                                          .toString(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      (student['adm_no'] ?? "")
                                          .toString(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      (student["name"] ?? "Unknown")
                                          .toString(),
                                      style: const TextStyle(
                                          fontSize: 15),
                                    ),
                                  ),
                                ),
                                ...dates.map((d) {
                                  final status =
                                  _getAttendanceStatus(
                                      student, d);
                                  return DataCell(
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                          _getAttendanceColor(
                                              status),
                                          borderRadius:
                                          BorderRadius.circular(
                                              8),
                                        ),
                                        child: Text(
                                          _mapAttendanceStatus(
                                              status),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                DataCell(
                                  Center(
                                    child: Text(
                                      (student["summary"]
                                      ?['working_days'] ??
                                          "0")
                                          .toString(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      totalP.toString(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      totalA.toString(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      totalL.toString(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ).toList(),
                      ),
                    ),
                  ),
                );
              })(),
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
    final bool hasDate = isUserPicked && startDate != null && endDate != null;
    String dateText = "Select Date Range";
    if (hasDate) { dateText = "${DateFormat('dd-MM-yyyy').format(startDate!)} - ${DateFormat('dd-MM-yyyy').format(endDate!)}"; }

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
        height: 30.h,
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