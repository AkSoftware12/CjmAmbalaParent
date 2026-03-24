import 'dart:convert';
import 'package:avi/UI/Notification/notification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../TecaherUi/UI/BirthdayScreen/birthday_screen.dart';
import '../UI/Dashboard/HomeScreen .dart';
import '../constants.dart';
import '../splash_sreen.dart';
import '../strings.dart';
import 'Achievements/achievements.dart';
import 'Assignment/assignment.dart';
import 'Attendance/AttendanceScreen.dart';
import 'Auth/login_screen.dart';
import 'Auth/login_student_userlist.dart';
import 'EbooksScreen/Ebooks/ebooks.dart' hide ApiRoutes;
import 'Fees/FeesScreen.dart';
import 'Gallery/Album/album.dart' show GalleryScreen;
import 'Help/help.dart';
import 'KnowYourTeacher/know_your_teacher.dart';
import 'Library/LibraryScreen.dart';
import 'LogoutUserList/logout_user_list.dart';
import 'Message/message.dart';
import 'ActivityCalendar/activity_calendar.dart';
import 'Notice/notice.dart';
import 'Profile/ProfileScreen.dart';
import 'TimeTable/time_table.dart';
import 'TransactionLibrary/transaction_library.dart';
import 'Videos/video_screen.dart';

class BottomNavBarScreen extends StatefulWidget {
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

  // String currentVersion = '';
  String release = "";
  bool _upgradeDialogShown = false;

  int? messageViewPermissionsApp;
  int? messageSendPermissionsApp;

  // ✅✅✅ COUNTS for drawer badges
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
    AttendanceCalendarScreen(title: 'Attendance'),
    LibraryScreen(appBar: ''),
    CalendarScreen(title: ''),
    ProfileScreen(appBar: ''),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    checkForVersion(context);
    _selectedIndex = widget.initialIndex;

    fetchData(); // ✅ dashboard (permissions + counts)
    fetchStudentData();

