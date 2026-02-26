import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:avi/UI/Attendance/AttendanceScreen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../../TecaherUi/UI/Notice/notice.dart';
import '../../constants.dart';
import '../Assignment/assignment.dart';
import '../Fees/FeesScreen.dart';
import '../Gallery/Album/album.dart' show GalleryScreen;
import '../Leaves/leaves_tab.dart';
import '../Library/LibraryScreen.dart';
import '../Message/message.dart';
import '../TimeTable/time_table.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
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

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // ✅ Only students
      return responseData['data']['today_student_birthdays'] ?? [];
    } else {
      throw Exception("Failed to load data");
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
      final token = prefs.getString('token');
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

// ✅✅✅ FIX: HomeScreen ko ConsumerStatefulWidget bana diya
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

// ✅✅✅ FIX: ConsumerState<HomeScreen>
class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? studentData;
  List assignments = []; // Declare a list to hold API data
  List<dynamic> banners = [];

  bool isLoading = true;
  double attendancePercent = 0;
  int? messageViewPermissionsApp;
  int? messageSendPermissionsApp;
  late CleanCalendarController calendarController;
  final List<Map<String, String>> items = [
    {'name': 'Assignments', 'image': 'assets/assignments.png'},
    {'name': 'Time Table', 'image': 'assets/watch.png'},
    {'name': 'Messages', 'image': 'assets/message_home.png'},
    {'name': 'Attendance', 'image': 'assets/calendar_attendance.png'},
    {'name': 'Fees', 'image': 'assets/rupee-indian.png'},
    {'name': 'Gallery', 'image': 'assets/gallery.png'},
    // {
    //   'name': 'Library',
    //   'image': 'assets/booksimg.png',
    // },
  ];

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchBannerData();
    calendarController = CleanCalendarController(
      minDate: DateTime.now().subtract(const Duration(days: 30)),
      maxDate: DateTime.now().add(const Duration(days: 365)),
    );
    fetchStudentData();

    // ✅✅✅ IMPORTANT FIX:
    // HomeScreen open hote hi provider ko current token se force refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(dashboardDataProvider.notifier).fetchDashboardData();
    });
  }

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      // _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfile),
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
      // _showLoginDialog();
    }
  }

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
        final data = json.decode(response.body)['data'];

        setState(() {
          /// ✅ permissions
          messageViewPermissionsApp =
              (data['permisions']?[0]['app_status'] as num?)?.toInt() ?? 0;

          messageSendPermissionsApp =
              (data['permisions']?[1]['app_status'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
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
          /// ✅ banners store karo
          banners = data['banners'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 20))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CarouselExample(
              banners: banners,
            ),
            const SizedBox(height: 20),
            _buildsellAll('Category', ''),
            _buildGridview(),
            const SizedBox(height: 10),
            _buildSectionTitle('Students Birthday', ''),
            BirthdayCard(),
            Container(
              height: 220,
              width: double.infinity,
              child: Image.network(
                'https://cjmambala.in/images/building.png',
                fit: BoxFit.fill,
              ),
            ),
            Divider(thickness: 1.sp, color: Colors.grey),
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
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              if (items[index]['name'] == 'Assignments') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return AssignmentListScreen();
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
              } else if (items[index]['name'] == 'Library') {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration:
                    Duration(milliseconds: 500), // Animation Speed
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        LibraryScreen(
                          appBar: '25',
                        ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      var begin = Offset(1.0, 0.0); // Right to Left
                      var end = Offset.zero;
                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: Curves.easeInOut));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              } else if (items[index]['name'] == 'Leaves') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return LeavesTabScreen();
                    },
                  ),
                );
              } else if (items[index]['name'] == 'Attendance') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return AttendanceCalendarScreen(title: 'Attendance');
                    },
                  ),
                );
              } else if (items[index]['name'] == 'Fees') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return FeesScreen(title: 'fees');
                    },
                  ),
                );
              } else if (items[index]['name'] == 'Time Table') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return TimeTableScreen();
                    },
                  ),
                );
              } else if (items[index]['name'] == 'Messages') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return MesssageListScreen(
                        messageSendPermissionsApp: messageSendPermissionsApp,
                      );
                    },
                  ),
                );
              }
            },
            child: Card(
              elevation: 5,
              color: Colors.red.shade600,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      items[index]['image']!,
                      height: 50,
                      width: 50,
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          items[index]['name']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            textStyle: Theme.of(context).textTheme.displayLarge,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.normal,
                            color: AppColors.textwhite,
                          ),
                        ),
                      ),
                    ),
                  ],
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
              color: AppColors.textwhite,
            ),
          ),
          Text(
            see,
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.normal,
              color: AppColors.textwhite,
            ),
          ),
        ],
      ),
    );
  }
}

