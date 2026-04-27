import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../HexColorCode/HexColor.dart';
import 'DateRangeReport/date_range_report.dart';
import 'DateWiseReport/date_wise_report.dart';
import 'mark_attendance.dart';

class ReportAttendanceScreen extends StatefulWidget {
  const ReportAttendanceScreen({super.key});

  @override
  State<ReportAttendanceScreen> createState() => _AttendanceTabScreenState();
}

class _AttendanceTabScreenState extends State<ReportAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
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
                      DateRangeAttendanceScreen(), // First Tab (Offline)
                      DateWiseAttendanceScreen(),
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
      padding: EdgeInsets.symmetric(horizontal: 3.w),
      child: Container(
        height:35.sp, // ✅ FIXED HEIGHT
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
              colors: [AppColors.primary, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: HexColor('#010071'),

          // 👇 IMPORTANT (text compress)
          labelPadding: EdgeInsets.zero,

          labelStyle: GoogleFonts.poppins(
            fontSize: 9.sp, // 🔥 thoda chhota karo warna overflow aayega
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 9.sp,
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