    final newVersion = NewVersionPlus(
      iOSId: 'com.avisunavi.avi',
      androidId: 'com.avisunavi.avi',
      androidPlayStoreCountry: "in",
      androidHtmlReleaseNotes: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      advancedStatusCheck(newVersion); // ✅ now context is ready
    });
  }

  // Future<void> checkForVersion(BuildContext context) async {
  //   PackageInfo packageInfo = await PackageInfo.fromPlatform();
  //   setState(() => currentVersion = packageInfo.version);
  // }

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
          photoUrl = null;
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

  // ✅✅✅ DASHBOARD API (permissions + counts)
  Future<void> fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse(ApiRoutes.getDashboard);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(decoded['data'] ?? {});

        final permissions = (data['permisions'] ?? []) as List;

        setState(() {
          // ✅ permissions safe parsing
          messageViewPermissionsApp = (permissions.isNotEmpty
              ? (permissions[0]['app_status'] as num?)?.toInt()
              : 0) ??
              0;

          messageSendPermissionsApp = (permissions.length > 1
              ? (permissions[1]['app_status'] as num?)?.toInt()
              : 0) ??
              0;

          // ✅ counts (safe)
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
      }
    } catch (e) {
      debugPrint('Error fetching dashboard: $e');
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  // ✅ used for "DUE" type label in badge
  dynamic get _feesBadgeValue => ((feesCount ?? 0) > 0 ? "DUE" : 0);

  Future<void> _refreshCounts() async {
    if (!mounted) return;
    await fetchData();
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
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: SizedBox(
              height: 30,
              width: 30,
              child: Image.asset('assets/menu.png'),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome !',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textwhite,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginUserLIst()),
                ).then((_) => _refreshCounts()); // ✅ optional refresh
              },
              child: Row(
                children: [
                  Text(
                    '${studentData?['student_name'].toString() ?? ' Student'}',
                    style: GoogleFonts.montserrat(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textwhite,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }



  basicStatusCheck(NewVersionPlus newVersion) async {
    final version = await newVersion.getVersionStatus();
    if (version != null) {
      release = version.releaseNotes ?? "";
      setState(() {});
    }
    newVersion.showAlertIfNecessary(
      context: context,
      launchModeVersion: LaunchModeVersion.external,
    );
  }

  Future<void> advancedStatusCheck(NewVersionPlus newVersion) async {
    try {
      final status = await newVersion.getVersionStatus();
      if (status == null) return;

      debugPrint("releaseNotes: ${status.releaseNotes}");
      debugPrint("appStoreLink: ${status.appStoreLink}");
      debugPrint("localVersion: ${status.localVersion}");
      debugPrint("storeVersion: ${status.storeVersion}");
      debugPrint("canUpdate: ${status.canUpdate}");

      if (!status.canUpdate) return;
      if (_upgradeDialogShown) return;
      if (!mounted) return;

      _upgradeDialogShown = true;

      showDialog(
        context: context, // ✅ yahi best hai
        barrierDismissible: false,
        builder: (dialogCtx) {
          return PopScope( // ✅ WillPopScope new replacement (Flutter 3.13+)
            canPop: false,
            onPopInvoked: (didPop) {
              SystemNavigator.pop();
            },
            child: CustomUpgradeDialog(
              currentVersion: status.localVersion,
              newVersion: status.storeVersion,
              releaseNotes: [
                (status.releaseNotes ?? "").trim().isEmpty
                    ? "New update available."
                    : status.releaseNotes!.trim(),
              ],
            ),
          );
        },
      );
    } catch (e, st) {
      debugPrint("advancedStatusCheck error: $e");
      debugPrint("$st");
    }
  }
  Future<void> checkForVersion(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        drawerEnableOpenDragGesture: false,

        // ✅ drawer open होते ही count refresh
        onDrawerChanged: (isOpen) {
          if (isOpen) _refreshCounts();
        },

        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          automaticallyImplyLeading: false,
          iconTheme: IconThemeData(color: AppColors.textwhite),
          title: Column(children: [_buildAppBar()]),
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

        body: _screens[_selectedIndex],

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.red.shade900,
          selectedItemColor: AppColors.textwhite,
          unselectedItemColor: AppColors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.home),
              label: AppStrings.homeLabel,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.clock),
              label: AppStrings.attendanceLabel,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.book_fill),
              label: AppStrings.libraryLabel,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month),
              label: AppStrings.activity,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.person_alt_circle_fill),
              label: AppStrings.profileLabel,
              backgroundColor: AppColors.primary,
            ),
          ],
        ),

        drawer: Drawer(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          width: MediaQuery.sizeOf(context).width * .65,
          backgroundColor: AppColors.secondary,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 70),

                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(appBar: 'appbar'),
                      ),
                    );
                    if (!mounted) return;
                    await _refreshCounts();
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: (studentData != null &&
                        studentData?['photo'] != null &&
                        studentData!['photo'].toString().isNotEmpty &&
                        !studentData!['photo']
                            .toString()
                            .endsWith("null"))
                        ? NetworkImage(studentData!['photo'])
                        : null,
                    child: (studentData == null ||
                        studentData?['photo'] == null ||
                        studentData!['photo'].toString().isEmpty)
                        ? const Icon(Icons.account_circle, size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  studentData?['student_name'] ?? 'Student',
                  style: GoogleFonts.montserrat(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textwhite,
                  ),
                ),
                Text(
                  studentData?['email'] ?? '',
                  style: GoogleFonts.montserrat(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textwhite,
                  ),
                ),

                Divider(
                  color: Colors.grey.shade300,
                  thickness: 2.0,
                  height: 20,
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ Dashboard
                            _drawerTile(
                              title: 'Dashboard',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(Icons.dashboard,
                                    color: Colors.white, size: 18),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                setState(() => _selectedIndex = 0);
                                // await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Attendance
                            _drawerTile(
                              title: 'Attendance',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(CupertinoIcons.clock,
                                    color: Colors.white, size: 18),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                setState(() => _selectedIndex = 1);
                              },
                            ),
                            _divider(),

                            // ✅ Notice
                            _drawerTile(
                              title: 'Notice',
                              badgeValue: noticeCount ?? 0,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(CupertinoIcons.bell,
                                    color: Colors.white, size: 18),
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
                            _divider(),

                            // ✅ Birthday List (kept as you had with AppColors2)
                            ListTile(
                              title: Text(
                                'Birthday List',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                      color: AppColors2.textblack,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                color: AppColors2.primary,
                                child: Icon(CupertinoIcons.gift,
                                    color: AppColors2.textblack, size: 18),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => BirthdayScreen()),
                                );
                                // if (!mounted) return;
                                // await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ My Profile
                            _drawerTile(
                              title: 'My Profile',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(CupertinoIcons.person,
                                    color: Colors.white, size: 18),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          ProfileScreen(appBar: 'app')),
                                );
                                // if (!mounted) return;
                                // await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Know Your Teacher
                            _drawerTile(
                              title: 'Know Your Teacher',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(CupertinoIcons.person_2_alt,
                                    color: Colors.white, size: 18),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          TeacherListPremiumScreen()),
                                );
                                // if (!mounted) return;
                                // await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Library Transaction
                            _drawerTile(
                              title: 'Library Transaction',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(CupertinoIcons.creditcard,
                                    color: Colors.white, size: 18),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          IssuedBooksScreen()),
                                );
                                // if (!mounted) return;
                                // await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Assignments (BADGE)
                            _drawerTile(
                              title: 'Assignments',
                              badgeValue: assignmentCount ?? 0,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset('assets/assignments.png'),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          AssignmentListScreen()),
                                );
                                if (!mounted) return;
                                await _refreshCounts(); // ✅ back aate hi refresh
                              },
                            ),
                            _divider(),

                            // ✅ Fees (DUE badge)
                            _drawerTile(
                              title: 'Fees',
                              badgeValue: _feesBadgeValue,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(Icons.currency_rupee,
                                    color: Colors.white, size: 18),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          FeesScreen(title: 'aa')),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Time Table
                            _drawerTile(
                              title: 'Time Table',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset('assets/watch.png'),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => TimeTableScreen()),
                                );
                              },
                            ),
                            _divider(),

                            // ✅ Messages (BADGE)
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
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MesssageListScreen(
                                      messageSendPermissionsApp:
                                      messageSendPermissionsApp,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Photo Gallery (BADGE if you have galleryCount else 0)
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
                            ),
                            _divider(),

                            // ✅ Video Gallery
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
                              },
                            ),
                            _divider(),

                            // ✅ Achievement Gallery
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
                              },
                            ),
                            _divider(),

                            // ✅ E Books
                            _drawerTile(
                              title: 'E Books',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset('assets/ebook.png'),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => EbooksScreen()),
                                );
                              },
                            ),
                            _divider(),

                            // ✅ Activity Calendar
                            _drawerTile(
                              title: 'Activity Calendar',
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Image.asset('assets/document.png'),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CalendarScreen(
                                      title: 'Activity Calendar',
                                    ),
                                  ),
                                );
                              },
                            ),
                            _divider(),

                            // ✅ Help
                            _drawerTile(
                              title: 'Help',
                              iconBox: SizedBox(
                                height: 25,
                                width: 25,
                                child: Image.asset(
                                  'assets/help.png',
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        HelpScreen(appBar: 'Help'),
                                  ),
                                );
                              },
                            ),
                            _divider(),

                            // ✅ Logout
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
                              trailing: const Icon(Icons.logout,
                                  color: Colors.white, size: 20),
                              onTap: () async {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>  LogoutUserList(),
                                  ),
                                );
                                // final prefs =
                                // await SharedPreferences.getInstance();
                                // await prefs.clear();
                                // Navigator.pushReplacement(
                                //   context,
                                //   MaterialPageRoute(
                                //       builder: (context) => const LoginPage()),
                                // );
                              },
                            ),

                            SizedBox(height: 12.sp),
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
                            SizedBox(height: 18.sp),
                          ],
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

  Widget _divider() => Padding(
    padding: const EdgeInsets.only(left: 8, right: 8),
    child: Divider(
      height: 1,
      color: Colors.grey.shade300,
      thickness: 1,
    ),
  );
}