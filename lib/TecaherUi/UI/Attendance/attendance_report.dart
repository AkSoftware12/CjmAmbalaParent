import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:open_filex/open_filex.dart';

import '../../../constants.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  @override
  _MonthlyAttendanceScreenState createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  List<dynamic> students = [];
  List<String> dates = [];
  bool isLoading = false;
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  List<dynamic> classes = [];
  List<dynamic> sections = [];
  String? selectedClass;
  String? selectedSection;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _initializeDefaultDates();
    fetchClassesAndSections();
  }

  /// Set default start and end dates to the first and last day of the current month
  void _initializeDefaultDates() {
    DateTime now = DateTime.now();
    selectedStartDate = DateTime(now.year, now.month, 1); // 1st day of month
    selectedEndDate = DateTime(now.year, now.month + 1, 0); // Last day of month
  }

  /// Fetch classes and sections dynamically from the API
  Future<void> fetchClassesAndSections() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('teachertoken');

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
          classes = data["data"]["classes"];
          sections = data["data"]["sections"];
        });
      } else {
        throw Exception("Failed to load classes and sections");
      }
    } catch (error) {
      print("Error fetching classes and sections: $error");
    }
  }

  Future<void> fetchMonthlyAttendance() async {
    if (selectedClass == null || selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a class and section")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('teachertoken');

      final response = await http.get(
        Uri.parse(
            '${ApiRoutes.baseUrl}/monthly-attendance?class=$selectedClass&section=$selectedSection&start_date=$startDate&end_date=$endDate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          students = data["data"]["students"];
          dates = List<String>.from(data["data"]["dates"]);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        throw Exception("Failed to load attendance");
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching data: $error");
    }
  }

  String _mapAttendanceStatus(dynamic value) {
    switch (value) {
      case 1:
        return "P"; // Present
      case 2:
        return "A"; // Absent
      case 3:
        return "L"; // Late
      case 4:
        return "H"; // Half-day
      default:
        return "-"; // Unknown or not recorded
    }
  }

  Color _getAttendanceColor(dynamic value) {
    switch (value) {
      case 1:
        return Colors.green; // P - Present
      case 2:
        return Colors.red; // A - Absent
      case 3:
        return Colors.blue; // L - Late
      case 4:
        return Colors.orange; // H - Half-day
      default:
        return Colors.grey; // Default color for unknown values
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Date Range",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: SfDateRangePicker(
                  selectionMode: DateRangePickerSelectionMode.range,
                  selectionTextStyle: TextStyle(
                    color: Colors.white
                  ),
                  selectionShape: DateRangePickerSelectionShape.circle,
                  onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                    if (args.value is PickerDateRange) {
                      setState(() {
                        startDate = args.value.startDate;
                        endDate = args.value.endDate;
                      });
                    }
                  },
                ),
              ),

              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  if (startDate == null || endDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Please select a valid date range")),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  fetchMonthlyAttendance();
                },
                icon: Icon(Icons.check),
                label: Text("Apply Date Range"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }




  Future<void> generateAndOpenPdf(List<dynamic> students1, List<String> dates1) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.all(10),
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
                "Total Students: ${students.length}",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),

              pw.TableHelper.fromTextArray(
                context: context,
                headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
                headerHeight: 30,
                cellHeight: 50,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  for (int i = 4; i < 4 + dates.length; i++) i: pw.Alignment.center,
                  4 + dates.length: pw.Alignment.center,
                  5 + dates.length: pw.Alignment.center,
                  6 + dates.length: pw.Alignment.center,
                  7 + dates.length: pw.Alignment.center,
                  8 + dates.length: pw.Alignment.center,
                },
                headers: [
                  "Sr No.",
                  "Student ID",
                  "Roll No",
                  "Name",
                  ...dates1,
                  "P", "A", "L", "H", "%" // Attendance summary
                ],
                data: students1.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  var student = entry.value;

                  int totalP = 0, totalA = 0, totalL = 0, totalH = 0;
                  int totalDays = dates1.length;

                  List<String> attendanceData = dates1.map((date) {
                    int? status = student["attendance"]?[date];
                    if (status == 1) totalP++;
                    if (status == 2) totalA++;
                    if (status == 3) totalL++;
                    if (status == 4) totalH++;
                    return _mapAttendanceStatus(status);
                  }).toList();

                  double attendancePercentage = totalDays > 0 ? (totalP / totalDays) * 100 : 0;

                  return [
                    index.toString(),
                    student['student_id'].toString(),
                    student['roll_no'].toString(),
                    student["name"] ?? "Unknown",
                    ...attendanceData,
                    totalP.toString(),
                    totalA.toString(),
                    totalL.toString(),
                    totalH.toString(),
                    "${attendancePercentage.toStringAsFixed(1)}%"
                  ];
                }).toList(),

                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                cellStyle: pw.TextStyle(fontSize: 9),
                headerPadding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                cellPadding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF
    final output = await getExternalStorageDirectory();
    final filePath = "${output!.path}/attendance_report.pdf";
    final file = File(filePath);

    // Purani file delete karna (agar chahiye toh)
    if (await file.exists()) {
      await file.delete();
    }

    await file.writeAsBytes(await pdf.save());

    print("Updated PDF with ${students1.length} students.");

    // Open PDF
    OpenFilex.open(filePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors2.primary,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
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
                padding: EdgeInsets.all(5.0),
                child:         Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField(
                        value: selectedClass,
                        items: classes.map((item) {
                          return DropdownMenuItem(
                            value: item["id"].toString(),
                            child: Text(item["title"].toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedClass = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: "Select Class",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: TextStyle(fontSize: 16,color: Colors.black),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                        dropdownColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField(
                        value: selectedSection,
                        items: sections.map((item) {
                          return DropdownMenuItem(
                            value: item["id"].toString(),
                            child: Text(item["title"].toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSection = value.toString();
                          });

                        },
                        decoration: InputDecoration(
                          labelText: "Select Section",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: TextStyle(fontSize: 16,color: Colors.black),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                        dropdownColor: Colors.white,
                      ),
                    ),
                  ],
                ),

              ),
            ),

            // Dropdowns for Class and Section

            SizedBox(height: 10),

            // Date Selection Row
            DateRangeSelector(
              startDate: startDate,
              endDate: endDate,
              onSelectDateRange: _selectDateRange,
            ),
            SizedBox(height: 10,),

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
                padding: EdgeInsets.all(5.0),
                child: Text('Attendance List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black), textAlign: TextAlign.center),
              ),
            ),
            SizedBox(height: 10,),

            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : students.isEmpty
                  ? Center(child: Text("No attendance records found"))
                  : Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(color: Colors.black, width: 1),
                    headingRowColor: MaterialStateProperty.all(Colors.blueAccent.shade100),
                    columns: [
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Sr No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black), textAlign: TextAlign.center),
                        ),
                      ),
                      ...dates.map((date) => DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(date, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black), textAlign: TextAlign.center),
                        ),
                      )).toList(),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Total Present", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Total Absent", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Total Leave", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Total Holiday", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(" Total Percentage ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        ),
                      ),
                    ],
                    rows: students.asMap().entries.map((entry) {
                      int index = entry.key + 1; // Sr No. (starting from 1)
                      var student = entry.value;

                      int totalP = 0, totalA = 0, totalL = 0, totalH = 0;
                      int totalDays = dates.length;

                      for (var date in dates) {
                        int? status = student["attendance"]?[date];
                        if (status == 1) totalP++; // Present
                        if (status == 2) totalA++; // Absent
                        if (status == 3) totalL++; // Late
                        if (status == 4) totalH++; // Half-day
                      }

                      double attendancePercentage = totalDays > 0 ? (totalP / totalDays) * 100 : 0;

                      return DataRow(
                        color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                          return index % 2 == 0 ? Colors.grey.shade200 : Colors.white;
                        }),
                        cells: [
                          DataCell(Center(child: Text(index.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
                          DataCell(Center(child: Text(student['student_id'].toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))),
                          DataCell(Center(child: Text(student['roll_no'].toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))),
                          DataCell(Center(child: Text(student["name"] ?? "Unknown", textAlign: TextAlign.center, style: TextStyle(fontSize: 15)))),
                          ...dates.map((date) {
                            int? status = student["attendance"]?[date];
                            return DataCell(
                              Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getAttendanceColor(status),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_mapAttendanceStatus(status), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                ),
                              ),
                            );
                          }).toList(),
                          DataCell(Center(child: Text(totalP.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)))),
                          DataCell(Center(child: Text(totalA.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)))),
                          DataCell(Center(child: Text(totalL.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)))),
                          DataCell(Center(child: Text(totalH.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange)))),
                          DataCell(Center(child: Text("${attendancePercentage.toStringAsFixed(2)}%", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.purple)))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: Colors.blue.shade200,
      //   onPressed: (){
      //     generateAndOpenPdf(students, dates);
      //
      //   },
      //   child: Icon(Icons.picture_as_pdf,color: Colors.white,),
      // ),
    );
  }
}


class DateRangeSelector extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(BuildContext) onSelectDateRange;

  const DateRangeSelector({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.onSelectDateRange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: () => onSelectDateRange(context),
            icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
            label: const Text(
              "Select Date Range",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: Colors.blueAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16), // Spacing between button and container
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRow("From:", startDate),
                  const Divider(height: 10, color: Colors.blueAccent),
                  _buildDateRow("To:", endDate),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, DateTime? date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        Text(
          date != null ? DateFormat('dd-MM-yyyy').format(date) : "Select Date",
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
