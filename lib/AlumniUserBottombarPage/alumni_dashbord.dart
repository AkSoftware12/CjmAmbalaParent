import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../../constants.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../TecaherUi/UI/Notice/notice.dart';
import '../UI/Auth/login_screen.dart';
import '../UI/EbooksScreen/Ebooks/ebooks.dart';
import '../UI/Gallery/Album/album.dart';
import '../UI/MagazineScreen/Magzine/magzine.dart';
import '../UI/Notice/notice.dart';
import '../UI/StudentMsg/StudentTabScreen/student_tab_screen.dart';
import '../UI/TimeTable/demo.dart';
import 'AlumniStudentMsg/AlumniStudentTabScreen/alumni_student_tab_screen.dart';
import 'alumni_chat_screen.dart';
import 'alumni_counts_provider.dart';
import 'alumni_notice.dart';

/// ---------------------------------------------------------------------------
/// Design tokens (Figma redesign se)
/// ---------------------------------------------------------------------------
class DashColors {
  static const bg = Color(0xFFF7F7F9); // light gray background
  static const red = Color(0xFFE53935); // primary red
  static const redDark = Color(0xFFC62828); // gradient end
  static const dark = Color(0xFF1F2430); // headings / labels
  static const gray = Color(0xFF8A8F98); // secondary text
}

