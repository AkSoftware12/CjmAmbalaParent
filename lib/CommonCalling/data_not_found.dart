// File: data_not_found.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DataNotFoundWidget extends StatelessWidget {
  final String title;

  const DataNotFoundWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(
          minHeight: 100.sp, // Minimum height to ensure visibility
        ),
        padding: EdgeInsets.all(16.sp),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Use min to avoid taking extra space
          children: [
            Icon(
              Icons.info_outline,
              size: 40.sp,
              color: Colors.white,
            ),
            SizedBox(height: 10.sp),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}