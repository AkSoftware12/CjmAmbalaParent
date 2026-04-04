import 'dart:async';
import 'dart:convert';

import 'package:avi/HexColorCode/HexColor.dart';
import 'package:avi/constants.dart';
import 'package:day_picker/day_picker.dart';
import 'package:day_picker/model/day_in_week.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../Auth/login_screen.dart';

class TimeTableScreen extends StatefulWidget {
  const TimeTableScreen({super.key});

  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> {

  bool isLoading = false;
  List timeTable = []; // Declare a list to hold API data
  int? selectedIndex; // Track selected index
  double dotPosition = 0.0;

  // Always start week from Monday
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", ];

  @override
  void initState() {
    super.initState();

    updateDotPosition();
    Timer.periodic(Duration(minutes: 1), (timer) {
      updateDotPosition();
    });
    // Automatically highlight today’s corresponding weekday
    DateTime now = DateTime.now();
    int todayWeekday = now.weekday; // 1 (Monday) to 7 (Sunday)

    // Adjust the index to match the fixed Monday-starting week list
    selectedIndex = (todayWeekday - 0) % 7; // Shift to Monday-based index
    DateTime.now().subtract(const Duration(days: 30));
    fetchAssignmentsData(selectedIndex);

    print(timeTable);
  }


  Future<void> fetchAssignmentsData(int? index) async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    // if (token == null) {
    //   _showLoginDialog();
    //   return;
    // }

    final response = await http.get(
      Uri.parse('${ApiRoutes.getTimeTable}$index'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        timeTable = jsonResponse['data'];
        isLoading = false; // Stop progress bar
// Update state with fetched data
      });
    } else {
      // _showLoginDialog();
      setState(() {
        isLoading = false;
      });
    }
  }


  void updateDotPosition() {
    DateTime now = DateTime.now();
    double totalMinutes = 24 * 60; // Total minutes in a day
    int currentMinutes = now.hour * 60 + now.minute;

    // Timeline ki height ke hisaab se position calculate karna
    double maxHeight = 300.0; // Change this according to your timeline height
    double newPosition = (currentMinutes / totalMinutes) * maxHeight;
    setState(() {
      dotPosition = newPosition;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        backgroundColor: AppColors.primary,
        title: Text(
          'Time Table',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 15.sp
          ),
        ),
        centerTitle: false,
      ),

      body: Column(
        children: [

          /// 🔴 Day Tabs
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) {
                bool isSelected = selectedIndex == index + 1;

                return GestureDetector(
                  onTap: () {
                    setState(() => selectedIndex = index + 1);
                    fetchAssignmentsData(selectedIndex);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        )
                      ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        days[index],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          /// 🔵 Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(
              color: Colors.red,
            ))
                : timeTable.isEmpty
                ? Center(
              child: Text(
                "No Time Table Available",
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            )
                : ListView.builder(
              itemCount: timeTable.length,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 0),
              itemBuilder: (context, index) {
                final schedule = timeTable[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                    border: Border.all(width: 1,color: Colors.red.shade200)
                  ),
                  child: Row(
                    children: [

                      /// 🔴 Period Circle
                      Column(
                        children: [
                          Container(
                            width: 50.sp,
                            height: 50.sp,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              // gradient: LinearGradient(
                              //   colors: [
                              //     AppColors.primary,
                              //     Colors.redAccent,
                              //   ],
                              // ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  schedule['period'].toString(),
                                  style:  TextStyle(
                                    color: Colors.red.shade500,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20.sp,
                                  ),
                                ),
                                Container(
                                  width: 10,
                                  height: 2,
                                  color: Colors.red.shade500,
                                ),
                                SizedBox(
                                  height: 1,
                                ),

                                Text(
                                  'Period',
                                  style:  TextStyle(
                                    color: Colors.red.shade500,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 7.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ],
                      ),

                      const SizedBox(width: 12),

                      /// 📘 Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule['subject_name'],
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),

                            Row(
                              children: [
                                Icon(Icons.person,
                                    size: 14,
                                    color: Colors.grey),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    schedule['teacher_name'],
                                    style:
                                    GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),

                      // /// 👉 Arrow Icon
                      // Icon(Icons.arrow_forward_ios,
                      //     size: 14, color: Colors.grey),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

