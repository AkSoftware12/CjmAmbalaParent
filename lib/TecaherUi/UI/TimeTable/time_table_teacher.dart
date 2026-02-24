import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../CommonCalling/data_not_found.dart';
import '../../../HexColorCode/HexColor.dart';
import '../../../constants.dart';
import '../../../utils/textSize.dart';

class TimeTableTeacherScreen extends StatefulWidget {
  const TimeTableTeacherScreen({super.key});

  @override
  State<TimeTableTeacherScreen> createState() => _TimeTableTeacherScreenState();
}

class _TimeTableTeacherScreenState extends State<TimeTableTeacherScreen> {
  bool isLoading = false;
  List<dynamic> timeTable = [];

  /// ✅ 1..5 only (Mon..Fri)
  int selectedIndex = 1;

  /// (Optional) dot position future use; safe + bounded
  double dotPosition = 0.0;

  Timer? _minuteTimer;

  /// ✅ Mon–Fri only
  final List<String> days = const ["Mon", "Tue", "Wed", "Thu", "Fri"];
  final List<String> images = const [
    "assets/mon_icon.png",
    "assets/tue_icon.png",
    "assets/wed_icon.png",
    "assets/thus_icon.png",
    "assets/fri_icon.png",
  ];

  @override
  void initState() {
    super.initState();

    // ✅ Dot updater (safe dispose)
    updateDotPosition();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      updateDotPosition();
    });

    // ✅ Today highlight (Mon–Fri). Sat/Sun => Fri
    final now = DateTime.now();
    int wd = now.weekday; // Mon=1..Sun=7
    if (wd > 5) wd = 5; // Sat/Sun => Fri
    selectedIndex = wd;

    // ✅ Fetch initial
    fetchAssignmentsData(selectedIndex);
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchAssignmentsData(int dayIndex) async {
    // ✅ Guard: only 1..5
    if (dayIndex < 1) dayIndex = 1;
    if (dayIndex > 5) dayIndex = 5;

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      if (token == null || token.isEmpty) {
        // ✅ Token missing
        if (!mounted) return;
        setState(() {
          isLoading = false;
          timeTable = [];
        });
        return;
      }

      final uri = Uri.parse('${ApiRoutes.getTeacherTimeTable}$dayIndex');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
        json.decode(response.body) as Map<String, dynamic>;

        final data = jsonResponse['data'];
        setState(() {
          timeTable = (data is List) ? data : <dynamic>[];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          timeTable = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        timeTable = [];
      });
    }
  }

  void updateDotPosition() {
    final now = DateTime.now();
    const double totalMinutes = 24 * 60;
    final int currentMinutes = now.hour * 60 + now.minute;

    // ✅ Keep bounded
    const double maxHeight = 300.0;
    final double newPosition = (currentMinutes / totalMinutes) * maxHeight;

    if (!mounted) return;
    setState(() {
      dotPosition = newPosition.clamp(0.0, maxHeight);
    });
  }

  String _getMonthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }


  @override
  Widget build(BuildContext context) {
    return    Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
          iconTheme: const IconThemeData(color: AppColors.textwhite),
          backgroundColor: AppColors.secondary,
          // backgroundColor: HexColor('#c0d4f2'),
          title: Text(
            'Time Table',
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.normal,
              color: AppColors.textwhite,
            ),
          )),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height:  MediaQuery.of(context).size.height* 0.99,
              decoration: BoxDecoration(
                color: HexColor('#dfe6f1'),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30.sp),topRight: Radius.circular(30.sp)),
              ),
              child:Column(
                children: [
                  _buildRow("Selected Day", '', Icons.calendar_today, Colors.blueGrey),
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.sp),
                    child: SizedBox(
                      height: 65.sp, // Adjust height for better appearance
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: days.length,
                        itemBuilder: (context, index) {
                          bool isSelected = selectedIndex == index + 1; // Ensure 1-based index

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedIndex = index + 1; // Store values as 1 to 7 instead of 0 to 6
                              });
                              fetchAssignmentsData(selectedIndex);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 15.sp, vertical: 15.sp),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Text(
                                    days[index],
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : HexColor('#515992'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child:  Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30.sp),
                          topRight: Radius.circular(30.sp),
                        ),
                      ),
                      child:  isLoading
                          ? Center(
                          child: Container(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: CupertinoActivityIndicator(radius: 25,color: AppColors.primary,)))
                          : timeTable.isEmpty
                          ? Center(child: DataNotFoundWidget(title: 'Time Table Not Available.'))
                          : Stack(
                        children: [
                          Positioned(
                            left: 70,
                            top: 10,
                            bottom: 0,
                            child: Container(
                              width: 1,
                              color: Colors.blue[100],
                            ),
                          ),
                          Positioned.fill(
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              itemCount: timeTable.length,
                              itemBuilder: (context, index) {
                                final schedule =
                                    (timeTable[index] as Map?)?.cast<String, dynamic>() ??
                                        <String, dynamic>{};

                                final subject =
                                (schedule['subject_name'] ?? '').toString();
                                final cls = (schedule['class'] ?? '').toString();
                                final section =
                                (schedule['section'] ?? '').toString();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [

                                      // Time Indicator
                                      Column(
                                        children: [
                                          Container(
                                            height: 35.sp,
                                            width: 40.sp,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue,
                                                  Colors.blueAccent,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blue.withOpacity(0.4),
                                                  blurRadius: 8,
                                                  offset: Offset(0, 4),
                                                )
                                              ],
                                            ),
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),



                                        ],
                                      ),
                                      SizedBox(width: 15),
                                      // Subject Card
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: (){
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              // color: Colors.orange.shade50,
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            margin: const EdgeInsets.symmetric(vertical: 0.0),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                              child: ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                leading: Container(
                                                  padding: EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blueAccent.withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.book,
                                                    size: 30,
                                                    color: Colors.blueAccent,
                                                  ),
                                                ),
                                                title: Text(
                                                  subject,
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [

                                                    SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        // SizedBox(
                                                        //   height: 18,
                                                        //   width: 18,
                                                        //   child: Image.asset('assets/teacher.png', color: Colors.black),
                                                        // ),
                                                        // SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            "$cls ($section)",
                                                            style: GoogleFonts.montserrat(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.grey.shade800,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 5),

                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        ],
                      ),

                    ),)
                ],
              ),




            ),






          ],
        ),
      ),

    );





  }
  Widget _buildRow(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(top: 10.sp, bottom: 10.sp),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: TextSizes.textmedium,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}