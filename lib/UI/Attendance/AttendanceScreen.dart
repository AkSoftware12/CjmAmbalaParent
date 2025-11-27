// import 'dart:convert';
// import 'package:avi/constants.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:syncfusion_flutter_datepicker/datepicker.dart';
//
// import '../../CommonCalling/progressbarWhite.dart';
//
// class AttendanceScreen extends StatefulWidget {
//   @override
//   _AttendanceTableScreenState createState() => _AttendanceTableScreenState();
// }
//
// class _AttendanceTableScreenState extends State<AttendanceScreen> {
//   late Future<Map<String, dynamic>> _attendanceFuture;
//   List<String> dates = [];
//   int selectedYear = DateTime.now().year;
//   int selectedMonth = DateTime.now().month;
//   DateTime? startDate;
//   DateTime? endDate;
//   @override
//   void initState() {
//     super.initState();
//     _attendanceFuture = fetchAttendance(selectedMonth.toString(),selectedYear.toString(),"","");
//   }
//
//   Future<Map<String, dynamic>> fetchAttendance(String month, String year, String startDate, String endDate) async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? token = prefs.getString('token');
//
//       final response = await http.get(
//         Uri.parse('${ApiRoutes.attendance}?month=$month&year=$year&start_date=$startDate&end_date=$endDate'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final decodedResponse = json.decode(response.body);
//
//
//         // If the response is a List, convert it to a Map
//         if (decodedResponse is List) {
//           return {
//             "data": {
//               "attendance": decodedResponse // Convert list to map key
//             }
//         };
//
//         } else if (decodedResponse is Map<String, dynamic>) {
//           print(decodedResponse.toString());
//
//           return decodedResponse;
//
//         } else {
//           throw Exception("Unexpected response format");
//         }
//       } else {
//         throw Exception('Failed to load data');
//       }
//     } catch (e) {
//       print('Error fetching attendance: $e');
//       throw Exception('Error fetching attendance');
//     }
//   }
//
//   Widget _buildAppBar(String title) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Align(
//           alignment: Alignment.bottomRight,
//           child: Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Text(
//               title,
//               style: GoogleFonts.montserrat(
//                 textStyle: Theme.of(context).textTheme.displayLarge,
//                 fontSize: 21,
//                 fontWeight: FontWeight.w800,
//                 fontStyle: FontStyle.normal,
//                 color: AppColors.textwhite,
//               ),
//             ),
//           ),
//         ),
//         Align(
//           alignment: Alignment.bottomLeft,
//           child: Padding(
//             padding: const EdgeInsets.all(0.0),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Year Dropdown
//
//                 // Month Dropdown
//                 Container(
//                   height: 30,
//                   decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(10),
//                       color: Colors.white),
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 8.0, right: 8),
//                     child: DropdownButton<int>(
//                       value: selectedMonth,
//                       onChanged: (int? newMonth) {
//                         setState(() {
//                           startDate=null;
//                           endDate=null;
//                           selectedMonth = newMonth!;
//                           _attendanceFuture = fetchAttendance(selectedMonth.toString(), selectedYear.toString(),'','');
//                         });
//                       },
//                       items: List.generate(12, (index) {
//                         int month = index + 1; // Months from 1 to 12
//                         // Abbreviated month names (Jan, Feb, etc.)
//                         List<String> monthNames = [
//                           'Jan',
//                           'Feb',
//                           'Mar',
//                           'Apr',
//                           'May',
//                           'Jun',
//                           'Jul',
//                           'Aug',
//                           'Sep',
//                           'Oct',
//                           'Nov',
//                           'Dec'
//                         ];
//                         return DropdownMenuItem<int>(
//                           value: month,
//                           child: Text(monthNames[month -
//                               1]), // Display the abbreviated month name
//                         );
//                       }),
//                       underline:
//                       SizedBox.shrink(), // Removes the bottom outline
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 // To add space between year and month dropdown
//
//                 Container(
//                   height: 30,
//                   decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(10),
//                       color: Colors.white),
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 8.0, right: 8),
//                     child: DropdownButton<int>(
//                       value: selectedYear,
//                       onChanged: (int? newYear) {
//                         setState(() {
//                           startDate=null;
//                           endDate=null;
//
//                           selectedYear = newYear!;
//                           _attendanceFuture = fetchAttendance(selectedMonth.toString(), selectedYear.toString(),'','');
//                         });
//                       },
//                       items: List.generate(10, (index) {
//                         int year = DateTime.now().year -
//                             5 +
//                             index; // Show 10 years range
//                         return DropdownMenuItem<int>(
//                           value: year,
//                           child: Text(year.toString()),
//                         );
//                       }),
//                       underline:
//                       SizedBox.shrink(), // Removes the bottom outline
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         )
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.secondary,
//       appBar: AppBar(
//         backgroundColor: AppColors.secondary,
//         automaticallyImplyLeading: true,
//         iconTheme: IconThemeData(color: Colors.white),
//         title:  _buildAppBar('Attendance'),
//
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//
//       //   Container(
//       //   padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       //   decoration: BoxDecoration(
//       //     color: Colors.white,
//       //     borderRadius: BorderRadius.circular(12),
//       //     boxShadow: [
//       //       BoxShadow(
//       //         color:Colors.blue.withOpacity(0.2),
//       //         blurRadius: 8,
//       //         spreadRadius: 2,
//       //         offset: const Offset(0, 1),
//       //       ),
//       //     ],
//       //   ),
//       //   child: Column(
//       //     // mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       //     children: [
//       //       DateRangeSelector(
//       //         startDate: startDate,
//       //         endDate: endDate,
//       //         onSelectDateRange: _selectDateRange,
//       //       ),
//       //
//       //     ],
//       //   ),
//       // ),
//             // Date Selection Row
//             // DateRangeSelector(
//             //   startDate: startDate,
//             //   endDate: endDate,
//             //   onSelectDateRange: _selectDateRange,
//             // ),
//             SizedBox(height: 10,),
//             // _buildAppBar('Attendance $selectedYear $selectedMonth'),
//             FutureBuilder<Map<String, dynamic>>(
//               future: _attendanceFuture,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Container(
//                     height: MediaQuery.of(context).size.height * 0.4,
//                       child: Center(child: WhiteCircularProgressWidget()));
//                 } else if (snapshot.hasError) {
//                   return Center(child: Text('Error: ${snapshot.error}'));
//                 } else if (!snapshot.hasData || snapshot.data == null || snapshot.data!['data'] == null || snapshot.data!['data']['attendance']==null) {
//                   return Container(
//                     height: MediaQuery.of(context).size.height * 0.4,
//                     child: Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Image.asset('assets/no_attendance.png', filterQuality: FilterQuality.high,height: 150.sp,width: 200.sp,),
//                           SizedBox(height: 10),
//                           Text(
//                             'Attendance Not Available.',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12.sp,
//                               fontWeight: FontWeight.w800,
//                               color: AppColors.textwhite,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 } else {
//                   final data = snapshot.data!;
//                   final processedData = processAttendanceData(data['data']['attendance']);
//                   return _buildDataTable(processedData);
//                 }
//               },
//             ),
//
//           ],
//         ),
//       ),
//     );
//   }
//   List<Map<String, dynamic>> processAttendanceData(Map<String, dynamic> attendanceData) {
//     List<String> formattedDates;
//     if (startDate != null && endDate != null) {
//       // Generate dates only within the selected range
//       final days = generateDateRange(startDate!, endDate!);
//       formattedDates = days.map((date) => DateFormat('yyyy-MM-dd').format(date)).toList();
//     } else {
//       // Fallback: all dates in the selected month
//       int daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
//       formattedDates = List.generate(daysInMonth, (index) {
//         DateTime date = DateTime(selectedYear, selectedMonth, index + 1);
//         return DateFormat('yyyy-MM-dd').format(date);
//       });
//     }
//
//     // Filter attendance data for the generated dates
//     Map<String, String> dailyAttendanceMap = {};
//     attendanceData.forEach((date, entry) {
//       if (formattedDates.contains(date)) {
//         int status = entry['status'];
//         dailyAttendanceMap[date] = getStatusSymbol(status);
//       }
//     });
//
//     // Optionally sort the dates
//     formattedDates.sort();
//     dates = formattedDates;
//
//     return [
//       {
//         'subject': 'Attendance',
//         'dailyRecords': dailyAttendanceMap,
//       }
//     ];
//   }
//
//   // List<Map<String, dynamic>> processAttendanceData(Map<String, dynamic> attendanceData) {
//   //   int daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day; // Get total days in month
//   //   Set<String> uniqueDates = Set.from(
//   //     List.generate(daysInMonth, (index) {
//   //       DateTime date = DateTime(selectedYear, selectedMonth, index + 1);
//   //       return DateFormat('yyyy-MM-dd').format(date); // Format as "YYYY-MM-DD"
//   //     }),
//   //   );
//   //
//   //   Map<String, String> dailyAttendanceMap = {}; // Store daily attendance
//   //
//   //   // Extract attendance records correctly
//   //   attendanceData.forEach((date, entry) {
//   //     if (date.startsWith('$selectedYear-${selectedMonth.toString().padLeft(2, '0')}')) {
//   //       int status = entry['status']; // Extract status
//   //       dailyAttendanceMap[date] = getStatusSymbol(status); // Convert status to symbol
//   //     }
//   //   });
//   //
//   //   dates = uniqueDates.toList()..sort(); // Sort formatted dates
//   //
//   //   return [
//   //     {
//   //       'subject': 'Attendance',
//   //       'dailyRecords': dailyAttendanceMap,
//   //     }
//   //   ];
//   // }
//
//   List<DateTime> generateDateRange(DateTime start, DateTime end) {
//     List<DateTime> range = [];
//     for (DateTime date = start;
//     date.isBefore(end.add(Duration(days: 1)));
//     date = date.add(Duration(days: 1))) {
//       range.add(date);
//     }
//     return range;
//   }
//
//
//   Widget _buildDataTable(List<Map<String, dynamic>> attendanceData) {
//     int totalPresent = 0;
//     int totalAbsent = 0;
//     int totalLeave = 0;
//     int totalHoliday = 0;
//     int totalDays = 0;
//
//     // **Loop through attendance records and count the totals**
//     for (var date in dates) {
//       String status = attendanceData[0]['dailyRecords'][date] ?? '-';
//       switch (status) {
//         case 'P': totalPresent++; break;
//         case 'A': totalAbsent++; break;
//         case 'L': totalLeave++; break;
//         case 'H': totalHoliday++; break;
//       }
//       if (status != 'H') totalDays++; // Count only working days
//     }
//
//     // **Calculate Percentage**
//     double attendancePercentage = totalDays == 0 ? 0 : (totalPresent / totalDays) * 100;
//
//     return Center(
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: DataTable(
//           columnSpacing: 20,
//           headingRowColor: MaterialStateColor.resolveWith((states) => Colors.blue.shade100),
//           border: TableBorder.all(color: Colors.grey.shade300),
//           columns: [
//             DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text("Attendance", style: TextStyle(fontWeight: FontWeight.bold))),
//           ],
//           rows: [
//             // **Attendance Records**
//             ...dates.map((date) {
//               String status = attendanceData[0]['dailyRecords'][date] ?? '-';
//               return DataRow(
//                 cells: [
//                   DataCell(Text(date, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,color: Colors.white))),
//                   DataCell(
//                     Center(
//                       child: Text(
//                         status,
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                           color: _getStatusColor(status),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             }).toList(),
//
//             // **Summary Rows**
//             _buildSummaryRow("Total Present", totalPresent.toString(), Colors.green),
//             _buildSummaryRow("Total Absent", totalAbsent.toString(), Colors.red),
//             _buildSummaryRow("Total Leave", totalLeave.toString(), Colors.blue),
//             _buildSummaryRow("Total Holiday", totalHoliday.toString(), Colors.orange),
//             _buildSummaryRow("Total Attendance %", "${attendancePercentage.toStringAsFixed(2)}%", Colors.white),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// **Builds the summary row with text and color**
//   DataRow _buildSummaryRow(String title, String value, Color color) {
//     return DataRow(
//       cells: [
//         DataCell(Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,color: Colors.white))),
//         DataCell(
//           Center(
//             child: Text(
//               value,
//               style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   /// **Convert status symbol to color**
//   Color _getStatusColor(String status) {
//     switch (status) {
//       case 'P': return Colors.green;
//       case 'A': return Colors.red;
//       case 'L': return Colors.blue;
//       case 'H': return Colors.orange;
//       default: return Colors.black;
//     }
//   }
//
//   /// **Convert status integer to symbol**
//   String getStatusSymbol(int status) {
//     switch (status) {
//       case 1: return 'P'; // Present
//       case 2: return 'A'; // Absent
//       case 3: return 'L'; // Leave
//       case 4: return 'H'; // Holiday
//       default: return '-';
//     }
//   }
//
//   Future<void> _selectDateRange(BuildContext context) async {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.white,
//       shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
//       builder: (context) {
//         return Padding(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text("Select Date Range",
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               SizedBox(height: 10),
//               SizedBox(
//                 height: 300,
//                 child: SfDateRangePicker(
//                   selectionMode: DateRangePickerSelectionMode.range,
//                   onSelectionChanged:
//                       (DateRangePickerSelectionChangedArgs args) {
//                     if (args.value is PickerDateRange) {
//                       setState(() {
//                         startDate = args.value.startDate;
//                         endDate = args.value.endDate;
//                         print('Start date :- $startDate' );
//                         print('End  date :- $endDate' );
//                       });
//                     }
//                   },
//                 ),
//               ),
//               SizedBox(height: 10),
//               ElevatedButton.icon(
//                 onPressed: () {
//                   if (startDate == null || endDate == null) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text("Please select a valid date range")),
//                     );
//                     return;
//                   }
//                   // Update the future with the new date range
//                   setState(() {
//                     _attendanceFuture = fetchAttendance('', '',
//                         DateFormat('yyyy-MM-dd').format(startDate!),
//                         DateFormat('yyyy-MM-dd').format(endDate!));
//                   });
//                   Navigator.pop(context);
//                 },
//                 icon: Icon(Icons.check),
//                 label: Text("Apply Date Range"),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blueAccent,
//                   foregroundColor: Colors.white,
//                   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                 ),
//               ),
//
//               // ElevatedButton.icon(
//               //   onPressed: () {
//               //     if (startDate == null || endDate == null) {
//               //       ScaffoldMessenger.of(context).showSnackBar(
//               //         SnackBar(
//               //             content: Text("Please select a valid date range")),
//               //       );
//               //       return;
//               //     }
//               //     fetchAttendance('', '',DateFormat('yyyy-MM-dd').format(startDate!).toString(),DateFormat('yyyy-MM-dd').format(endDate!).toString());
//               //
//               //     Navigator.pop(context);
//               //
//               //     // _attendanceFuture = fetchAttendance2();
//               //
//               //   },
//               //   icon: Icon(Icons.check),
//               //   label: Text("Apply Date Range"),
//               //   style: ElevatedButton.styleFrom(
//               //     backgroundColor: Colors.blueAccent,
//               //     foregroundColor: Colors.white,
//               //     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//               //   ),
//               // ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//
// }
//
//
//
// class DateRangeSelector extends StatelessWidget {
//   final DateTime? startDate;
//   final DateTime? endDate;
//   final Function(BuildContext) onSelectDateRange;
//
//   const DateRangeSelector({
//     Key? key,
//     required this.startDate,
//     required this.endDate,
//     required this.onSelectDateRange,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color:Colors.blue.withOpacity(0.2),
//             blurRadius: 8,
//             spreadRadius: 2,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Row(
//         // mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             children: [
//
//               OutlinedButton.icon(
//                 onPressed: () => onSelectDateRange(context),
//                 icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
//                 label: const Text(
//                   "Select Date Range",
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                 ),
//                 style: OutlinedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   side: const BorderSide(color: Colors.blueAccent),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(width: 16), // Spacing between button and container
//           Expanded(
//             child: Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildDateRow("From:", startDate),
//                   const Divider(height: 10, color: Colors.blueAccent),
//                   _buildDateRow("To:", endDate),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDateRow(String label, DateTime? date) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: Colors.blueGrey,
//           ),
//         ),
//         Text(
//           date != null ? DateFormat('dd-MM-yyyy').format(date) : "Select Date",
//           style: const TextStyle(
//             fontSize: 16,
//             color: Colors.black87,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }
//
// }
//
//