class CarouselExample extends StatefulWidget {
  final List<dynamic> banners; // ✅ parent se aayega
  const CarouselExample({super.key, required this.banners});

  @override
  State<CarouselExample> createState() => _CarouselExampleState();
}

class _CarouselExampleState extends State<CarouselExample> {
  final List<String> imgList = [
    'https://apiweb.ksadmission.in/upload/banners/1766826226_PDS_5934.jpg',
    'https://apiweb.ksadmission.in/upload/banners/1766826226_PDS_6054.jpg',
  ];

  int _currentIndex = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  /// ✅ effective banners (API → fallback)
  List<String> get effectiveBanners {
    if (widget.banners.isNotEmpty) {
      final list = widget.banners
          .map<String>((e) => e['image_url']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }
    return imgList;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ Precache first 2 banners (perceived fast load)
    final list = effectiveBanners;
    for (int i = 0; i < list.length && i < 2; i++) {
      precacheImage(CachedNetworkImageProvider(list[i]), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerList = effectiveBanners;

    // ✅ optimize decode size (fast + less RAM)
    final screenW = MediaQuery.of(context).size.width;
    final cacheW = (screenW * MediaQuery.of(context).devicePixelRatio).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: screenW,
          child: CarouselSlider(
            controller: _controller,
            options: CarouselOptions(
              height: 180.sp,
              autoPlay: bannerList.length > 1,
              viewportFraction: 1,
              enableInfiniteScroll: bannerList.length > 1,
              autoPlayInterval: const Duration(seconds: 2),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              onPageChanged: (index, reason) {
                setState(() => _currentIndex = index);
              },
            ),
            items: bannerList.map((url) {
              return Padding(
                padding: const EdgeInsets.all(5.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.fill, // ✅ correct fit
                    width: double.infinity,
                    memCacheWidth: cacheW, // ✅ fast decode
                    placeholder: (context, _) => const BannerShimmer(radius: 8),
                    errorWidget: (context, _, __) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSmoothIndicator(
          activeIndex: _currentIndex,
          count: bannerList.length,
          effect: ExpandingDotsEffect(
            dotHeight: 8,
            dotWidth: 8,
            activeDotColor: Colors.redAccent,
            dotColor: Colors.grey.shade400,
          ),
          onDotClicked: (index) => _controller.animateToPage(index),
        ),
      ],
    );
  }
}

/// ✅ Premium shimmer placeholder (progress bar ki jagah)
class BannerShimmer extends StatelessWidget {
  final double radius;
  const BannerShimmer({super.key, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// -----------------------
// बाकी code tumhara same hai (BirthdayCard etc.) — unchanged ✅
// -----------------------

class CarouselFees extends StatelessWidget {
  final String dueAmount;
  final VoidCallback onPayNow;
  final String status;
  final String dueDate;
  final String payDate;
  final String custFirstName; //optional
  final String custLastName; //optional
  final String mobile; //optional
  final String email; //optional
  final String address;

  final List<Map<String, String>> imgList = [
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Welcome to CJM Ambala',
    },
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Best School for Excellence',
    },
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Learn, Grow & Succeed',
    },
    {
      'image': 'https://cjmambala.in/images/building.png',
      'text': 'Join Our Community',
    },
  ];

  CarouselFees({
    super.key,
    required this.dueAmount,
    required this.onPayNow,
    required this.status,
    required this.dueDate,
    required this.payDate,
    required this.custFirstName,
    required this.custLastName,
    required this.mobile,
    required this.email,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: CarouselSlider(
          options: CarouselOptions(
            height: 180,
            autoPlay: false,
            viewportFraction: 1,
            enableInfiniteScroll: true,
            autoPlayInterval: Duration(seconds: 1),
            autoPlayAnimationDuration: Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            scrollDirection: Axis.horizontal,
          ),
          items: imgList.map((item) {
            return DueAmountCard(
              dueAmount: '0',
              status: 'due',
              dueDate: '',
              payDate: '',
              onPayNow: () {},
              custFirstName: '',
              lastName: 'N/A',
              mobile: '',
              email: '',
              address: '',
            );
          }).toList(),
        ),
      ),
    );
  }
}

class DueAmountCard extends StatelessWidget {
  final String dueAmount;
  final VoidCallback onPayNow;
  final String status;
  final String dueDate;
  final String payDate;
  final String custFirstName;
  final String lastName;
  final String mobile;
  final String email;
  final String address;

  const DueAmountCard({
    super.key,
    required this.dueAmount,
    required this.onPayNow,
    required this.status,
    required this.dueDate,
    required this.payDate,
    required this.custFirstName,
    required this.lastName,
    required this.mobile,
    required this.email,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BottomNavBarScreen(initialIndex: 3),
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.11,
        width: MediaQuery.of(context).size.width * 0.93,
        decoration: BoxDecoration(
          color: HexColor('6e6edf'),
          borderRadius: BorderRadius.circular(10.sp),
        ),
        padding: EdgeInsets.all(5.sp),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Image.asset(
                  'assets/due_fees_amount.png',
                  height: 40.sp,
                  width: 40.sp,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Due Fees",
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textwhite,
                      ),
                    ),
                    Text(
                      "₹ $dueAmount",
                      style: GoogleFonts.poppins(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textwhite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 3.sp),
            Text(
              "Click to pay overdue fees",
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textwhite,
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
          name =
          '${(s['student_name'] ?? '').toString()}\n(${academicClass['title']}(${section['title']}))';
          imageUrl = (s['picture_data'] ?? '').toString();
          roleText = 'Student';
        } else {
          name = (item['first_name'] ?? '').toString();
          imageUrl = (item['photo'] ?? '').toString();
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
                                errorWidget: (context, url, error) => Icon(
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
                  Image.asset('assets/birthday.png', fit: BoxFit.fill),
                ],
              ),
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

class NoBirthdaysToday extends StatelessWidget {
  const NoBirthdaysToday({super.key});

  @override
  Widget build(BuildContext context) {
    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 420.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF7F7), Color(0xFFFFFFFF)],
            ),
            border: Border.all(color: Colors.black.withOpacity(.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 26,
                offset: const Offset(0, 14),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: Stack(
              children: [
                Positioned(
                  right: -60,
                  top: -60,
                  child: _BlurBlob(size: 180, color: red1.withOpacity(.18)),
                ),
                Positioned(
                  left: -70,
                  bottom: -70,
                  child: _BlurBlob(size: 200, color: red2.withOpacity(.14)),
                ),
                Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 54.w,
                        width: 54.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [red1, red2],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: red2.withOpacity(.35),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(Icons.cake_rounded,
                            color: Colors.white, size: 26),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "No birthdays today",
                              style: GoogleFonts.montserrat(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF141414),
                              ),
                            ),
                            SizedBox(height: 6.h),
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
}

class _BlurBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _BlurBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}