class AlumniDashBoard extends ConsumerStatefulWidget {
  const AlumniDashBoard({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<AlumniDashBoard> {
  Map<String, dynamic>? studentData;
  Map<String, dynamic>? _selectedUser;
  List assignments = [];
  List<dynamic> banners = [];

  bool isLoading = true;
  double attendancePercent = 0;
  int? messageViewPermissionsApp;
  int? messageSendPermissionsApp;

  late CleanCalendarController calendarController;

  /// ✅ Counts ab shared provider (AlumniCounts) se aate hain —
  /// bottombar/drawer aur ye grid hamesha same value dikhayenge.
  List<Map<String, dynamic>> _items(AlumniCounts c) => [
    {
      'name': 'Messages',
      'image': 'assets/message_home.png',
      'count': c.message,
      'chipColor': const Color(0xFFE3F2FD),
    },
    {
      'name': 'Activity Calendar',
      'image': 'assets/document.png',
      'count': 0,
      'chipColor': const Color(0xFFFFF3E0),
    },
    {
      'name': 'Magazines',
      'image': 'assets/watch.png',
      'count': 0,
      'chipColor': const Color(0xFFE8F5E9),
    },
    {
      'name': 'Notice',
      'image': 'assets/calendar_attendance.png',
      'count': c.notice,
      'chipColor': const Color(0xFFF3E5F5),
    },
    {
      'name': 'E-Books',
      'image': 'assets/ebook.png',
      'count': 0,
      'chipColor': const Color(0xFFFFE7E7),
    },
    {
      'name': 'Gallery',
      'image': 'assets/gallery.png',
      'count': c.gallery,
      'chipColor': const Color(0xFFE0F2F1),
    },
  ];

  @override
  void initState() {
    super.initState();
    // ✅ counts provider khud fetch karta hai — yahan fetchData sirf
    // permissions / session-expiry ke liye hai
    fetchPermissions();
    fetchBannerData();
    calendarController = CleanCalendarController(
      minDate: DateTime.now().subtract(const Duration(days: 30)),
      maxDate: DateTime.now().add(const Duration(days: 365)),
    );
    fetchStudentData();
    _loadSelectedUser();
    updateDatetime();
  }

  Future<void> _loadSelectedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getString('loginHistory');
    final selectedId = prefs.getString('selected_student_id');

    if (history != null && history.isNotEmpty && selectedId != null) {
      final loadedList = List<Map<String, dynamic>>.from(
        jsonDecode(history) as List<dynamic>,
      );

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

    final token = (teacherToken != null && teacherToken.isNotEmpty)
        ? teacherToken
        : userToken;

    if (token == null || token.isEmpty) {
      debugPrint('No token found');
      return;
    }

    final uri = Uri.parse(ApiRoutes.appReport);
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    String formattedDate =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    request.fields['datetime'] = formattedDate;

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('AppReport: ${data['message']}');
        } else {
          debugPrint('AppReport Failed: ${data['message']}');
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Update datetime error: $e');
    }
  }

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumniToken');

    if (token == null) return;

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfileAlumniUser),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        studentData = data['alumni'];
        isLoading = false;
      });
    }
  }

  /// ✅ Sirf permissions + session-expiry check — counts provider se aate hain
  Future<void> fetchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumniToken');
    final url = Uri.parse(ApiRoutes.getAlumniCount);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 440) {
        if (mounted) showSessionExpiredDialog(context);
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(decoded['data'] ?? {});

        setState(() {
          final permissions = (data['permisions'] ?? []) as List;

          messageViewPermissionsApp = (permissions.isNotEmpty
              ? (permissions[0]['app_status'] as num?)?.toInt()
              : 0) ??
              0;

          messageSendPermissionsApp = (permissions.length > 1
              ? (permissions[1]['app_status'] as num?)?.toInt()
              : 0) ??
              0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
    }
  }

  Future<void> fetchBannerData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumniToken');
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
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  /// ✅ Ek call — provider refresh hote hi dashboard grid, appbar bell
  /// aur drawer badges sab update ho jaate hain
  Future<void> _refreshDashboardCounts() async {
    await ref.read(alumniCountsProvider.notifier).refresh();
  }

  void showSessionExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return SessionExpiredDialogContent(selectedUser: _selectedUser);
      },
    );
  }

  // ===========================================================================
  // BUILD — Redesigned UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashColors.bg,
      body: RefreshIndicator(
        color: DashColors.red,
        onRefresh: () async {
          // ✅ Pull-to-refresh: counts + banners dono
          await Future.wait([
            _refreshDashboardCounts(),
            fetchBannerData(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              CarouselExample(banners: banners),
              const SizedBox(height: 20),
              _buildSectionHeader('Categories', 'See All'),
              _buildGridview(),
              const SizedBox(height: 10),
              _buildSchoolImage(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// "Categories" + "See All"
  Widget _buildSectionHeader(String title, String actionText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: DashColors.dark,
            ),
          ),
          if (actionText.isNotEmpty)
            GestureDetector(
              onTap: () {
                // TODO: See All action
              },
              child: Text(
                actionText,
                style: GoogleFonts.montserrat(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: DashColors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridview() {
    // ✅ Shared counts watch — provider refresh hote hi grid auto-update
    final counts = ref.watch(alumniCountsProvider);
    final items = _items(counts);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 0.92,
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

          return GestureDetector(
            onTap: () => _onCategoryTap(item['name'] as String),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // White card — soft shadow, no hard border
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border:
                    Border.all(width: 1.sp, color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pastel icon chip
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: item['chipColor'] as Color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(11),
                        child: Image.asset(
                          item['image']!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['name']!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: DashColors.dark,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),

                // Red badge pill
                if (count > 0 || label != null)
                  Positioned(
                    right: -2,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: DashColors.red,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: DashColors.red.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        label ?? '$count',
                        style: const TextStyle(
                          color: Colors.white,
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

  /// Navigation logic — har screen se wapas aane pe shared refresh
  Future<void> _onCategoryTap(String name) async {
    if (name == 'Activity Calendar') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarScreen(title: 'Activity Calendar'),
        ),
      );
      await _refreshDashboardCounts();
    } else if (name == 'Gallery') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GalleryScreen()),
      );
      await _refreshDashboardCounts();
    } else if (name == 'Magazines') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MagazineScreen()),
      );
      await _refreshDashboardCounts();
    } else if (name == 'E-Books') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EbooksScreen()),
      );
      await _refreshDashboardCounts();
    } else if (name == 'Notice') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AlumniNoticeScreen()),
      );
      await _refreshDashboardCounts();
    } else if (name == 'Time Table') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TimeTableScreen()),
      );
      await _refreshDashboardCounts();
    } else if (name == 'Messages') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AlumniStudentChatScreen(),
        ),
      );
      await _refreshDashboardCounts();
    }
  }

  /// School building image
  Widget _buildSchoolImage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Image.network(
          'https://cjmambala.in/images/building.png',
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(
            height: 200,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CAROUSEL — rounded, side margins, red expanding dots
// =============================================================================
class CarouselExample extends StatefulWidget {
  final List<dynamic> banners;
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
    final list = effectiveBanners;
    for (int i = 0; i < list.length && i < 2; i++) {
      precacheImage(CachedNetworkImageProvider(list[i]), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerList = effectiveBanners;
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
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              onPageChanged: (index, reason) {
                setState(() => _currentIndex = index);
              },
            ),
            items: bannerList.map((url) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.fill,
                      width: double.infinity,
                      memCacheWidth: cacheW,
                      placeholder: (context, _) =>
                      const BannerShimmer(radius: 20),
                      errorWidget: (context, _, __) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSmoothIndicator(
          activeIndex: _currentIndex,
          count: bannerList.length,
          effect: ExpandingDotsEffect(
            dotHeight: 7,
            dotWidth: 7,
            expansionFactor: 3,
            activeDotColor: DashColors.red,
            dotColor: Colors.grey.shade400,
          ),
          onDotClicked: (index) => _controller.animateToPage(index),
        ),
      ],
    );
  }
}

class BannerShimmer extends StatelessWidget {
  final double radius;

  const BannerShimmer({super.key, this.radius = 20});

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

// =============================================================================
// SESSION EXPIRED DIALOG — unchanged
// =============================================================================
class SessionExpiredDialogContent extends StatefulWidget {
  final Map<String, dynamic>? selectedUser;

  const SessionExpiredDialogContent({Key? key, this.selectedUser})
      : super(key: key);

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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
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

      await prefs.remove('token');
      await prefs.remove('newusertoken');
      await prefs.remove('teachertoken');
      await prefs.remove('alumniToken');

      final history = prefs.getString('loginHistory');
      if (history != null && history.isNotEmpty) {
        final loadedList = List<Map<String, dynamic>>.from(
          jsonDecode(history) as List<dynamic>,
        );

        final studentId = widget.selectedUser?['student_id']?.toString();
        loadedList
            .removeWhere((e) => e['student_id']?.toString() == studentId);

        await prefs.setString('loginHistory', jsonEncode(loadedList));
      }

      await prefs.remove('selected_student_id');

      if (!mounted) return;

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deepRed = AppColors.primary;
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                                (selectedUser['name']
                                    ?.toString()
                                    .substring(0, 1) ??
                                    'U')
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
                                    selectedUser['adm_no'].toString() !=
                                        'null')
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
                          ),
                        ],
                      ),
                    ),
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