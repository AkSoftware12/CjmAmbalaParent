import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants.dart';

class ApplyLeaves extends StatefulWidget {
  @override
  _LeaveRequestScreenState createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<ApplyLeaves> {
  DateTime? fromDate;
  DateTime? toDate;
  TextEditingController reasonController = TextEditingController();

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        if (isFromDate) {
          fromDate = pickedDate;
        } else {
          toDate = pickedDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text("Leave"),
      //   backgroundColor: Colors.green,
      //   leading: IconButton(
      //     icon: Icon(Icons.arrow_back),
      //     onPressed: () => Navigator.pop(context),
      //   ),
      // ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(0.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.all(8.sp),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.sp),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary, // Shadow color
                        blurRadius: 10, // Softness of the shadow
                        spreadRadius: 2, // How much the shadow spreads
                        offset: Offset(0, 0), // Changes position of shadow
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        SizedBox(height: 30.sp),
                        _buildDatePickerField("Tap to select the From Date",
                            fromDate, true, context),
                        SizedBox(height: 20.sp),
                        TextField(
                          controller: reasonController,
                          maxLines: 6,
                          maxLength: 200,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: "Reason (Max 100 words)",
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.blue, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 30.sp),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                          ),
                          child: Text(
                            "Submit",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16.sp),
                          ),
                        ),
                        SizedBox(height: 10.sp),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildDatePickerField(String hintText, DateTime? selectedDate,
      bool isFromDate, BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, isFromDate),
      borderRadius: BorderRadius.circular(10), // Smooth touch effect
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.sp),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary, // Shadow color
              blurRadius: 0, // Softness of the shadow
              spreadRadius: 2, // How much the shadow spreads
              offset: Offset(0, 0), // Changes position of shadow
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedDate == null
                    ? hintText
                    : "${selectedDate.toLocal()}".split(' ')[0],
                style: TextStyle(
                  color: selectedDate == null ? Colors.grey[600] : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.calendar_today, color: AppColors.secondary, size: 20),
              // Modern icon color
            ],
          ),
        ),
      ),
    );
  }
}
