import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
import '../../../UI/Library/LibraryScreen.dart';
import '../../../constants.dart';
import '../Assignment/assignment.dart';
import '../HomeWork/home_work.dart';
import '../Notice/notice.dart';
import '../Subject/subject.dart';
import '../TeacherMessage/message.dart';
import '../TimeTable/time_table_teacher.dart';
import '../bottom_navigation.dart';

// API Service
class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );




  Future<List<dynamic>> fetchDashboardData(String token) async {
    final url = Uri.parse(ApiRoutes.getBirthdays);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        final students = responseData['data']['today_student_birthdays'] ?? [];
        final teachers = responseData['data']['today_teacher_birthdays'] ?? [];

        return [...students, ...teachers]; // 👈 merge
      } else {
        throw Exception("Failed to load data");
      }
    } catch (e) {
      throw Exception('Error fetching dashboard data: $e');
    }
  }
}

class DashboardData {
  final List<dynamic> assignments;

  DashboardData(this.assignments);
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final dashboardDataProvider =
StateNotifierProvider<DashboardDataNotifier, AsyncValue<DashboardData>>(
      (ref) => DashboardDataNotifier(ref.read(apiServiceProvider)),
);

class DashboardDataNotifier extends StateNotifier<AsyncValue<DashboardData>> {
  final ApiService _apiService;

  DashboardDataNotifier(this._apiService) : super(const AsyncValue.loading()) {
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    try {
      state = const AsyncValue.loading();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');
      if (token == null) {
        state = AsyncValue.error(
          Exception('No token found'),
          StackTrace.current,
        );
        return;
      }
      final assignments = await _apiService.fetchDashboardData(token);
      state = AsyncValue.data(DashboardData(assignments));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}



class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? teacherData;
  List assignments = []; // Declare a list to hold API data
  List<dynamic> banners = [];

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
    {
      'name': 'Library',
      'image': 'assets/booksimg.png',
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
    fetchBannerData();
    // fetchDasboardData();
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
          banners = data['banners'] ?? [];

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
  Future<void> fetchBannerData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse(ApiRoutes.getBanner);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];

        setState(() {
          banners = data['banners'] ?? [];
          //
          // /// ✅ permissions
          // messageViewPermissionsApp =
          //     (data['permisions']?[0]['app_status'] as num?)?.toInt() ?? 0;
          //
          // messageSendPermissionsApp =
          //     (data['permisions']?[1]['app_status'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors2.primary,
      body: isLoading
          ? const Center(
              child: CupertinoActivityIndicator(radius: 20),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CarouselExample(banners: banners,),
                  SizedBox(height: 10),

                  _buildsellAll('Category', ''),

                  _buildGridview(),
                  const SizedBox(height: 10),

                  _buildSectionTitle('Teachers & Students Birthday', ''),
                  BirthdayCard(),
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


  Widget _buildSectionTitle(String title, String see) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 6.sp),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          /// 🔥 Title Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: MediaQuery.of(context).size.width * 0.042,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textwhite,
                  letterSpacing: 0.5,
                ),
              ),

              /// 🔻 Accent line
              Container(
                margin: EdgeInsets.only(top: 4.sp),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),


        ],
      ),
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


              }else if (items[index]['name'] == 'Library') {

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: Duration(milliseconds: 500), // Animation Speed
                    pageBuilder: (context, animation, secondaryAnimation) => LibraryScreen(appBar: '25',),
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

              else if (items[index]['name'] == 'Subject') {

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
                        height: 10,
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
class BirthdayCard extends ConsumerStatefulWidget {
  const BirthdayCard({super.key});

  @override
  ConsumerState<BirthdayCard> createState() => _BirthdayCardState();
}

class _BirthdayCardState extends ConsumerState<BirthdayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;
  late ConfettiController _confettiController;

  int currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 8),
    );

    _startConfettiLoop();
    _controller.forward();
  }

  void _startConfettiLoop() {
    _confettiController.play();

    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;

      // ✅ safe list length check
      final st = ref.read(dashboardDataProvider);
      final list = st.value?.assignments ?? [];
      if (list.isEmpty) return;

      _controller.reverse().then((_) {
        if (!mounted) return;

        setState(() {
          currentIndex = (currentIndex + 1) % list.length;
        });

        _controller.forward();
        _confettiController.play();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardDataProvider);

    return dashboardState.when(
      data: (data) {
        final birthdayList = data.assignments;

        if (birthdayList.isEmpty) {
          return const NoBirthdaysToday();
        }

        if (currentIndex >= birthdayList.length) currentIndex = 0;

        final item = birthdayList[currentIndex] as Map<String, dynamic>;

        // ✅ student item me "student" key hoti hai
        final bool isStudent =
            item.containsKey('student') && item['student'] != null;

        String name = '';
        String imageUrl = '';
        String roleText = '';

        if (isStudent) {
          final s = (item['student'] as Map<String, dynamic>);
          final academicClass = (item['academic_class'] as Map<String, dynamic>);
          final section = (item['section'] as Map<String, dynamic>);
          name = '${(s['student_name'] ?? '').toString()}\n(${academicClass['title'] }(${section['title'] }))';
          imageUrl = (s['picture_data'] ?? '').toString();
          roleText = 'Student';

        } else {
          // ✅ teacher item direct object hai
          name = (item['first_name'] ?? '').toString();
          imageUrl = (item['photo'] ?? '').toString(); // ✅ teacher photo
          roleText = (item['designation']?['title'] ?? 'Teacher').toString();
        }

        return Padding(
          padding: EdgeInsets.all(10.sp),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.sp),
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('assets/backg.jpg'),
                        fit: BoxFit.cover,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#191970').withOpacity(0.9),
                          HexColor('#191970').withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.4),
                          spreadRadius: 4,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ✅ IMAGE
                        Container(
                          height: 130.sp,
                          width: 130.sp,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: ScaleTransition(
                            scale: _fadeAnimation,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20.r),
                              child: (imageUrl.isNotEmpty)
                                  ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.fill,
                                errorWidget: (context, url, error) =>
                                    Icon(
                                      Icons.cake,
                                      size: 60.sp,
                                      color: Colors.orangeAccent,
                                    ),
                              )
                                  : Container(
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: Icon(
                                  isStudent ? Icons.school : Icons.badge,
                                  size: 60.sp,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 6.sp),

                        SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            'Happy Birthday!',
                            style: GoogleFonts.poppins(
                              fontSize: 22.sp,
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,

                            ),
                          ),
                        ),

                        SizedBox(height: 6.sp),

                        SlideTransition(
                          position: _slideAnimation,
                          child: Center(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 18.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 8.sp),

                        // ✅ ROLE / DESIGNATION CHIP
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.sp,
                            vertical: 5.sp,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.25),
                            borderRadius: BorderRadius.circular(50.r),
                          ),
                          child: Text(
                            roleText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ overlay image (optional)
                  Image.asset('assets/birthday.png', fit: BoxFit.fill),
                ],
              ),

              // ✅ CONFETTI
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: -pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 2,
                gravity: 0.0,
                colors: const [
                  Colors.red,
                  Colors.blue,
                  Colors.yellow,
                  Colors.green,
                  Colors.purple,
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator(radius: 20)),
      error: (error, _) => const SizedBox(),
    );
  }
}