import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../../HexColorCode/HexColor.dart';
import '../../constants.dart';
import '../Auth/login_screen.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String title;
  const AttendanceCalendarScreen({super.key, required this.title});

  @override
  _AttendanceCalendarScreenState createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  late CalendarFormat _calendarFormat;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _attendanceRecords = {};
  Set<DateTime> _highlightedDays = {};
  List<Map<String, dynamic>> _monthlyAttendance = [];
  bool isLoading = false;
  int totalPresent = 0;
  int totalAbsent = 0;
  int totalLeave = 0;
  int totalHoliday = 0;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');


    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.attendance}?month=${_focusedDay.month}&year=${_focusedDay.year}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        Map<String, dynamic> attendanceData = decodedResponse is List
            ? {"data": {"attendance": decodedResponse}}
            : decodedResponse;

        Map<DateTime, List<Map<String, dynamic>>> tempAttendance = {};
        Set<DateTime> tempHighlightedDays = {};
        Set<String> uniqueDates = {};
        List<Map<String, dynamic>> tempMonthlyAttendance = [];
        int tempPresent = 0;
        int tempAbsent = 0;
        int tempLeave = 0;
        int tempHoliday = 0;

        // Process attendance data
        attendanceData['data']['attendance'].forEach((date, entry) {
          DateTime parsedDate = DateTime.parse(date).toLocal();
          DateTime normalizedDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

          tempHighlightedDays.add(normalizedDate);

          if (tempAttendance[normalizedDate] == null) {
            tempAttendance[normalizedDate] = [];
          }

          String status = getStatusSymbol(entry['status']);
          tempAttendance[normalizedDate]!.add({
            'date': date,
            'status': status,
            'status_code': entry['status'],
          });

          if (parsedDate.month == _focusedDay.month && parsedDate.year == _focusedDay.year) {
            if (!uniqueDates.contains(date)) {
              uniqueDates.add(date);
              tempMonthlyAttendance.add({
                'date': date,
                'status': status,
                'status_code': entry['status'],
              });

              // Count totals
              switch (status) {
                case 'P':
                  tempPresent++;
                  break;
                case 'A':
                  tempAbsent++;
                  break;
                case 'L':
                  tempLeave++;
                  break;
                case 'H':
                  tempHoliday++;
                  break;
              }
            }
          }
        });

        setState(() {
          _attendanceRecords = tempAttendance;
          _highlightedDays = tempHighlightedDays;
          _monthlyAttendance = tempMonthlyAttendance;
          totalPresent = tempPresent;
          totalAbsent = tempAbsent;
          totalLeave = tempLeave;
          totalHoliday = tempHoliday;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = true;
        });
      }
    } catch (e) {
      print('Error fetching attendance: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String getStatusSymbol(int status) {
    switch (status) {
      case 1:
        return 'P'; // Present
      case 2:
        return 'A'; // Absent
      case 3:
        return 'L'; // Leave
      case 4:
        return 'H'; // Holiday
      default:
        return '-';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'P':
        return Colors.green;
      case 'A':
        return Colors.red;
      case 'L':
        return Colors.blue;
      case 'H':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  List<Map<String, dynamic>> _getAttendanceForDay(DateTime day) {
    return _attendanceRecords[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _updateMonthlyAttendance(DateTime newMonth) {
    Set<String> uniqueDates = {};
    List<Map<String, dynamic>> tempMonthlyAttendance = [];
    int tempPresent = 0;
    int tempAbsent = 0;
    int tempLeave = 0;
    int tempHoliday = 0;

    _attendanceRecords.forEach((date, records) {
      if (date.month == newMonth.month && date.year == newMonth.year) {
        for (var record in records) {
          if (!uniqueDates.contains(record['date'])) {
            uniqueDates.add(record['date']);
            tempMonthlyAttendance.add(record);
            // Count totals
            switch (record['status']) {
              case 'P':
                tempPresent++;
                break;
              case 'A':
                tempAbsent++;
                break;
              case 'L':
                tempLeave++;
                break;
              case 'H':
                tempHoliday++;
                break;
            }
          }
        }
      }
    });

    setState(() {
      _monthlyAttendance = tempMonthlyAttendance;
      totalPresent = tempPresent;
      totalAbsent = tempAbsent;
      totalLeave = tempLeave;
      totalHoliday = tempHoliday;
    });
  }

  Widget _buildSummaryItem(String title, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.sp, horizontal: 10.sp),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.sp),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 12.sp,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: GoogleFonts.montserrat(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.secondary,
      ),
      body: Padding(
        padding: EdgeInsets.all(5.sp),
        child:Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: TableCalendar(
                        focusedDay: _focusedDay,
                        firstDay: DateTime(2025, 1, 1),
                        lastDay: DateTime(2025, 12, 31),
                        calendarFormat: _calendarFormat,
                        eventLoader: _getAttendanceForDay,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                          _updateMonthlyAttendance(focusedDay);
                          _fetchAttendance();
                        },
                        daysOfWeekVisible: true,
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          weekendTextStyle: TextStyle(color: Colors.redAccent),
                          todayDecoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          defaultTextStyle: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black, size: 25.sp),
                          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black, size: 25.sp),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                          weekendStyle: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 18.sp,
                          ),
                        ),
                        daysOfWeekHeight: 40,
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, date, _) {
                            bool isHighlighted = _highlightedDays.contains(
                              DateTime(date.year, date.month, date.day),
                            );
                            String status = _getAttendanceForDay(date).isNotEmpty
                                ? _getAttendanceForDay(date)[0]['status']
                                : '';
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              margin: EdgeInsets.all(6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isHighlighted ? _getStatusColor(status) : null,
                                shape: BoxShape.circle,
                                boxShadow: isHighlighted
                                    ? [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                                    : null,
                              ),
                              child: Text(
                                '${date.day}',
                                style: GoogleFonts.notoSans(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isHighlighted ? Colors.white : Colors.black87,
                                ),

                              ),
                            );
                          },
                          markerBuilder: (context, date, events) {
                            return SizedBox();
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5.sp),
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      color: HexColor('#FFE5E7'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.all(10.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "📊 Attendance Summary",
                              style: GoogleFonts.montserrat(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[800],
                              ),
                            ),
                            SizedBox(height: 16.sp),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              runSpacing: 15.sp,
                              spacing: 15.sp,
                              children: [
                                _buildSummaryItem("✅ Present", totalPresent, Colors.green),
                                _buildSummaryItem("❌ Absent", totalAbsent, Colors.red),
                                _buildSummaryItem("📝 Leave", totalLeave, Colors.blue),
                                _buildSummaryItem("🎉 Holiday", totalHoliday, Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading) ...[
              // Blur effect when isLoading is true
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), // Adjust blur intensity
                child: Container(
                  color: Colors.black.withOpacity(0.1), // Optional: slight overlay for better visibility
                ),
              ),
              // Loading indicator
              Center(
                child: CupertinoActivityIndicator(radius: 25, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }


}