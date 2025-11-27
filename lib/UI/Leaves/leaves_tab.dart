import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'apply_leave.dart';
import 'leave_approve_list.dart';

class LeavesTabScreen extends StatefulWidget {
  LeavesTabScreen({super.key});

  @override
  _LeavesTabScreenState createState() => _LeavesTabScreenState();
}

class _LeavesTabScreenState extends State<LeavesTabScreen>
    with SingleTickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          "Leaves",
          style: GoogleFonts.montserrat(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.h),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(5.sp),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black,
                labelStyle: GoogleFonts.montserrat(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.h),
                      child: Text("Apply Leave"),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.h),
                      child: Text("Approve Leave"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 5.h),
        child: TabBarView(
          controller: _tabController,
          children: [
            ApplyLeaves(),
            ApproveLeaveList(),
          ],
        ),
      ),
    );
  }
}
