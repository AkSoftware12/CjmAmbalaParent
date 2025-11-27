import 'dart:async';
import 'dart:convert';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:avi/constants.dart';
import 'package:day_picker/day_picker.dart';
import 'package:day_picker/model/day_in_week.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../Auth/login_screen.dart';

class TimeTableScreen extends StatefulWidget {
  const TimeTableScreen({super.key});

  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> {

  bool isLoading = false;
  List timeTable = []; // Declare a list to hold API data
  int? selectedIndex; // Track selected index
  double dotPosition = 0.0;

  // Always start week from Monday
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  @override
  void initState() {
    super.initState();

    updateDotPosition();
    Timer.periodic(Duration(minutes: 1), (timer) {
      updateDotPosition();
    });
    // Automatically highlight today’s corresponding weekday
    DateTime now = DateTime.now();
    int todayWeekday = now.weekday; // 1 (Monday) to 7 (Sunday)

    // Adjust the index to match the fixed Monday-starting week list
    selectedIndex = (todayWeekday - 0) % 7; // Shift to Monday-based index
    DateTime.now().subtract(const Duration(days: 30));
    fetchAssignmentsData(selectedIndex);
  }


  Future<void> fetchAssignmentsData(int? index) async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse('${ApiRoutes.getTimeTable}$index'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        timeTable = jsonResponse['data'];
        isLoading = false; // Stop progress bar
// Update state with fetched data
      });
    } else {
      _showLoginDialog();
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showLoginDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Please log in again to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  void updateDotPosition() {
    DateTime now = DateTime.now();
    double totalMinutes = 24 * 60; // Total minutes in a day
    int currentMinutes = now.hour * 60 + now.minute;

    // Timeline ki height ke hisaab se position calculate karna
    double maxHeight = 300.0; // Change this according to your timeline height
    double newPosition = (currentMinutes / totalMinutes) * maxHeight;
    setState(() {
      dotPosition = newPosition;
    });
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // backgroundColor: HexColor('#c0d4f2'),
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
          iconTheme: IconThemeData(color: AppColors.textwhite),
          backgroundColor: AppColors.secondary,
          // backgroundColor: HexColor('#c0d4f2'),
          title: Text(
            'Time Table',
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.normal,
              color: AppColors.textwhite,
            ),
          )),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height:  MediaQuery.of(context).size.height* 0.99,
              decoration: BoxDecoration(
                color: HexColor('#dfe6f1'),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30.sp),topRight: Radius.circular(30.sp)),
              ),
              child: Stack(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20.sp),
                              topRight: Radius.circular(20.sp),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildRow("Selected Day", '', Icons.calendar_today, Colors.blueGrey),
                              Padding(
                                padding: EdgeInsets.only(bottom: 10.sp),
                                child: SizedBox(
                                  height: 65.sp, // Adjust height for better appearance
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: days.length,
                                    itemBuilder: (context, index) {
                                      bool isSelected = selectedIndex == index + 1; // Ensure 1-based index

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedIndex = index + 1; // Store values as 1 to 7 instead of 0 to 6
                                          });
                                          fetchAssignmentsData(selectedIndex);
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 15.sp, vertical: 15.sp),
                                          margin: const EdgeInsets.symmetric(horizontal: 5),
                                          decoration: BoxDecoration(
                                            color: isSelected ? HexColor('#93a0e8') : Colors.grey[300],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              days[index],
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : HexColor('#515992'),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding:  EdgeInsets.only(top: 8.0),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.99,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30.sp),
                                topRight: Radius.circular(30.sp),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildRow("", '', Icons.calendar_today, Colors.blueGrey),
                                isLoading
                                    ? Center(
                                    child: Container(
                                        height: MediaQuery.of(context).size.height * 0.5,
                                        child: CupertinoActivityIndicator(radius: 25,color: AppColors.primary,)))
                                    : timeTable.isEmpty
                                    ? Center(child: DataNotFoundWidget(title: 'Time Table Not Available.'))
                                    :           Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 80,
                                        top: 10,
                                        bottom: 0,
                                        child: Container(
                                          width: 1,
                                          color: Colors.blue[300],
                                        ),
                                      ),
                                      ListView.builder(
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                        itemCount: timeTable.length,
                                        itemBuilder: (context, index) {
                                          final schedule = timeTable[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [

                                                // Time Indicator
                                                Column(
                                                  children: [
                                                    Text(
                                                      schedule['start_time'].split(" - ")[0],
                                                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                                    ),
                                                    Container(
                                                      height: 3.sp,
                                                      width: 45.sp,
                                                      decoration: BoxDecoration(
                                                          color: Colors.grey,

                                                          borderRadius: BorderRadius.circular(10)
                                                      ),
                                                    ),
                                                    // SizedBox(height: 80.sp),
                                                    Text(
                                                      schedule['end_time'].split(" - ")[0],
                                                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(width: 15),
                                                // Subject Card
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: (){
                                                      // Navigator.push(
                                                      //   context,
                                                      //   MaterialPageRoute(
                                                      //     builder: (context) {
                                                      //       return TimetableApp();
                                                      //     },
                                                      //   ),
                                                      // );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        // color: Colors.orange.shade50,
                                                        color: Colors.grey.shade200,
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      margin: const EdgeInsets.symmetric(vertical: 0.0),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                                        child: ListTile(
                                                          contentPadding: EdgeInsets.zero,
                                                          leading: Container(
                                                            padding: EdgeInsets.all(10),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blueAccent.withOpacity(0.1),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(
                                                              Icons.book,
                                                              size: 30,
                                                              color: Colors.blueAccent,
                                                            ),
                                                          ),
                                                          title: Text(
                                                            schedule['subject_name'],
                                                            style: GoogleFonts.montserrat(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w800,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                          subtitle: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              SizedBox(height: 6),
                                                              Row(
                                                                children: [
                                                                  Icon(Icons.watch_later_outlined, size: 18, color: Colors.grey.shade700),
                                                                  SizedBox(width: 6),
                                                                  Text(
                                                                    "${schedule['start_time']} - ${schedule['end_time']}",
                                                                    style: GoogleFonts.montserrat(
                                                                      fontSize: 14,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Colors.grey.shade800,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(height: 5),
                                                              Row(
                                                                children: [
                                                                  SizedBox(
                                                                    height: 18,
                                                                    width: 18,
                                                                    child: Image.asset('assets/teacher.png', color: Colors.black),
                                                                  ),
                                                                  SizedBox(width: 6),
                                                                  Expanded(
                                                                    child: Text(
                                                                      schedule['teacher_name'],
                                                                      style: GoogleFonts.montserrat(
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: Colors.grey.shade800,
                                                                      ),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(height: 5),
                                                              // Row(
                                                              //   children: [
                                                              //     Icon(Icons.meeting_room, size: 18, color: Colors.grey.shade700),
                                                              //     SizedBox(width: 6),
                                                              //     // Text(
                                                              //     //   "Room No. ${schedule['room_name']}",
                                                              //     //   style: GoogleFonts.montserrat(
                                                              //     //     fontSize: 14,
                                                              //     //     fontWeight: FontWeight.w600,
                                                              //     //     color: Colors.grey.shade800,
                                                              //     //   ),
                                                              //     // ),
                                                              //   ],
                                                              // ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                    ],
                                  ),
                                ),




                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),


                ],
              ),

            ),






          ],
        ),
      ),

    );
  }
  Widget _buildRow(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.cabin(
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              color: HexColor('#515992'),
            ),
          ),
        ],
      ),
    );
  }


}

