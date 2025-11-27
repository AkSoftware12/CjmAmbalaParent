import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/scrollable_clean_calendar.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../../HexColorCode/HexColor.dart';
import '../../../UI/Dashboard/HomeScreen .dart';
import '../../../UI/Gallery/Album/album.dart';
import '../../../constants.dart';
import '../Assignment/assignment.dart';
import '../Auth/login_screen.dart';
import '../HomeWork/home_work.dart';
import '../Notice/notice.dart';
import '../Subject/subject.dart';
import '../TeacherMessage/message.dart';
import '../TimeTable/time_table_teacher.dart';
import '../bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? teacherData;
  List assignments = []; // Declare a list to hold API data
  bool isLoading = true;
  int? messageViewPermissionsApp;
  int? messageSendPermissionsApp;
  late CleanCalendarController calendarController;
  final List<Map<String, String>> items = [
    {
      'name': 'Assignments',
      'image': 'assets/assignments.png',
    },
    {
      'name': 'Time Table',
      'image': 'assets/watch.png',
    },
    {
      'name': 'Messages',
      'image': 'assets/message_home.png',
    },
    // {
    //   'name': 'Attendance',
    //   'image': 'assets/calendar_attendance.png',
    // },
    {
      'name': 'Activity Calendar',
      'image': 'assets/calendar_activity.png',
    },
    {
      'name': 'Gallery',
      'image': 'assets/gallery.png',
    },

  ];

  @override
  void initState() {
    super.initState();
    calendarController = CleanCalendarController(
      minDate: DateTime.now().subtract(const Duration(days: 30)),
      maxDate: DateTime.now().add(const Duration(days: 365)),
    );
    fetchStudentData();
    // fetchDasboardData();
  }

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getTeacheProfile),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        teacherData = data['teacher'];
        isLoading = false;
        print(teacherData);
      });
    } else {
      _showLoginDialog();
    }
  }

  Future<void> fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse(ApiRoutes.getDashboard); // Ensure ApiRoutes.getDashboard is valid

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          messageViewPermissionsApp = (data['permisions']?[0]['app_status'] as num?)?.toInt() ?? 0;
          messageSendPermissionsApp = (data['permisions']?[1]['app_status'] as num?)?.toInt() ?? 0;

        });
      } else {
        setState(() {

        });
      }
    } catch (e) {
      setState(() {
        // attendancePercent = 0.0; // Default value for error case

      });
      // Optionally log the error for debugging
      debugPrint('Error fetching data:  $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors2.primary,

      // appBar: AppBar(
      //   backgroundColor: AppColors2.secondary,
      //   title: Column(
      //     children: [
      //       _buildAppBar(),
      //     ],
      //   ),
      //   actions: [
      //     Padding(
      //       padding: const EdgeInsets.all(15.0),
      //       child: GestureDetector(
      //           onTap: () {},
      //           child: Icon(
      //             Icons.notification_add,
      //             size: 26,
      //             color: Colors.white,
      //           )),
      //     )
      //
      //     // Container(child: Icon(Icons.ice_skating)),
      //   ],
      // ),
      body: isLoading
          ? const Center(
              child: CupertinoActivityIndicator(radius: 20),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CarouselExample(),
                  SizedBox(height: 10),

                  _buildsellAll('Category', ''),

                  _buildGridview(),
                  const SizedBox(height: 10),

                  Container(
                    height: 220,
                    width: double.infinity,
                    child: Image.network(
                      'https://cjmambala.in/images/building.png',
                      fit: BoxFit.fill,
                    ),
                  ),


                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors2.secondary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: teacherData!['photo'] != null
                ? NetworkImage(teacherData!['photo'])
                : null,
            child: teacherData!['photo'] == null
                ? Image.asset(AppAssets.logo, fit: BoxFit.cover)
                : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors2.textblack,
                ),
              ),
              Text(
                teacherData!['student_name'] ?? 'Student',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors2.textblack,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white,
          radius: 20,
          backgroundImage: teacherData?['photo'] != null
              ? NetworkImage(teacherData!['photo'])
              : null,
          child: teacherData?['photo'] == null
              ? Image.asset(AppAssets.logo, fit: BoxFit.cover)
              : null,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome !',
              style: GoogleFonts.montserrat(
                textStyle: Theme.of(context).textTheme.displayLarge,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
                color: AppColors2.textblack,
              ),
            ),
            Text(
              teacherData?['student_name'] ?? 'Student',
              // Fallback to 'Student' if null
              style: GoogleFonts.montserrat(
                textStyle: Theme.of(context).textTheme.displayLarge,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
                color: AppColors2.textblack,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridview() {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        itemCount: items.length,
        // Kitne bhi items set kar sakte hain
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              if (items[index]['name'] == 'Assignments') {

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: Duration(milliseconds: 500), // Animation Speed
                    pageBuilder: (context, animation, secondaryAnimation) => AssignmentListScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      var begin = Offset(1.0, 0.0); // Right to Left
                      var end = Offset.zero;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );


              } else if (items[index]['name'] == 'Subject') {

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: Duration(milliseconds: 500), // Animation Speed
                    pageBuilder: (context, animation, secondaryAnimation) => SubjectScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      var begin = Offset(1.0, 0.0); // Right to Left
                      var end = Offset.zero;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );


              } else if (items[index]['name'] == 'Gallery') {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return GalleryScreen();
                    },
                  ),
                );

              } else if (items[index]['name'] == 'Messages') {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: Duration(milliseconds: 500), // Animation Speed
                    pageBuilder: (context, animation, secondaryAnimation) =>  TeacherMesssageListScreen(messageSendPermissionsApp: messageSendPermissionsApp,),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      var begin = Offset(1.0, 0.0); // Right to Left
                      var end = Offset.zero;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );


              } else if (items[index]['name'] == 'Activity Calendar') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return CalendarScreen(title: 'Activity Calendar',);
                    },
                  ),
                );


              } else if (items[index]['name'] == 'Time Table') {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: Duration(milliseconds: 500), // Animation Speed
                    pageBuilder: (context, animation, secondaryAnimation) => TimeTableTeacherScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      var begin = Offset(1.0, 0.0); // Right to Left
                      var end = Offset.zero;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(10)
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        items[index]['image']!,
                        height: 50, // Adjust the size as needed
                        width: 50,
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Text(
                        items[index]['name']!,
                        style: GoogleFonts.montserrat(
                          textStyle: Theme.of(context).textTheme.displayLarge,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.normal,
                          color: AppColors2.textblack,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: assignments.length, // Number of items in the list
        itemBuilder: (context, index) {
          final assignment = assignments[index];

          String description =
              html_parser.parse(assignment['description']).body?.text ?? '';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return AssignmentListScreen();
                  },
                ),
              );
            },
            child: Card(
              elevation: 5,
              color: AppColors2.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Colors.grey.shade300, // Border color
                  width: 1.5, // Border width
                ), // Rounded corners
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  color: HexColor('#f2888c'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: Colors.grey.shade300, // Border color
                      width: 1, // Border width
                    ), // Rounded corners
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(8.0),
                    leading: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: AppColors2.textblack,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}', // Displaying the index number
                          style: GoogleFonts.montserrat(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: AppColors2.textblack,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      assignments[index]['title'].toString().toUpperCase(),
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors2.textblack,
                      ),
                    ),
                    subtitle: Text(
                      description,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade300,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 25),
                    // Optional arrow icon
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return AssignmentListScreen();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildsellAll(String title, String see) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 15, top: 10, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
              color: AppColors2.textblack,
            ),
          ),
          Text(
            see,
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.normal,
              color: AppColors2.textblack,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool isCalendar;
  final CleanCalendarController? calendarController;
  final color;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.isCalendar = false,
    this.calendarController,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: this.color,
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors2.textblack),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(fontSize: 16, color: AppColors2.textblack),
            ),
            if (isCalendar) const SizedBox(height: 16),
            if (isCalendar)
              Container(
                height: 300,
                child: ScrollableCleanCalendar(
                  daySelectedBackgroundColor: AppColors2.primary,
                  dayBackgroundColor: AppColors2.textblack,
                  daySelectedBackgroundColorBetween: AppColors2.primary,
                  dayDisableBackgroundColor: AppColors2.textblack,
                  dayDisableColor: AppColors2.textblack,
                  calendarController: calendarController!,
                  layout: Layout.DEFAULT,
                  monthTextStyle:
                      TextStyle(fontSize: 18, color: AppColors2.textblack),
                  weekdayTextStyle:
                      TextStyle(fontSize: 16, color: AppColors2.textblack),
                  dayTextStyle:
                      TextStyle(fontSize: 14, color: AppColors2.textblack),
                  padding: const EdgeInsets.all(8.0),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class CarouselFees extends StatelessWidget {
  final List<Map<String, String>> imgList = [
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Welcome to CJM Ambala'
    },
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Best School for Excellence'
    },
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Learn, Grow & Succeed'
    },
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Join Our Community'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: CarouselSlider(
          options: CarouselOptions(
            height: 180,
            autoPlay: true,
            viewportFraction: 1,
            enableInfiniteScroll: true,
            autoPlayInterval: Duration(seconds: 10),
            autoPlayAnimationDuration: Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            scrollDirection: Axis.horizontal,
          ),
          items: imgList.map((item) {
            return DueAmountCard(
              dueAmount: 1250.75, // Example due amount
              onPayNow: () {
                print("Redirecting to payment...");

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => TeacherBottomNavBarScreen(initialIndex: 3,)),
                );
              },
            );

            //   GestureDetector(
            //   onTap: () {
            //     print('Image Clicked: ${item['text']}');
            //   },
            //   child: Padding(
            //     padding: const EdgeInsets.all(5.0),
            //     child: Container(
            //       width: double.infinity,
            //       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            //       decoration: BoxDecoration(
            //         color: Colors.black.withOpacity(0.6),
            //         borderRadius: BorderRadius.circular(5),
            //       ),
            //       child: Text(
            //         item['text']!,
            //         textAlign: TextAlign.center,
            //         style: TextStyle(
            //           color: Colors.white,
            //           fontSize: 16,
            //           fontWeight: FontWeight.bold,
            //         ),
            //       ),
            //     ),
            //   ),
            // );
          }).toList(),
        ),
      ),
    );
  }
}

