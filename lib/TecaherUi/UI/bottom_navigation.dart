import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../UI/Achievements/achievements.dart';
import '../../UI/Auth/login_screen.dart';
import '../../UI/Auth/login_student_userlist.dart';
import '../../UI/EbooksScreen/Ebooks/ebooks.dart';
import '../../UI/Gallery/Album/album.dart';
import '../../UI/Library/LibraryScreen.dart' show LibraryScreen;
import '../../UI/Notice/notice.dart';
import '../../UI/TransactionLibrary/transaction_library.dart';
import '../../UI/Videos/video_screen.dart';
import '../../constants.dart';
import '../../strings.dart';
import '../UI/Dashboard/HomeScreen%20.dart';
import 'AllStudents/all_students.dart';
import 'Assignment/assignment.dart';
import 'Attendance/AttendanceScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'BirthdayScreen/birthday_screen.dart';
import 'ClassTeacher/class_teacher.dart';
import 'Notice/notice.dart';
import 'Notification/notification.dart';
import 'Profile/ProfileScreen.dart';
import 'TeacherMessage/message.dart';
import 'TeachingStaff/teaching_staff.dart';
import 'TimeTable/time_table_teacher.dart';

class TeacherBottomNavBarScreen extends StatefulWidget {
  // final String token;
  final int initialIndex;
  const TeacherBottomNavBarScreen({super.key, required this.initialIndex});
  @override
  _BottomNavBarScreenState createState() => _BottomNavBarScreenState();
}

class _BottomNavBarScreenState extends State<TeacherBottomNavBarScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? teacherData;
  // Map<String, dynamic>? teacherData;
  bool isLoading = true;
  String currentVersion = '';
  int? messageViewPermissionsApp;
  int? messageSendPermissionsApp;
  // List of screens
  final List<Widget> _screens = [
    HomeScreen(),
    AttendanceTabScreen(),
    LibraryScreen(appBar: '',),
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
  Future<void> fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    final url = Uri.parse(ApiRoutes.getTeacherDashboard); // Ensure ApiRoutes.getDashboard is valid

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

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    print("Token: $token");

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
    }
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
                child: Image.asset('assets/menu.png',color: AppColors2.textblack,),
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
                color: AppColors2.textblack,
              ),
            ),
            GestureDetector(
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
                    '${teacherData?['first_name']??'Teacher'} ${teacherData?['last_name']??''}' ?? 'Teacher', // Fallback to 'Student' if null
                    style: GoogleFonts.montserrat(
                      textStyle: Theme.of(context).textTheme.displayLarge,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                      color: AppColors2.textblack,
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
    return Scaffold(
      backgroundColor: AppColors2.primary,
      drawerEnableOpenDragGesture: false,



      appBar: AppBar(
        backgroundColor: AppColors2.primary,
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(
          color: AppColors2.textblack
        ),
        title: Column(
          children: [
            _buildAppBar(),
          ],
        ),
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
                  color: AppColors2.textblack,
                )),
          )

          // Container(child: Icon(Icons.ice_skating)),
        ],
      ),
      body: _screens[_selectedIndex], // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.red.shade900,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
          showSelectedLabels: true,  // ✅ Ensures selected labels are always visible
          showUnselectedLabels: true, // ✅ Ensures unselected labels are also visible
          type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        items:  <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: AppStrings.homeLabel,
            backgroundColor: AppColors2.primary,
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock),
            label: AppStrings.attendanceLabel,
            backgroundColor: AppColors2.primary,
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book_fill),
            label: AppStrings.libraryLabel,
            backgroundColor: AppColors2.primary,

          ),

          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_alt_circle_fill),
            label: AppStrings.profileLabel,
            backgroundColor: AppColors2.primary,
          ),
        ],
      ),
      drawer: Drawer(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        width: MediaQuery.sizeOf(context).width * .65,
        // backgroundColor: Theme.of(context).colorScheme.background,
        backgroundColor: AppColors2.primary,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 70,
              ),

              GestureDetector(
                onTap: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return ProfileScreen(appBar: 'appbar');
                      },
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: teacherData != null && teacherData?['photo'] != null
                      ? Image.network(
                    teacherData?['photo'],
                    height: 100.sp,
                    width: 100.sp,
                
                  )
                      : Image.asset(
                    AppAssets.cjmlogo,
                    height: 80.sp,
                    width: 80.sp,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  child: Padding(
                    padding: EdgeInsets.only(top: 0, bottom: 3.sp),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${teacherData?['first_name']??'Teacher'} ${teacherData?['last_name']??''}' ?? 'Teacher', // Fallback to 'Student' if null
                        style: GoogleFonts.montserrat(
                          textStyle: Theme.of(context).textTheme.displayLarge,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors2.textblack,
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
                        teacherData?['email'] ?? '',
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
                                    color:AppColors2.textblack,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            trailing: Container(
                              height: 20,
                              width: 20,
                              color: AppColors2.primary,
                              child:Icon(Icons.dashboard,color:AppColors2.textblack,),


              ),
                            onTap: () {
                              Navigator.pop(context);

                             
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
                              'Students Profile',
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
                              child: Icon(CupertinoIcons.person_2_alt,color:AppColors2.textblack,),

                            ),
                            onTap: () {
                              Navigator.pop(context);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return  AllStudents();
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
                              'Class Teachers',
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
                              child: Icon(CupertinoIcons.person_2,color:AppColors2.textblack,),

                            ),
                            onTap: () {

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return  ClassTeacher();
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
                              'Staff List',
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
                              child: Icon(CupertinoIcons.person_2,color:AppColors2.textblack,),

                            ),
                            onTap: () {

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return  TeachingStaff();
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
                              'Attendance',
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
                              child: Icon(CupertinoIcons.clock,color:AppColors2.textblack,),

                            ),
                            onTap: () {
                              Navigator.pop(context);

                              // Navigate to the Profile screen in the BottomNavigationBar
                              setState(() {
                                _selectedIndex = 1; // Index of the Profile screen in _screens
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
                              'Assignments',
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
                              child:  Image.asset(
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
                              'Time Table',
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
                              child:  Image.asset(
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
                                    return TimeTableTeacherScreen();
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
                                    return  TeacherMesssageListScreen(messageSendPermissionsApp: messageSendPermissionsApp,);
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
                                    return const CalendarScreen(
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
                              'E Books',
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
                              'Photo Gallery',
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
                              child:  Image.asset(
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
                              'Logout',
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
                                child: Icon(
                                  Icons.logout,
                                  color:AppColors2.textblack,
                                )),
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.clear(); // Clear the stored token
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginPage()),
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
              )

            ],
          ),
        ),
      ),

    );
  }
}

