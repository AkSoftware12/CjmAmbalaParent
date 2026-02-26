import 'package:avi/UI/Notification/notification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../TecaherUi/UI/BirthdayScreen/birthday_screen.dart';
import '../UI/Dashboard/HomeScreen%20.dart';
import '../constants.dart';
import '../strings.dart';
import 'Achievements/achievements.dart';
import 'Assignment/assignment.dart';
import 'Attendance/AttendanceScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Auth/login_screen.dart';
import 'Auth/login_student_userlist.dart';
import 'EbooksScreen/Ebooks/ebooks.dart' hide ApiRoutes;
import 'Fees/FeesScreen.dart';
import 'Gallery/Album/album.dart' show GalleryScreen;
import 'Help/help.dart';
import 'KnowYourTeacher/know_your_teacher.dart';
import 'Library/LibraryScreen.dart';
import 'Message/message.dart';
import 'ActivityCalendar/activity_calendar.dart';
import 'Notice/notice.dart';
import 'Profile/ProfileScreen.dart';
import 'TimeTable/time_table.dart';
import 'TransactionLibrary/transaction_library.dart';
import 'Videos/video_screen.dart';

class BottomNavBarScreen extends StatefulWidget {
  // final String token;
  final int initialIndex;

  const BottomNavBarScreen({super.key, required this.initialIndex});

  @override
  _BottomNavBarScreenState createState() => _BottomNavBarScreenState();
}