class DueAmountCard extends StatelessWidget {
  final double dueAmount;
  final VoidCallback onPayNow;

  DueAmountCard({required this.dueAmount, required this.onPayNow});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.red, Colors.white, Colors.red], // Gradient Colors
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            Text(
              "Due Amount",
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: HexColor('#f62c13'), // Highlight in Yellow
              ),
            ),
            SizedBox(height: 8),

            // Amount
            Text(
              "₹${dueAmount.toStringAsFixed(2)}",
              style: GoogleFonts.montserrat(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: HexColor('#f62c13'), // Highlight in Yellow
              ),
            ),
            SizedBox(height: 12),

            // Pay Now Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPayNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // White button for contrast
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Pay Now",
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent, // Matching gradient color
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PromotionCard extends StatelessWidget {
  const PromotionCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppColors2.secondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors2.textblack, // You can change the color as needed
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 18.0),
              child: Image.asset(
                AppAssets.logo,
                color: AppColors2.textblack,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '3D Design \nFundamentals',
                    style: GoogleFonts.montserrat(
                      textStyle: Theme.of(context).textTheme.displayLarge,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      color: AppColors2.textblack,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppColors2.primary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: HexColor('#e16a54'),
                        // You can change the color as needed
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          'Click',
                          style: GoogleFonts.montserrat(
                            textStyle: Theme.of(context).textTheme.displayLarge,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.normal,
                            color: AppColors2.textblack,
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
