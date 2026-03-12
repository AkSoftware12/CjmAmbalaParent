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
import 'package:intl/intl.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../../TecaherUi/UI/Notice/notice.dart';
import '../../constants.dart';
import '../Assignment/assignment.dart';
import '../Auth/login_screen.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

// ✅✅✅ FIX: ConsumerState<HomeScreen>
class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? studentData;
  Map<String, dynamic>? _selectedUser; // 👈 Add this
  List assignments = []; // Declare a list to hold API data
  List<dynamic> banners = [];

  bool isLoading = true;
  double attendancePercent = 0;
  int? messageViewPermissionsApp;
  int? messageSendPermissionsApp;

  int? messageCount;
  int? feesCount;
  int? assignmentCount;
  int? galleryCount;

  late CleanCalendarController calendarController;
  List<Map<String, dynamic>> get items => [
    {'name': 'Assignments', 'image': 'assets/assignments.png', 'count': assignmentCount ?? 0},
    {'name': 'Time Table', 'image': 'assets/watch.png', 'count': 0},
    {'name': 'Messages', 'image': 'assets/message_home.png', 'count': messageCount ?? 0},
    {'name': 'Attendance', 'image': 'assets/calendar_attendance.png', 'count': 0},

    // ✅ Fees: agar count > 0 to number, warna 0
    {'name': 'Fees', 'image': 'assets/rupee-indian.png', 'count':  ((feesCount ?? 0) > 0 ? 'DUE' : 0)},

    {'name': 'Gallery', 'image': 'assets/gallery.png', 'count': galleryCount ?? 0},
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
    _loadSelectedUser(); // 👈 Add this

    // ✅✅✅ IMPORTANT FIX:
    // HomeScreen open hote hi provider ko current token se force refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(dashboardDataProvider.notifier).fetchDashboardData();
    });

    updateDatetime();
  }

  // 👇 Add this function to load selected user
  Future<void> _loadSelectedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getString('loginHistory');
    final selectedId = prefs.getString('selected_student_id');

    if (history != null && history.isNotEmpty && selectedId != null) {
      final loadedList =
      List<Map<String, dynamic>>.from(jsonDecode(history) as List<dynamic>);

      for (final user in loadedList) {
        if (user['student_id']?.toString() == selectedId) {
          if (mounted) {
            setState(() {
              _selectedUser = user;
            });
          }
          break;
        }
      }
    }
  }

  Future<void> updateDatetime() async {
    final prefs = await SharedPreferences.getInstance();

    final teacherToken = prefs.getString('teachertoken');
    final userToken = prefs.getString('token');

    // ✅ jo token mile use karo
    final token = (teacherToken != null && teacherToken.isNotEmpty)
        ? teacherToken
        : userToken;

    if (token == null || token.isEmpty) {
      print('No token found');
      return;
    }

    final uri = Uri.parse(ApiRoutes.appReport);

    final request = http.MultipartRequest('POST', uri);

    // ✅ Only ONE token header
    request.headers['Authorization'] = 'Bearer $token';

    // ✅ 24 hour format datetime
    String formattedDate =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    request.fields['datetime'] = formattedDate;

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          print('AppReport: ${data['message']}');
        } else {
          print('AppReport Failed: ${data['message']}');
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Update datetime error: $e');
    }
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

      /// ⭐⭐⭐ MOST IMPORTANT PART ⭐⭐⭐
      if (response.statusCode == 440) {
        showSessionExpiredDialog(context);
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);

        final Map<String, dynamic> data =
        Map<String, dynamic>.from(decoded['data'] ?? {});

        applyDashboardCounts(data);

        setState(() {
          final permissions = (data['permisions'] ?? []) as List;

          messageViewPermissionsApp =
              (permissions.isNotEmpty
                  ? (permissions[0]['app_status'] as num?)?.toInt()
                  : 0) ??
                  0;

          messageSendPermissionsApp =
              (permissions.length > 1
                  ? (permissions[1]['app_status'] as num?)?.toInt()
                  : 0) ??
                  0;
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

  void applyDashboardCounts(Map<String, dynamic> data) {
    setState(() {
      messageCount = _toInt(data['message_count']);
      assignmentCount = _toInt(data['assignment_count']);
      feesCount = _toInt(data['fee_count']);

      galleryCount = _toInt(data['photo_count']) ?? 0;
    });
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _refreshDashboardCounts() async {
    if (!mounted) return;

    // optional loader (agar chaho)
    setState(() => isLoading = true);

    await fetchData(); // ✅ ye wali API hit hogi aur counts refresh honge

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  // 👇 Updated this function
  void showSessionExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return SessionExpiredDialogContent(
          selectedUser: _selectedUser, // 👈 Pass user data from state
        );
      },
    );
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
            CarouselExample(banners: banners),
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
                    colors: [Colors.white, Colors.white],
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
          final item = items[index];
          final raw = item['count'];

          int count = 0;
          String? label;

          if (raw is int) {
            count = raw;
          } else if (raw is String && int.tryParse(raw) != null) {
            count = int.parse(raw);
          } else if (raw is String) {
            label = raw.toUpperCase(); // DUE / PENDING
          }

          final showBadge = (count > 0) || (label != null);
          return GestureDetector(
            onTap: () async {
              if (items[index]['name'] == 'Assignments') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AssignmentListScreen()),
                );

                // ✅ back aate hi dashboard api hit + count refresh
                await _refreshDashboardCounts();
              } else if (items[index]['name'] == 'Gallery') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return GalleryScreen();
                    },
                  ),
                );
                await _refreshDashboardCounts();

              } else if (items[index]['name'] == 'Library') {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: Duration(
                      milliseconds: 500,
                    ), // Animation Speed
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        LibraryScreen(appBar: '25'),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      var begin = Offset(1.0, 0.0); // Right to Left
                      var end = Offset.zero;
                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: Curves.easeInOut));

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
                await  Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return FeesScreen(title: 'fees');
                    },
                  ),
                );
                await _refreshDashboardCounts();

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
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return MesssageListScreen(
                        messageSendPermissionsApp: messageSendPermissionsApp,
                      );
                    },
                  ),
                );
                await _refreshDashboardCounts();

              }
            },
            child: Stack(
              children: [
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.red.shade600,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            items[index]['image']!,
                            height: 40,
                            width: 40,
                          ),
                          SizedBox(height: 10),
                          Text(
                            items[index]['name']!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                /// 🔴 BADGE COUNT
                if (count > 0 || label != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: Text(
                        label ?? "$count",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
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
                    fit: BoxFit.fill,
                    // ✅ correct fit
                    width: double.infinity,
                    memCacheWidth: cacheW,
                    // ✅ fast decode
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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

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
          final academicClass =
              (item['academic_class'] as Map<String, dynamic>);
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
      loading: () =>
          const Center(child: CupertinoActivityIndicator(radius: 20)),
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
              ),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 18.h,
                  ),
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
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.cake_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}







class SessionExpiredDialogContent extends StatefulWidget {
  final Map<String, dynamic>? selectedUser;

  const SessionExpiredDialogContent({
    Key? key,
    this.selectedUser,
  }) : super(key: key);

  @override
  State<SessionExpiredDialogContent> createState() =>
      _SessionExpiredDialogContentState();
}

class _SessionExpiredDialogContentState
    extends State<SessionExpiredDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLoginAgain() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ 1) Clear tokens
      await prefs.remove('token');
      await prefs.remove('newusertoken');
      await prefs.remove('teachertoken');

      // ✅ 2) Remove selected user from loginHistory
      final history = prefs.getString('loginHistory');
      if (history != null && history.isNotEmpty) {
        final loadedList = List<Map<String, dynamic>>.from(
            jsonDecode(history) as List<dynamic>);

        final studentId = widget.selectedUser?['student_id']?.toString();
        loadedList.removeWhere((e) => e['student_id']?.toString() == studentId);

        await prefs.setString('loginHistory', jsonEncode(loadedList));
      }

      // ✅ 3) Clear selected_student_id
      await prefs.remove('selected_student_id');

      if (!mounted) return;

      // ✅ 4) Direct navigation
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deepRed = AppColors.primary;
    final darkRed = AppColors.primary;
    final selectedUser = widget.selectedUser;

    return PopScope(
      canPop: false,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: AlertDialog(
              backgroundColor: Colors.white,
              elevation: 24,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: deepRed, width: 1.5),
              ),

              // 👇 TITLE - Lock icon + Session Expired
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60.sp,
                    height: 60.sp,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [deepRed, deepRed.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: deepRed.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_clock_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 16.sp),
                  Text(
                    "Session Expired",
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              // 👇 CONTENT - User info + Message
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ User Card
                  if (selectedUser != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(5.sp),
                      margin: EdgeInsets.only(bottom: 10.sp),
                      decoration: BoxDecoration(
                        color: deepRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: deepRed.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // 👈 Avatar
                          Container(
                            width: 40.sp,
                            height: 40.sp,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [deepRed, deepRed.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Center(
                              child: Text(
                                (selectedUser['name']?.toString().substring(0, 1) ?? 'U')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.sp),
                          // 👉 User details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedUser['name'] ?? 'Unknown User',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                if (selectedUser['adm_no'] != null &&
                                    selectedUser['adm_no'].toString() != 'null')
                                  Text(
                                    "Adm No: ${selectedUser['adm_no']}",
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // ✅ Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.sp,
                              vertical: 4.sp,
                            ),
                            decoration: BoxDecoration(
                              color: deepRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                               Icons.verified,
                              size: 14.sp,
                              color: deepRed,
                            ),
                          ),                        ],
                      ),
                    ),

                  // ✅ Message Box
                  Container(
                    padding: EdgeInsets.all(12.sp),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: deepRed.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: deepRed,
                          size: 20.sp,
                        ),
                        SizedBox(width: 10.sp),
                        Expanded(
                          child: Text(
                            "Your session has expired due to inactivity. Please log in again to continue.",
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 👇 ACTION BUTTON
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [deepRed, deepRed.withOpacity(0.85)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: deepRed.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _handleLoginAgain,
                        borderRadius: BorderRadius.circular(12),
                        splashColor: Colors.white.withOpacity(0.25),
                        highlightColor: Colors.white.withOpacity(0.15),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 12.sp,
                            horizontal: 16.sp,
                          ),
                          child: _isLoading
                              ? SizedBox(
                            height: 22.sp,
                            width: 22.sp,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.login_rounded,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                              SizedBox(width: 10.sp),
                              Text(
                                "Login Again",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              actionsPadding: EdgeInsets.all(16.sp),
              contentPadding: EdgeInsets.fromLTRB(20.sp, 18.sp, 20.sp, 12.sp),
              titlePadding: EdgeInsets.fromLTRB(20.sp, 20.sp, 20.sp, 8.sp),
            ),
          ),
        ),
      ),
    );
  }
}
