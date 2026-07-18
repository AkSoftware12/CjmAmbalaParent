import 'package:avi/NewUserBottombarPage/new_user_profile_page.dart';
import 'package:avi/NewUserBottombarPage/new_user_payment_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../TecaherUi/UI/Notice/notice.dart';
import '../TecaherUi/UI/Notification/notification.dart';
import '../UI/Achievements/achievements.dart';
import '../UI/Auth/login_screen.dart';
import '../UI/Auth/login_student_userlist.dart';
import '../UI/EbooksScreen/Ebooks/ebooks.dart';
import '../UI/MagazineScreen/Magzine/magzine.dart';
import '../UI/Notice/notice.dart';
import '../UI/Videos/video_screen.dart';
import '../VacanciesScreen/vacancies_screen.dart';
import '../splash_sreen.dart';
import '../UI/Gallery/Album/album.dart';
import '../constants.dart';
import '../strings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'alumni_chat_screen.dart';
import 'alumni_counts_provider.dart';
import 'alumni_dashbord.dart';
import 'alumni_notice.dart';
import 'alumni_user_profile_page.dart';

class AlumniUserBottombarPage extends ConsumerStatefulWidget {
  const AlumniUserBottombarPage({super.key});

  @override
  ConsumerState<AlumniUserBottombarPage> createState() =>
      _BottomNavBarScreenState();
}

