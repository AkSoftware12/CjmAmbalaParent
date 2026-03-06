import 'package:avi/TecaherUi/UI/AdminTimeTable/TeacherTImeTable/teacher_time_table.dart';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../HexColorCode/HexColor.dart';
import 'StudentTImeTable/student_time_table.dart';


class AdminTimeTableTabScreen extends StatefulWidget {
  const AdminTimeTableTabScreen({super.key});

  @override
  State<AdminTimeTableTabScreen> createState() => _AttendanceTabScreenState();
}

class _AttendanceTabScreenState extends State<AdminTimeTableTabScreen> with SingleTickerProviderStateMixin {
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
        appBar: AppBar(
            iconTheme: const IconThemeData(color: AppColors.textwhite),
            backgroundColor: AppColors.secondary,
            // backgroundColor: HexColor('#c0d4f2'),
            title: Text(
              'Time Table',
              style: GoogleFonts.poppins(
                textStyle: Theme.of(context).textTheme.displayLarge,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.normal,
                color: AppColors.textwhite,
              ),
            )),

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
                SizedBox(height: 8.h),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      TeacherTimeTableScreen(),
                      StudentTimeTable(),
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
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          // color: HexColor('#010071'),
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: HexColor('#010071'),),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: LinearGradient(
              colors: [ AppColors.primary,AppColors.primary,],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor:Colors.black54,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: "Teachers Time Table"),
            Tab(text: "Student Time Table"),
          ],
        ),
      ),
    );
  }
}