class _BottomNavBarScreenState extends State<BottomNavBarScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? studentData;
  bool isLoading = true;
  String currentVersion = '';
  int? messageViewPermissionsApp;
  int? messageSendPermissionsApp;

  // List of screens
  final List<Widget> _screens = [
    HomeScreen(),
    AttendanceCalendarScreen(title: 'Attendance'),
    LibraryScreen(appBar: '',),
    CalendarScreen(title: ''),
    // FeesScreen(),
    ProfileScreen(appBar: '',),
  ];



  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    checkForVersion(context);

    fetchData();

    fetchStudentData();
    _selectedIndex = widget.initialIndex; // Set the initial tab index
  }

  Future<void> checkForVersion(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
  }

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfile),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      var photoUrl = data['student']?['photo'];

      // Check if image actually exists
      if (photoUrl != null && photoUrl.toString().isNotEmpty) {
        final imgCheck = await http.head(Uri.parse(photoUrl));
        if (imgCheck.statusCode != 200) {
          photoUrl = null; // Use null if file not found
        }
      }

      setState(() {
        studentData = {...data['student'], 'photo': photoUrl};
        isLoading = false;
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
          // Handle attendance_percent as double to support decimal values
          // attendancePercent = (data['attendance_percent'] as num?)?.toDouble() ?? 0.0;
          // Uncomment and fix if permissions are needed
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
      debugPrint('Error fetching data: $e');
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

  Widget _buildAppBar() {
    return Row(
      children: [
        Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.all(0),
            child: GestureDetector(
              onTap: () {
                Scaffold.of(context).openDrawer();
              },
              child: SizedBox(
                height: 30,
                width: 30,
                child: Image.asset('assets/menu.png'),
              ),
            ),
          ), // Ensure Scaffold is in context
        ),

        SizedBox(width: 16),
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
                color: AppColors.textwhite,
              ),
            ),
            GestureDetector(
              // onTap: () {
              //   showModalBottomSheet(
              //     context: context,
              //     isScrollControlled: true,
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              //     ),
              //     builder: (BuildContext context) {
              //       return WillPopScope(
              //         onWillPop: () async {
              //           Navigator.pop(context); // Close bottom sheet on back press
              //           return false; // Prevent app from closing
              //         },
              //         child: Container(
              //           color: Colors.transparent,
              //           height: MediaQuery.of(context).size.height * 0.6, // Set height to 60% of screen
              //           padding: EdgeInsets.all(16),
              //           child: LoginStudentPage(),
              //         ),
              //       );
              //     },
              //   );
              //
              // },
              onTap: () {
                Navigator.push(
                  context,
                  // MaterialPageRoute(builder: (context) => LoginStudentPage()),
                  MaterialPageRoute(builder: (context) => LoginUserLIst()),
                );
              },
              child: Row(
                children: [
                  Text(
                    '${studentData?['student_name'].toString() ?? ' Student'}',
                    style: GoogleFonts.montserrat(
                      textStyle: Theme.of(context).textTheme.displayLarge,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                      color: AppColors.textwhite,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        drawerEnableOpenDragGesture: false,

        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          automaticallyImplyLeading: false,
          iconTheme: IconThemeData(color: AppColors.textwhite),
          title: Column(children: [_buildAppBar()]),
          actions: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return NotificationScreen();
                      },
                    ),
                  );
                },
                child: Icon(
                  Icons.notification_add,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ),

            // Container(child: Icon(Icons.ice_skating)),
          ],
        ),
        body: _screens[_selectedIndex],
        // Display the selected screen
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.red.shade900,
          selectedItemColor: AppColors.textwhite,
          unselectedItemColor: AppColors.grey,
          showSelectedLabels: true,
          // ✅ Ensures selected labels are always visible
          showUnselectedLabels: true,
          // ✅ Ensures unselected labels are also visible
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home),
              label: AppStrings.homeLabel,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.clock),
              label: AppStrings.attendanceLabel,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.book_fill),
              label: AppStrings.libraryLabel,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: AppStrings.activity,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_alt_circle_fill),
              label: AppStrings.profileLabel,
              backgroundColor: AppColors.primary,
            ),
          ],
        ),
        drawer: Drawer(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          width: MediaQuery.sizeOf(context).width * .65,
          // backgroundColor: Theme.of(context).colorScheme.background,
          backgroundColor: AppColors.secondary,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 70),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return ProfileScreen(appBar: 'appbar');
                        },
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage:
                    (studentData != null &&
                        studentData?['photo'] != null &&
                        studentData!['photo'].toString().isNotEmpty &&
                        !studentData!['photo'].toString().endsWith(
                          "null",
                        ))
                        ? NetworkImage(studentData!['photo'])
                        : null,
                    child:
                    (studentData == null ||
                        studentData?['photo'] == null ||
                        studentData!['photo'].toString().isEmpty)
                        ? const Icon(Icons.account_circle, size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    child: Padding(
                      padding: EdgeInsets.only(top: 0, bottom: 0),
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Text(
                          studentData?['student_name'] ?? 'Student',
                          // Fallback to 'Student' if null
                          style: GoogleFonts.montserrat(
                            textStyle: Theme.of(
                              context,
                            ).textTheme.displayLarge,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.normal,
                            color: AppColors.textwhite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    child: Padding(
                      padding: EdgeInsets.only(top: 0, bottom: 20),
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Text(
                          studentData?['email'] ?? '',
                          // Fallback to 'Student' if null
                          style: GoogleFonts.montserrat(
                            textStyle: Theme.of(
                              context,
                            ).textTheme.displayLarge,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.normal,
                            color: AppColors.textwhite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(
                  color: Colors.grey.shade300,
                  // Set the color of the divider
                  thickness: 2.0,
                  // Set the thickness of the divider
                  height: 1, // Set the height of the divider
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ListTile(
                              title: Text(
                                'Dashboard',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  Icons.dashboard,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);

                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (context) {
                                //       return DownloadPdf();
                                //     },
                                //   ),
                                // );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Attendance',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  CupertinoIcons.clock,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);

                                // Navigate to the Profile screen in the BottomNavigationBar
                                setState(() {
                                  _selectedIndex =
                                  1; // Index of the Profile screen in _screens
                                });
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (context) {
                                //       return DownloadPdf();
                                //     },
                                //   ),
                                // );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),


                            ListTile(
                              title: Text(
                                'Notice',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  CupertinoIcons.bell,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return NoticeScreen();
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Birthday List',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                      color:AppColors2.textblack,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors2.primary,
                                child: Icon(CupertinoIcons.gift,color:AppColors2.textblack,),

                              ),
                              onTap: () {

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return  BirthdayScreen();
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding:
                              EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'My Profile',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  CupertinoIcons.person,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return ProfileScreen(appBar: 'app',);
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Know Your Teacher',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  CupertinoIcons.person_2_alt,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return TeacherListPremiumScreen();
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),


                            ListTile(
                              title: Text(
                                'Library Transaction',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  CupertinoIcons.creditcard,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return IssuedBooksScreen();
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Assignments',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset(
                                  'assets/assignments.png',
                                  height: 80, // Adjust the size as needed
                                  width: 80,
                                ),
                              ),
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
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Fees',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  Icons.currency_rupee,
                                  color: Colors.white,
                                ),

                                // Image.asset(
                                //   'assets/assignments.png',
                                //   height: 80, // Adjust the size as needed
                                //   width: 80,
                                // ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return FeesScreen(title: 'aa');
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Time Table',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset(
                                  'assets/watch.png',
                                  height: 80, // Adjust the size as needed
                                  width: 80,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return TimeTableScreen();
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Messages',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset(
                                  'assets/message_home.png',
                                  height: 80, // Adjust the size as needed
                                  width: 80,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return MesssageListScreen(messageSendPermissionsApp: messageSendPermissionsApp,);
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),
                            ListTile(
                              title: Text(
                                ' Photo Gallery',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset(
                                  'assets/gallery.png',
                                  height: 80, // Adjust the size as needed
                                  width: 80,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return GalleryScreen();
                                    },
                                  ),
                                );
                              },
                            ),

                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),



                            ListTile(
                              title: Text(
                                'Video Gallery',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child:Icon(CupertinoIcons.video_camera, color: Colors.white)
                                ,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return VideoGallery();
                                    },
                                  ),
                                );
                              },
                            ),

                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Achievement Gallery',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child:Icon(CupertinoIcons.rosette, color: Colors.white)
                                ,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return AchievementsWaveScreen();
                                    },
                                  ),
                                );
                              },
                            ),

                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),


                            ListTile(
                              title: Text(
                                'E Books',
                                style: GoogleFonts.cabin(
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset(
                                  'assets/ebook.png',
                                  height: 80, // Adjust the size as needed
                                  width: 80,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return EbooksScreen();
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Activity Calendar',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset(
                                  'assets/document.png',
                                  height: 80, // Adjust the size as needed
                                  width: 80,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return CalendarScreen(
                                        title: 'Activity Calendar',
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            ListTile(
                              title: Text(
                                'Help',
                                style: GoogleFonts.cabin(
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 25,
                                width: 25,
                                child: Image.asset(
                                  'assets/help.png',
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return HelpScreen(appBar: 'Help');
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),

                            // ListTile(
                            //   title: Text(
                            //     'FAQs',
                            //     style: GoogleFonts.cabin(
                            //       textStyle: TextStyle(
                            //           color: Colors.white,
                            //           fontSize: 15,
                            //           fontWeight: FontWeight.normal),
                            //     ),
                            //   ),
                            //   trailing: Container(
                            //       height: 20,
                            //       width: 20,
                            //       child: Image.asset('assets/faq.png')),
                            //   onTap: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) {
                            //           return FaqScreen(appBar: 'FAQ',);
                            //         },
                            //       ),
                            //     );
                            //   },
                            // ),
                            // Padding(
                            //   padding:
                            //   EdgeInsets.only(left: 8, right: 8),
                            //   child: Divider(
                            //     height: 1,
                            //     color: Colors.grey.shade300,
                            //     thickness: 1,
                            //   ),
                            // ),
                            // ListTile(
                            //   title: Text(
                            //     'Privacy',
                            //     style: GoogleFonts.cabin(
                            //       textStyle: TextStyle(
                            //           color: Colors.white,
                            //           fontSize: 15,
                            //           fontWeight: FontWeight.normal),
                            //     ),
                            //   ),
                            //   trailing: Container(
                            //       height: 20,
                            //       width: 20,
                            //       child: Icon(
                            //         Icons.privacy_tip,
                            //         color: Colors.white,
                            //       )),
                            //   onTap: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) {
                            //           return WebViewExample(
                            //             title: 'Privacy',
                            //             url:
                            //             'https://www.freeprivacypolicy.com/live/79492741-6341-4ea2-a3b1-87ffc1154bda',
                            //           );
                            //         },
                            //       ),
                            //     );
                            //   },
                            // ),
                            // Padding(
                            //   padding:
                            //   EdgeInsets.only(left: 8, right: 8),
                            //   child: Divider(
                            //     height: 1,
                            //     color: Colors.grey.shade300,
                            //     thickness: 1,
                            //   ),
                            // ),
                            // ListTile(
                            //   title: Text(
                            //     'Terms & Condition',
                            //     style: GoogleFonts.cabin(
                            //       textStyle: TextStyle(
                            //           color: Colors.white,
                            //           fontSize: 15,
                            //           fontWeight: FontWeight.normal),
                            //     ),
                            //   ),
                            //   trailing: Container(
                            //       height: 20,
                            //       width: 20,
                            //       child: Icon(
                            //         Icons.event_note_outlined,
                            //         color: Colors.white,
                            //       )),
                            //   onTap: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) {
                            //           return WebViewExample(
                            //             title: 'Terms & Condition',
                            //             url:
                            //             'https://www.freeprivacypolicy.com/live/79492741-6341-4ea2-a3b1-87ffc1154bda',
                            //           );
                            //         },
                            //       ),
                            //     );
                            //   },
                            // ),
                            Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),
                            ListTile(
                              title: Text(
                                'Logout',
                                style: GoogleFonts.cabin(
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                child: const Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () async {
                                final prefs =
                                await SharedPreferences.getInstance();
                                await prefs
                                    .clear(); // Clear the stored token
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      Padding(padding: EdgeInsets.only(bottom: 15.sp)),
                      Center(
                        child: Text(
                          'Version :-  $currentVersion',
                          style: GoogleFonts.cabin(
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }
}
