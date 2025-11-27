import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DataNotFoundWhiteScreenWidget extends StatelessWidget {
  final String title;
  const DataNotFoundWhiteScreenWidget({
    super.key, required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 450.sp,
        child: Container(
          child: Center(
              child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(10.sp),
                  child:
                  Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          height: 200.sp,
                            child: Image.asset('assets/no_attendance.png')),
                      ),
                      Center(child: Padding(
                        padding:  EdgeInsets.only(top: 258.sp),
                        child: Text(title,
                          style: GoogleFonts.radioCanada(
                            textStyle: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ))
                    ],
                  ))),
        ),
      ),
    );
  }
}
