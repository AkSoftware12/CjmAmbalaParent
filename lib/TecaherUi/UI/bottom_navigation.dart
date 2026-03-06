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
import '../../UI/LogoutUserList/logout_user_list.dart';
import '../../UI/Notice/notice.dart';
import '../../UI/TransactionLibrary/transaction_library.dart';
import '../../UI/Videos/video_screen.dart';
import '../../constants.dart';
import '../../strings.dart';
import '../UI/Dashboard/HomeScreen%20.dart';
import 'AdminTimeTable/admin_time_table.dart';
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
import 'SalarySlip/salary_slip.dart';
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

  int? messageCount;
  int? feesCount;
  int? assignmentCount;
  int? galleryCount;
  int? achivementCount;
  int? videoCount;
  int? noticeCount;
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
          messageCount = _toInt(data['message_count']);
          assignmentCount = _toInt(data['assignment_count']);
          feesCount = _toInt(data['fee_count']);

          // ✅ if API has gallery_count then use it, else keep previous or 0
          galleryCount = data.containsKey('photo_count')
              ? _toInt(data['photo_count'])
              : (galleryCount ?? 0);
          achivementCount = data.containsKey('achivement_count')
              ? _toInt(data['achivement_count'])
              : (achivementCount ?? 0);
          videoCount = data.containsKey('video_count')
              ? _toInt(data['video_count'])
              : (videoCount ?? 0);
          noticeCount = data.containsKey('notice')
              ? _toInt(data['notice'])
              : (noticeCount ?? 0);
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
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
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
  Future<void> _refreshCounts() async {
    if (!mounted) return;
    await fetchData();
  }

  // ✅✅✅ BADGE widget
  Widget _menuBadge(dynamic raw) {
    int count = 0;
    String? label;

    if (raw is int) {
      count = raw;
    } else if (raw is String && int.tryParse(raw) != null) {
      count = int.parse(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      label = raw.toUpperCase(); // DUE
    }

    final show = (count > 0) || (label != null);
    if (!show) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 6)
        ],
      ),
      child: Text(
        label ?? "$count",
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  // ✅ Drawer tile builder (badge + icon)
  Widget _drawerTile({
    required String title,
    dynamic badgeValue, // int or "DUE"
    required Widget iconBox,
    required Future<void> Function() onTap,
    Color titleColor = Colors.white,
  }) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.cabin(
          textStyle: TextStyle(
            color: titleColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _menuBadge(badgeValue),
          const SizedBox(width: 8),
          iconBox,
        ],
      ),
      onTap: () async => await onTap(),
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
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationScreen()),
                );
                if (!mounted) return;
                await _refreshCounts(); // refresh after back
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications_active,
                    size: 26,
                    color: Colors.white,
                  ),

                  // 🔴 BADGE
                  if ((noticeCount ?? 0) > 0)
                    Positioned(
                      right: -6,
                      top: -10,
                      child: Container(
                        width: 15.sp,
                        height: 15.sp,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                            )
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          noticeCount! > 99 ? "99+" : "$noticeCount",
                          style:  TextStyle(
                            color: Colors.red,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )

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
                          if (int.tryParse(teacherData?['role_manual'].toString() ?? '')== 2)
                            ListTile(
                              title: Text(
                                'Salary Slip',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: AppColors2.textblack,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors2.primary,
                                child: Icon(Icons.currency_rupee,color: Colors.white,),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SalaryScreen(),
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
                              final role = int.tryParse(teacherData?['role_manual'].toString() ?? '') ?? 0;

                              if (role == 2) {
                                // ✅ AdminTimeTable open
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminTimeTableTabScreen(),
                                  ),
                                );
                              } else {
                                // ✅ TimeTable (Teacher) open
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TimeTableTeacherScreen(),
                                  ),
                                );
                              }
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
                          _drawerTile(
                            title: 'Notice',
                            badgeValue: noticeCount ?? 0,
                            iconBox: Container(
                              height: 20,
                              width: 20,
                              color: AppColors.primary,
                              child:  Icon(CupertinoIcons.bell,
                                  color: Colors.white, size: 20.sp),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => NoticeScreen()),
                              );
                              if (!mounted) return;
                              await _refreshCounts();
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

                          _drawerTile(
                            title: 'Messages',
                            badgeValue: messageCount ?? 0,
                            iconBox: Container(
                              height: 20,
                              width: 20,
                              color: AppColors.primary,
                              child: Image.asset('assets/message_home.png'),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await  Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return  TeacherMesssageListScreen(messageSendPermissionsApp: messageSendPermissionsApp,);
                                  },
                                ),
                              );
                              if (!mounted) return;
                              await _refreshCounts();
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
                          _drawerTile(
                            title: 'Photo Gallery',
                            badgeValue: galleryCount ?? 0,
                            iconBox: Container(
                              height: 20,
                              width: 20,
                              color: AppColors.primary,
                              child: Image.asset('assets/gallery.png'),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => GalleryScreen()),
                              );
                              if (!mounted) return;
                              await _refreshCounts();
                            },
                          ),                          Padding(
                            padding:
                            EdgeInsets.only(left: 8, right: 8),
                            child: Divider(
                              height: 1,
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),

                          _drawerTile(
                            title: 'Video Gallery',
                            badgeValue: videoCount ?? 0,

                            iconBox: Container(
                              height: 20,
                              width: 20,
                              color: AppColors.primary,
                              child: const Icon(CupertinoIcons.video_camera,
                                  color: Colors.white, size: 18),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => VideoGallery()),
                              );
                              if (!mounted) return;
                              await _refreshCounts();
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

                          _drawerTile(
                            title: 'Achievement Gallery',
                            badgeValue: achivementCount ?? 0,
                            iconBox: Container(
                              height: 20,
                              width: 20,
                              color: AppColors.primary,
                              child: const Icon(CupertinoIcons.rosette,
                                  color: Colors.white, size: 18),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        AchievementsWaveScreen()),
                              );
                              if (!mounted) return;
                              await _refreshCounts();
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>  LogoutUserList(),
                                ),
                              );
                              // final prefs = await SharedPreferences.getInstance();
                              // await prefs.clear(); // Clear the stored token
                              // Navigator.pushReplacement(
                              //   context,
                              //   MaterialPageRoute(builder: (context) => const LoginPage()),
                              // );
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

