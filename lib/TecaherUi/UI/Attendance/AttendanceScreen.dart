import 'package:flutter/material.dart';
import 'attendance_report.dart';
import 'mark_attendance.dart';

class AttendanceTabScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(00),
                ),
              ),
              bottom: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.black,
                labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: "Mark Attendance".toUpperCase()),
                  Tab(text: "Report Attendance".toUpperCase()),
                ],
              ),
            ),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.only(bottom: 5), // Bottom padding
          child: TabBarView(
            children: [
              AttendanceScreen(),
              MonthlyAttendanceScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
