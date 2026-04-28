import 'dart:convert';

import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../HexColorCode/HexColor.dart';
import 'DateRangeReport/date_range_report.dart';
import 'DateWiseReport/date_wise_report.dart';

class ReportAttendanceScreen extends StatefulWidget {
  const ReportAttendanceScreen({super.key});

  @override
  State<ReportAttendanceScreen> createState() => _ReportAttendanceScreenState();
}

class _ReportAttendanceScreenState extends State<ReportAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List classes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    fetchClassesAndSections();
  }
  Future<void> fetchClassesAndSections() async {

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('teachertoken');

      final response = await http.get(
        Uri.parse(
            '${ApiRoutes.baseUrl}/teacher-student-atttendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        setState(() {
          classes = List<Map<String, dynamic>>.from(responseData['data']['classes']);
          // sections =
          // List<Map<String, dynamic>>.from(responseData['data']['sections']);
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          color: Colors.red,
          child: Column(
            children: [
              SizedBox(height: 2.h),
              _tabBar(),
              SizedBox(height: 2.h),

              Expanded(
                child: isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
                    : errorMessage != null
                    ? _errorView()
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    DateRangeAttendanceScreen(
                      classes: classes,
                    ),
                    DateWiseAttendanceScreen(
                      classes: classes,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 42.sp,
            ),
            SizedBox(height: 10.h),
            Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 14.h),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                fetchClassesAndSections();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3.w),
      child: Container(
        height: 45.sp,
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: HexColor('#010071')),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary,
              ],
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: HexColor('#010071'),
          labelPadding: EdgeInsets.zero,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: "Date Range Attendance"),
            Tab(text: "Date Wise Attendance"),
          ],
        ),
      ),
    );
  }
}