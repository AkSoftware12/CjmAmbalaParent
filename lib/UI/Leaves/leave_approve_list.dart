

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants.dart';


class LeaveRequest {
  String fromDate;
  String toDate;
  String status;
  String reason;
  bool isApproved;

  LeaveRequest({
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.reason,
    required this.isApproved,
  });
}

class ApproveLeaveList extends StatefulWidget {
  @override
  _LeaveScreenState createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<ApproveLeaveList> {
  List<LeaveRequest> leaveRequests = [
    LeaveRequest(
      fromDate: "18-7-2024",
      toDate: "18-7-2024",
      status: "Approved",
      reason: "My daughter is not feeling well, so she can't come to school.",
      isApproved: true,
    ),
    LeaveRequest(
      fromDate: "12-5-2023",
      toDate: "12-5-2023",
      status: "Disapproved",
      reason: "My daughter is attending a marriage function.",
      isApproved: false,
    ),
  ];

  void deleteRequest(int index) {
    setState(() {
      leaveRequests.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text("Leave"),
      //   backgroundColor: Colors.green,
      // ),
      body: ListView.builder(
        itemCount: leaveRequests.length,
        itemBuilder: (context, index) {
          final request = leaveRequests[index];
          return Stack(
            children: [
              Card(
                color: AppColors.secondary,
                margin: EdgeInsets.all(10),
                child: Padding(
                  padding: EdgeInsets.all(0),
                  child: Padding(
                    padding:  EdgeInsets.only(left: 8.0,right: 8),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(topRight: Radius.circular(10.sp),bottomRight: Radius.circular(10.sp))
                      ),
                      child: Padding(
                        padding:  EdgeInsets.all(8.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("From: ${request.fromDate}",
                                    style: TextStyle(fontWeight: FontWeight.bold)),

                                Text("To: ${request.toDate}",
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),

                            SizedBox(height: 5),
                            Row(
                              children: [
                                Text("Status: ",
                                    style: TextStyle(fontWeight: FontWeight.bold)),

                                Text(
                                  request.status,
                                  style: TextStyle(
                                    color: request.isApproved ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),


                            SizedBox(height: 5),
                            Text("Reason: ${request.reason}"),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                icon: Icon(Icons.delete, color: AppColors.secondary),
                                onPressed: () => deleteRequest(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: Container(
        width: double.infinity,
        height: 20.sp,
        color: AppColors.secondary,
        child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Powered By ',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'AviSun',
                  style: GoogleFonts.poppins(
                    color: Colors.orangeAccent,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),

                ),
              ],
            )),
      ),

    );
  }
}
