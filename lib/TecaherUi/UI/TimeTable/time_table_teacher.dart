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
  State<TimeTableTeacherScreen> createState() =>
      _TimeTableTeacherScreenState();
}

class _TimeTableTeacherScreenState
    extends State<TimeTableTeacherScreen> {
  bool isLoading = false;
  List<dynamic> timeTable = [];

  /// ✅ Mon=1..Sun=7
  int selectedIndex = 1;

  double dotPosition = 0.0;

  Timer? _minuteTimer;

  /// ✅ Mon–Fri tabs
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

    updateDotPosition();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      updateDotPosition();
    });

    final now = DateTime.now();
    int wd = now.weekday; // Mon=1..Sun=7

    selectedIndex = wd;

    /// ✅ FIX: Weekend pe API call nahi hogi
    if (wd > 5) {
      timeTable = [];
    } else {
      fetchAssignmentsData(selectedIndex);
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchAssignmentsData(int dayIndex) async {
    /// ✅ Safety
    if (dayIndex < 1 || dayIndex > 5) return;

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
          timeTable = [];
        });
        return;
      }

      final uri =
      Uri.parse('${ApiRoutes.getTeacherTimeTable}$dayIndex');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        setState(() {
          timeTable = jsonResponse['data'] ?? [];
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

    const double maxHeight = 300.0;
    final double newPosition =
        (currentMinutes / totalMinutes) * maxHeight;

    if (!mounted) return;
    setState(() {
      dotPosition = newPosition.clamp(0.0, maxHeight);
    });
  }

  /// ✅ Weekend check
  bool isWeekend() => selectedIndex > 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        backgroundColor: AppColors.primary,
        centerTitle: false,
        title: Text(
          'Time Table',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 15.sp
          ),
        ),
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

                    /// ✅ FIX: weekend pe API call mat karo
                    if (selectedIndex > 5) {
                      setState(() => timeTable = []);
                    } else {
                      fetchAssignmentsData(selectedIndex);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: isSelected
                          ? [
                        const BoxShadow(
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
            child: isWeekend()
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
                : isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Colors.red,
              ),
            )
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
                  horizontal: 10, vertical: 5),
              itemBuilder: (context, index) {
                final schedule =
                    (timeTable[index] as Map?)
                        ?.cast<String, dynamic>() ??
                        {};

                final subject =
                (schedule['subject_name'] ?? '')
                    .toString();
                final teacher =
                (schedule['teacher_name'] ?? '')
                    .toString();
                final period =
                (schedule['period'] ?? '')
                    .toString();
                final cls =
                (schedule['class'] ?? '').toString();
                final section =
                (schedule['section'] ?? '')
                    .toString();

                return Container(
                  margin:
                  const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12
                            .withOpacity(0.05),
                        blurRadius: 10,
                        offset:
                        const Offset(0, 4),
                      )
                    ],
                    border: Border.all(
                      width: 1,
                      color: Colors.red.shade100,
                    ),
                  ),
                  child: Row(
                    children: [

                      /// 🔴 Period Circle
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                          Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        alignment:
                        Alignment.center,
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                          children: [
                            Text(
                              period,
                              style: TextStyle(
                                color: Colors
                                    .red.shade500,
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Container(
                              width: 10,
                              height: 2,
                              color: Colors
                                  .red.shade500,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Period',
                              style: TextStyle(
                                color: Colors
                                    .red.shade500,
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// 📘 Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              subject,
                              style: GoogleFonts
                                  .montserrat(
                                fontSize: 15,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                    Icons.class_,
                                    size: 14,
                                    color:
                                    Colors.grey),
                                const SizedBox(
                                    width: 5),
                                Expanded(
                                  child: Text(
                                    "$cls ($section)",
                                    style:
                                    GoogleFonts
                                        .montserrat(
                                      fontSize: 11,
                                      color: Colors
                                          .grey[700],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ],
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
    );
  }
}