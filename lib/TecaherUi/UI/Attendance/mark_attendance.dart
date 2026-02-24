
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../../../constants.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> students = [];
  DateTime selectedDate = DateTime.now();
  int? selectedClass;
  int? selectedSection;
  bool isLoading = true;
  Map<String, int> attendanceStatus = {}; // Using String for student_id
  List<String> studentIds = [];
  List<String> notes = [];
  List<int> attendances = [];
  int? globalAttendance; // Stores global selection

  @override
  void initState() {
    super.initState();
    fetchClassesAndSections();
    _initializeDefaultDates();
  }

  void _initializeDefaultDates() {
    DateTime now = DateTime.now();

    setState(() {
      selectedDate = DateTime.now();
    });
  }


  Future<void> fetchClassesAndSections() async {

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('teachertoken');

      final response = await http.get(
        Uri.parse(
            '${ApiRoutes.baseUrl}/teacher-student-atttendance?class=$selectedClass'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        setState(() {
          classes =
          List<Map<String, dynamic>>.from(responseData['data']['classes']);
          sections =
          List<Map<String, dynamic>>.from(responseData['data']['sections']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load class and section data');
      }
    } catch (e) {
      print('Error fetching classes and sections: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchAttendance() async {
    if (selectedClass == null || selectedSection == null) return;

    setState(() => isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('teachertoken');

      final response = await http.get(
        Uri.parse(
            '${ApiRoutes.baseUrl}/teacher-student-atttendance?class=$selectedClass&section=$selectedSection&date=${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print("📢 API Response: $responseData"); // ✅ Log response for debugging

        setState(() {
          students = List<Map<String, dynamic>>.from(responseData['data']['students']);

          // Ensure attendanceStatus is correctly mapped
          attendanceStatus.clear();
          studentIds.clear();
          attendances.clear();

          for (var student in students) {
            String studentId = student['student_id'].toString();
            int status = student['attendance_status'] ?? 0;

            attendanceStatus[studentId] = status;
            studentIds.add(studentId);
            attendances.add(status);
          }

          isLoading = false;
        });

        print("✅ Attendance Status Updated: $attendanceStatus");
      } else {
        throw Exception('Failed to load attendance data');
      }
    } catch (e) {
      print('❌ Error fetching attendance: $e');
      setState(() => isLoading = false);
    }
  }


  Future<void> submitAttendance() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('teachertoken'); // Fetch stored token

      final String url = "${ApiRoutes.baseUrl}/mark-attendance";

      // Create MultipartRequest
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add Headers
      request.headers.addAll({
        "Authorization": "Bearer $token",
        "Content-Type": "multipart/form-data",
      });

      // Add FormData fields
      request.fields['date'] =
          DateFormat('yyyy-MM-dd').format(selectedDate); // Date
      request.fields['class_id'] = selectedClass.toString(); // Class ID
      request.fields['section_id'] = selectedSection.toString(); // Section ID

      // Add Arrays (students, attendances, notes)
      for (int i = 0; i < studentIds.length; i++) {
        request.fields['students[$i]'] = studentIds[i]; // Student ID array
        request.fields['attendances[$i]'] =
            attendances[i].toString(); // Attendance status array
      }

      // If you have notes, add them
      for (int i = 0; i < notes.length; i++) {
        request.fields['notes[$i]'] = notes[i]; // Notes array
      }

      // Send Request
      var response = await request.send();

      if (response.statusCode == 200) {
        print("✅ Attendance submitted successfully.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Attendance Submitted Successfully!")),
        );
        fetchAttendance();
      } else {
        print("❌ Failed to submit: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to Submit Attendance")),
        );
      }
    } catch (e) {
      print("❌ Error submitting attendance: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting attendance")),
      );
    }
  }

  /// **Set global attendance for all students**
  void _setGlobalAttendance(int status) {
    setState(() {
      globalAttendance = status;
      studentIds.clear();
      attendances.clear();
      attendanceStatus = {
        for (var student in students) student['student_id'].toString(): status
      };

      // Update studentIds and attendances arrays
      for (var student in students) {
        studentIds.add(student['student_id'].toString());
        attendances.add(status);
      }
    });
  }

  /// **Set individual student attendance**
  void _setIndividualAttendance(String studentId, int status) {
    setState(() {
      attendanceStatus[studentId] = status;

      // Check if student is already in the array, update it
      int index = studentIds.indexOf(studentId);
      if (index != -1) {
        attendances[index] = status;
      } else {
        studentIds.add(studentId);
        attendances.add(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CupertinoActivityIndicator(
        radius: 20,
        color: Colors.black54,
      ))
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // **Date Picker**
            GestureDetector(
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    selectedDate = pickedDate;
                    fetchAttendance();
                  });
                }
              },
              child: Container(
                padding:
                EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd-MM-yyyy').format(selectedDate)),
                    Icon(Icons.calendar_today, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                // Class Dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedClass,
                    decoration: InputDecoration(
                      labelText: "Select Class",
                      border: OutlineInputBorder(),
                    ),
                    items: classes.map((c) {
                      return DropdownMenuItem<int>(
                        value: c["id"],
                        child: Text(c["title"]),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedClass = value;
                        selectedSection = null;
                        globalAttendance = null; // Clear global selection
                        attendanceStatus.clear();
                        studentIds.clear();
                        attendances.clear();
                      });
                      fetchClassesAndSections();
                    },
                  ),
                ),

                SizedBox(width: 16), // Space between dropdowns

                // Section Dropdown (Only shows if a class is selected)
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedSection,
                    decoration: InputDecoration(
                      labelText: "Select Section",
                      border: OutlineInputBorder(),
                    ),
                    items: sections
                        .where((s) => s["class_id"] == selectedClass)
                        .map((s) {
                      return DropdownMenuItem<int>(
                        value: s["section_id"],
                        child: Text(s["section_title"].toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSection = value;
                        globalAttendance = null; // Clear global selection
                        attendanceStatus.clear();
                        studentIds.clear();
                        attendances.clear();
                      });
                      fetchAttendance();
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // **Global Attendance Selection**
            Card(
              elevation: 5,
              color: Colors.blue.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero, // No rounded corners
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _globalRadioButton(1, "P", Colors.green),
                  _globalRadioButton(2, "A", Colors.red),
                  _globalRadioButton(3, "L", Colors.blue),
                  _globalRadioButton(4, "H", Colors.orange),
                ],
              ),
            ),
            SizedBox(height: 16),

            // **Attendance List**
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Builder(
                    builder: (context) {

                      // ✅ Roll No wise sorting
                      final List<Map<String, dynamic>> sortedStudents =
                      List<Map<String, dynamic>>.from(students);

                      int rollToInt(dynamic v) {
                        if (v == null) return 999999;
                        return int.tryParse(v.toString()) ?? 999999;
                      }

                      sortedStudents.sort(
                            (a, b) => rollToInt(a['roll_no'])
                            .compareTo(rollToInt(b['roll_no'])),
                      );

                      return Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 5,
                                spreadRadius: 2),
                          ],
                        ),
                        child: DataTable(
                          columnSpacing: 25.0,
                          headingRowHeight: 50.0,
                          dataRowHeight: 55.0,
                          headingRowColor: MaterialStateColor.resolveWith(
                                  (states) => Colors.blue.shade100),
                          border: TableBorder.all(color: Colors.grey.shade300),

                          // ✅ UPDATED COLUMNS
                          columns: const [
                            // DataColumn(
                            //   label: Text('Student ID',
                            //       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            // ),
                            DataColumn(
                              label: Text('Roll No',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            DataColumn(
                              label: Text('Admission No',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            DataColumn(
                              label: Text('Name',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            DataColumn(
                              label: Text('Father Name',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            DataColumn(
                              label: Text('Mother Name',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            DataColumn(
                              label: Text('Attendance',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],

                          // ✅ UPDATED ROWS
                          rows: sortedStudents.asMap().entries.map((entry) {
                            int index = entry.key;
                            var student = entry.value;

                            final admissionNo = (student['adm_no'] ??
                                student['admissionNumber'] ??
                                student['admission'] ??
                                "-")
                                .toString();

                            final fatherName = (student['father_name'] ??
                                student['fatherName'] ??
                                student['fathers'] ??
                                "-")
                                .toString();

                            final motherName = (student['mother_name'] ??
                                student['motherName'] ??
                                student['mother'] ??
                                "-")
                                .toString();

                            return DataRow(
                              color: MaterialStateColor.resolveWith((states) =>
                              index.isEven ? Colors.white : Colors.grey.shade100),
                              cells: [
                                // DataCell(
                                //   Text(
                                //     student['student_id'].toString(),
                                //     style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                //   ),
                                // ),
                                DataCell(
                                  Text(
                                    student['roll_no'].toString(),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ),

                                // ✅ Admission No
                                DataCell(
                                  Text(
                                    admissionNo,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ),

                                DataCell(
                                  Text(
                                    student['student_name'].toString(),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ),

                                // ✅ Father Name
                                DataCell(
                                  Text(
                                    fatherName,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),

                                // ✅ Mother Name
                                DataCell(
                                  Text(
                                    motherName,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),

                                DataCell(
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _attendanceRadioButton(
                                          student['student_id'].toString(),
                                          1,
                                          "P",
                                          Colors.green),
                                      _attendanceRadioButton(
                                          student['student_id'].toString(),
                                          2,
                                          "A",
                                          Colors.red),
                                      _attendanceRadioButton(
                                          student['student_id'].toString(),
                                          3,
                                          "L",
                                          Colors.blue),
                                      _attendanceRadioButton(
                                          student['student_id'].toString(),
                                          4,
                                          "H",
                                          Colors.orange),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            )
            // **Submit Button**

          ],
        ),
      ),
      floatingActionButton:   Align(
        alignment: Alignment.bottomCenter,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors2.primary, // Set your desired color
          ),

          onPressed: () {
            print("Students: $studentIds");
            print("Attendances: $attendances");
            submitAttendance();
          },
          child: Text("Submit Attendance".toUpperCase(),style: TextStyle(
              color: AppColors2.textblack
          ),),

        ),
      ),

    );
  }

  Widget _globalRadioButton(int value, String label, Color color) {
    return Row(
      children: [
        Radio<int>(
          value: value,
          groupValue: globalAttendance,
          activeColor: color,
          onChanged: (newValue) {
            _setGlobalAttendance(newValue!);
          },
        ),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _attendanceRadioButton(
      String studentId, int value, String label, Color color) {
    return Row(
      children: [
        Radio<int>(
          value: value,
          groupValue: attendanceStatus[studentId],
          activeColor: color,
          onChanged: (newValue) {
            _setIndividualAttendance(studentId, newValue!);
          },
        ),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}