class _BottomNavBarScreenState extends ConsumerState<AlumniUserBottombarPage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? studentData;
  bool isLoading = true;
  String currentVersion = '';
  String release = "";
  bool _upgradeDialogShown = false;

  // List of screens
  final List<Widget> _screens = [
    const AlumniDashBoard(),
    const AlumniStudentChatScreen(),
    const AlumniUserProfileScreen(),
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

    // ✅ Counts ab shared provider se aate hain — provider khud
    // pehli baar fetch kar leta hai, yahan alag fetch ki zaroorat nahi.

    fetchStudentData();

    final newVersion = NewVersionPlus(
      iOSId: '6752724101',
      iOSAppStoreCountry: 'IN',
      androidId: 'com.avisunavi.avi',
      androidPlayStoreCountry: "in",
      androidHtmlReleaseNotes: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      advancedStatusCheck(newVersion); // ✅ now context is ready
    });
  }

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumniToken');
    print("token: $token");

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfileAlumniUser),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        studentData = data['alumni'];
        isLoading = false;
        print(studentData);
      });
    } else {}
  }

  Future<void> checkForVersion(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
  }

  Widget _buildAppBar() {
    return Container(
      child: Row(
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
                style: GoogleFonts.poppins(
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.normal,
                  color: AppColors.textwhite,
                ),
              ),
              SizedBox(
                height: 2.sp,
              ),
              Text(
                '${studentData?['full_name'].toString() ?? ' Student'}',
                style: GoogleFonts.poppins(
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  color: AppColors.textwhite,
                ),
              ),
            ],
          ),
        ],
      ),
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
          return PopScope(
            // ✅ WillPopScope new replacement (Flutter 3.13+)
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

  // ✅ Ab refresh sirf provider ko bolta hai — dono screens update ho jaati hain
  Future<void> _refreshCounts() async {
    await ref.read(alumniCountsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Shared counts — dashboard bhi yahi provider watch karta hai
    final counts = ref.watch(alumniCountsProvider);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        drawerEnableOpenDragGesture: false,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          automaticallyImplyLeading: false,
          iconTheme: IconThemeData(color: AppColors.textwhite),
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
                    MaterialPageRoute(
                      builder: (context) => AlumniNoticeScreen(),
                    ),
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
                    if (counts.notice > 0)
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
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            counts.notice > 99 ? "99+" : "${counts.notice}",
                            style: TextStyle(
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
            ),
          ],
        ),
        body: _screens[_selectedIndex], // Display the selected screen
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.red.shade700,
          selectedItemColor: Colors.white,
          unselectedItemColor: AppColors.grey,
          selectedLabelStyle:
          TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp),
          unselectedLabelStyle:
          TextStyle(fontWeight: FontWeight.w500, fontSize: 11.sp),
          showSelectedLabels:
          true, // ✅ Ensures selected labels are always visible
          showUnselectedLabels:
          true, // ✅ Ensures unselected labels are also visible
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard),
              label: 'DashBoard',
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chat_bubble_text),
              label: 'Messages',
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
          backgroundColor: AppColors.secondary,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 70),
                GestureDetector(
                  onTap: () {},
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: (studentData != null &&
                        studentData?['picture_data'] != null &&
                        studentData!['picture_data']
                            .toString()
                            .isNotEmpty &&
                        !studentData!['picture_data'].toString().endsWith(
                          "null",
                        ))
                        ? NetworkImage(studentData!['picture_data'])
                        : null,
                    child: (studentData == null ||
                        studentData?['picture_data'] == null ||
                        studentData!['picture_data'].toString().isEmpty)
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
                          studentData?['full_name'] ?? 'Student',
                          style: GoogleFonts.montserrat(
                            textStyle: Theme.of(context).textTheme.displayLarge,
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
                          style: GoogleFonts.montserrat(
                            textStyle: Theme.of(context).textTheme.displayLarge,
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
                  thickness: 2.0,
                  height: 1,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(5.sp),
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
                                    fontSize: 15.sp,
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
                                Navigator.pop(context); // Drawer close karega
                                setState(() {
                                  _selectedIndex = 0;
                                });
                              },
                            ),
                            _divider(),

                            // ✅ Notice
                            _drawerTile(
                              title: 'Notice',
                              badgeValue: counts.notice,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(
                                  CupertinoIcons.bell,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AlumniNoticeScreen(),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Messages (BADGE)
                            _drawerTile(
                              title: 'Messages',
                              badgeValue: counts.message,
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
                                    builder: (context) =>
                                        AlumniStudentChatScreen(),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
                              },
                            ),
                            _divider(),

                            _drawerTile(
                              title: 'Vacancies',
                              badgeValue: counts.vacancies,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: Icon(
                                  CupertinoIcons.briefcase_fill,
                                  color: Colors.white,
                                  size: 20.sp,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VacanciesScreen(),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Photo Gallery
                            _drawerTile(
                              title: 'Photo Gallery',
                              badgeValue: counts.gallery,
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
                                    builder: (context) => GalleryScreen(),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
                              },
                            ),
                            _divider(),

                            // ✅ Video Gallery
                            _drawerTile(
                              title: 'Video Gallery',
                              badgeValue: counts.video,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(
                                  CupertinoIcons.video_camera,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoGallery(),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
                              },
                            ),
                            _divider(),

                            _drawerTile(
                              title: 'Magazines',
                              badgeValue: 0,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(
                                  CupertinoIcons.news_solid,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const MagazineScreen(),
                                  ),
                                );
                              },
                            ),
                            _divider(),

                            // ✅ Achievement Gallery
                            _drawerTile(
                              title: 'Achievement Gallery',
                              badgeValue: counts.achievement,
                              iconBox: Container(
                                height: 20,
                                width: 20,
                                color: AppColors.primary,
                                child: const Icon(
                                  CupertinoIcons.rosette,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AchievementsWaveScreen(),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshCounts();
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
                                    builder: (context) => EbooksScreen(),
                                  ),
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
                            ListTile(
                              title: Text(
                                'Logout',
                                style: GoogleFonts.cabin(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                height: 20,
                                width: 20,
                                child: Icon(Icons.logout, color: Colors.white),
                              ),
                              onTap: () async {
                                final prefs =
                                await SharedPreferences.getInstance();
                                await prefs.clear(); // Clear the stored token
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
                    ],
                  ),
                ),
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
                Padding(padding: EdgeInsets.only(bottom: 15.sp)),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 6),
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
        children: [_menuBadge(badgeValue), const SizedBox(width: 8), iconBox],
      ),
      onTap: () async => await onTap(),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.only(left: 8, right: 8),
    child: Divider(height: 1, color: Colors.grey.shade300, thickness: 1),
  );
}