import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../CommonCalling/data_not_found.dart';
import '../../../constants.dart';
import '../../../utils/textSize.dart';
import '../Auth/login_screen.dart';

class TimeTableTeacherScreen extends StatefulWidget {
  const TimeTableTeacherScreen({super.key});

  @override
  State<TimeTableTeacherScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableTeacherScreen> {

  bool isLoading = false;
  List timeTable = []; // Declare a list to hold API data
  int? selectedIndex; // Track selected index
  double dotPosition = 0.0;

  // Always start week from Monday
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  final List<String> images = [
    "assets/mon_icon.png",
    "assets/tue_icon.png",
    "assets/wed_icon.png",
    "assets/thus_icon.png",
    "assets/fri_icon.png",
    "assets/sat_icon.png",
    "assets/sun_icon.png",

  ];

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
    final token = prefs.getString('teachertoken');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse('${ApiRoutes.getTeacherTimeTable}$index'),
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
      builder: (ctx) =>
          CupertinoAlertDialog(
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
  String _getMonthName(int month) {
    const List<String> months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: HexColor('#c0d4f2'),
      // backgroundColor: AppColors2.primary,
      // appBar: AppBar(
      //     iconTheme: IconThemeData(color: AppColors2.textblack),
      //     // backgroundColor: AppColors2.primary,
      //     backgroundColor: HexColor('#7a211b'),
      //     title: Text(
      //       'Time Table',
      //       style: GoogleFonts.montserrat(
      //         textStyle: Theme.of(context).textTheme.displayLarge,
      //         fontSize: 20,
      //         fontWeight: FontWeight.w600,
      //         fontStyle: FontStyle.normal,
      //         color: AppColors2.textblack,
      //       ),
      //     )),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors2.primary, AppColors2.primary],
                // Change colors as needed
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),


          Column(
            children: [
              Card(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      30), // Optional rounded corners
                ),
                elevation: 4,
                // Adds shadow for better visibility
                margin: EdgeInsets.all(0),
                // Adds some space around the card
                child: Container(
                  // color: Colors.transparent,
                  width: double.infinity, // Makes the card expand horizontally
                  padding: EdgeInsets.all(5.sp), // Adds padding inside the card
                  child: Column(
                    children: [
                      SizedBox(
                        height: 25.sp,
                      ),

                      Stack(
                        children: [
                          Container(
                            height: 55.sp,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    icon: Icon(
                                        Icons.arrow_back_ios, size: 20.sp,
                                        color: Colors.white),
                                  ),

                                ],
                              ),
                            ),
                          ),
                          Container(
                            height: 55.sp,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Time Table',
                                    style: GoogleFonts.poppins(
                                      textStyle: Theme
                                          .of(context)
                                          .textTheme
                                          .displayLarge,
                                      fontSize: TextSizes.textmedium,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.normal,
                                      color: AppColors2.textwhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        ],
                      ),
                      Container(
                        width: double.infinity,
                        decoration:BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25.sp)
                        ),
                        child: Column(
                        children: [
                          _buildRow("Selected Day", '', Icons.calendar_today,
                              Colors.blueGrey),
                          Padding(
                            padding: EdgeInsets.only(bottom: 10.sp),
                            child: SizedBox(
                              height: 70.sp,

                              // Adjust height for better appearance
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 7, // 7 days (Monday to Sunday)
                                itemBuilder: (context, index) {
                                  bool isSelected = selectedIndex == index + 1; // Ensure 1-based index

                                  DateTime today = DateTime.now();
                                  int currentWeekday = today.weekday; // Monday = 1, Sunday = 7
                                  DateTime weekStart = today.subtract(Duration(days: currentWeekday - 1)); // Get Monday
                                  DateTime currentDate = weekStart.add(Duration(days: index)); // Get each day from Monday to Sunday

                                  String formattedDate = "${currentDate.day} ${_getMonthName(currentDate.month)}";

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedIndex = index + 1; // Store values as 1 to 7 instead of 0 to 6
                                      });
                                      fetchAssignmentsData(selectedIndex);
                                    },
                                    child: Container(
                                      height: 70.sp,
                                      width: 70.sp,
                                      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 5.sp),
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors2.primary : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Image.asset(images[index], height: 30.sp, width: 40.sp),
                                            SizedBox(height: 5.sp),
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ],
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



                    ],
                  ),
                ),
              ),


              Expanded(
                child: isLoading
                    ? Center(
                    child: Container(
                        height: MediaQuery
                            .of(context)
                            .size
                            .height * 0.5,
                        child: CupertinoActivityIndicator(
                          radius: 25, color: AppColors2.primary,)))
                    : timeTable.isEmpty
                    ? Center(child: DataNotFoundWidget(
                    title: 'Time Table Not Available.'))
                    : Stack(
                  children: [

                    Positioned.fill(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        itemCount: timeTable.length,
                        itemBuilder: (context, index) {
                          final schedule = timeTable[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [


                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
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
                                        color: Colors.red.shade200,
                                        // color: HexColor('#9d6763'),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: const EdgeInsets.symmetric(vertical: 0.0),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 0, horizontal: 8),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Container(
                                            height: 50.sp,
                                            width: 50.sp,
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Image.asset('assets/education.png',height: 50.sp,width: 50.sp,)
                                          ),
                                          title: Text(
                                            schedule['subject_name'],
                                            style: GoogleFonts.poppins(
                                              fontSize: TextSizes.textmedium,
                                              fontWeight: FontWeight.w700,
                                              color:AppColors2.textwhite,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment
                                                .start,
                                            children: [
                                              SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons
                                                      .watch_later_outlined,
                                                      size: 18,
                                                      color: Colors.white
                                                         ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    "${schedule['start_time']} - ${schedule['end_time']}",
                                                    style: GoogleFonts
                                                        .poppins(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white
                                                          ,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 5),

                                              Divider(
                                                height: 2.sp,
                                                color: Colors.white .withOpacity(0.1),
                                                thickness: 2.sp,
                                              ),
                                              SizedBox(height: 5),

                                              Row(
                                                children: [
                                                  SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child: Image.asset(
                                                        'assets/teacher.png',
                                                        color: Colors.white),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          '${schedule['class']
                                                              .toString()} ${'(${schedule['section']
                                                              .toString()})'}',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.meeting_room,
                                                          size: 18,
                                                          color: Colors.white),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        "Room No. ${schedule['room']}",
                                                        style: GoogleFonts
                                                            .poppins(
                                                          fontSize: 12.sp,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
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
                    ),

                  ],
                ),)
            ],
          ),

        ],
      ),

    );
  }

  Widget _buildRow(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(top: 10.sp,bottom: 10.sp),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: TextSizes.textmedium,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

