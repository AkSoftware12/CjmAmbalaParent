import 'package:avi/NewUserBottombarPage/new_user_profile_page.dart';
import 'package:avi/NewUserBottombarPage/new_user_payment_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import '../UI/Auth/login_screen.dart';
import '../UI/Auth/login_student_userlist.dart';
import 'documents.dart';
import '../UI/Gallery/gallery_tab.dart';
import '../utils/upgrader_config.dart';
import '../UI/Gallery/Album/album.dart';
import '../constants.dart';
import '../strings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'message_main.dart';
import 'message_psge.dart';



class NewUserBottombarPage extends StatefulWidget {

  const NewUserBottombarPage({super.key,});
  @override
  _BottomNavBarScreenState createState() => _BottomNavBarScreenState();
}

class _BottomNavBarScreenState extends State<NewUserBottombarPage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? studentData;
  bool isLoading = true;
  String currentVersion = '';


  // List of screens
  final List<Widget> _screens = [

    MessageMainScreen(),
    MessageListScreen(appbar: 'AppBar',),
    NewUserPaymentScreen(),
    DocumentsScreen(),
    NewUserProfileScreen(),
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
    fetchStudentData();

  }



  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('newusertoken');
    print("token: $token");

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfileNewUser),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        studentData = data['student'];
        isLoading = false;
        print(studentData);

      });
    } else {
    }
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
                      '${studentData?['name'].toString() ?? ' Student'}',
                      style: GoogleFonts.montserrat(
                        textStyle: Theme.of(context).textTheme.displayLarge,
                        fontSize: 12.sp,
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
      ),
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
          title: Column(children: [
            _buildAppBar(),
            Divider(
              thickness: 2,
              color: Colors.red.shade900,
            )
          ]),
          actions: [
            // Padding(
            //   padding: const EdgeInsets.all(15.0),
            //   child: GestureDetector(
            //     onTap: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) {
            //             return NotificationScreen();
            //           },
            //         ),
            //       );
            //     },
            //     child: Icon(
            //       Icons.notification_add,
            //       size: 26,
            //       color: Colors.white,
            //     ),
            //   ),
            // ),

            // Container(child: Icon(Icons.ice_skating)),
          ],
        ),



        body: _screens[_selectedIndex], // Display the selected screen
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.red.shade900,
          selectedItemColor: Colors.white,
          unselectedItemColor: AppColors.grey,
          showSelectedLabels: true,  // ✅ Ensures selected labels are always visible
          showUnselectedLabels: true, // ✅ Ensures unselected labels are also visible
          type: BottomNavigationBarType.fixed,
          items:  <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard),
              label:'DashBoard',
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chat_bubble_text),
              label:'Messages',
              backgroundColor: AppColors.primary,
            ),

            BottomNavigationBarItem(
              icon: Icon(Icons.currency_rupee),
              label: AppStrings.feesLabel,
              backgroundColor: AppColors.primary,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.picture_as_pdf),
              label: 'Documents',
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

                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage:
                    (studentData != null &&
                        studentData?['picture_data'] != null &&
                        studentData!['picture_data'].toString().isNotEmpty &&
                        !studentData!['picture_data'].toString().endsWith(
                          "null",
                        ))
                        ? NetworkImage(studentData!['picture_data'])
                        : null,
                    child:
                    (studentData == null ||
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
                          studentData?['name'] ?? 'Student',
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
                                  _selectedIndex = 0; // BottomNavigation ka index 0 pe set karega
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
                                'Messages ',
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
                                  Icons.chat,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context); // Drawer close karega
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        MessageListScreen(appbar: '',),
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
                                'Gallery',
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
                                  Icons.photo_album_outlined,
                                  color: Colors.white,
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
                                child: Icon(
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
}

