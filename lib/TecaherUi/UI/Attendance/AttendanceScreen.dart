import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../HexColorCode/HexColor.dart';
import 'AttendanceSummary/attendance_summary.dart';
import 'attendance_report.dart';
import 'mark_attendance.dart';

class AttendanceTabScreen extends StatefulWidget {
  const AttendanceTabScreen({super.key});

  @override
  State<AttendanceTabScreen> createState() => _AttendanceTabScreenState();
}

class _AttendanceTabScreenState extends State<AttendanceTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
       body: SafeArea(
      child: Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
      ),
      child: Column(
        children: [
          // _topHeader(),
          SizedBox(height: 2.h),
          _tabBar(),
          SizedBox(height: 2.h),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AttendanceScreen(), // First Tab (Offline)
                ReportAttendanceScreen(),
                AttendanceSummaryScreen(),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Container(
        height: 50.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: HexColor('#010071'),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: TabBar(
          controller: _tabController,

          // ✅ Horizontal Scroll
          isScrollable: true,

          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            color: AppColors.primary,
          ),

          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,

          labelColor: Colors.white,
          unselectedLabelColor: HexColor('#010071'),

          // spacing between tabs
          tabAlignment: TabAlignment.start,
          labelPadding: EdgeInsets.symmetric(horizontal: 20.w),

          labelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),

          tabs: const [
            Tab(text: "Mark Attendance"),
            Tab(text: "Report Attendance"),
            Tab(text: "Attendance Summary"),
          ],
        ),
      ),
    );
  }
}
