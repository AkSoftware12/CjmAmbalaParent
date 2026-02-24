import 'dart:async';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:avi/UI/Attendance/AttendanceScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
import '../Gallery/Album/album.dart' show GalleryScreen;
import '../Leaves/leaves_tab.dart';
import '../Message/message.dart';
import '../TimeTable/time_table.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    {'name': 'Activity Calendar', 'image': 'assets/calendar_activity.png'},
    {'name': 'Gallery', 'image': 'assets/gallery.png'},
  ];


  @override
  void initState() {
    super.initState();
    fetchData();
    calendarController = CleanCalendarController(
      minDate: DateTime.now().subtract(const Duration(days: 30)),
      maxDate: DateTime.now().add(const Duration(days: 365)),
    );
    fetchStudentData();

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
          /// ✅ banners store karo
          banners = data['banners'] ?? [];

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
                  CarouselExample(banners: banners,),
                  const SizedBox(height: 20),
                  _buildsellAll('Category', ''),
                  _buildGridview(),
                  const SizedBox(height: 10),
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
              } else if (items[index]['name'] == 'Activity Calendar') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return CalendarScreen(title: 'Activity Calendar');
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
              // decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(10)
              // ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      items[index]['image']!,
                      height: 50, // Adjust the size as needed
                      width: 50,
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          items[index]['name']!,
                          textAlign: TextAlign.center, // <-- ये जोड़ा
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
                    placeholder: (context, _) =>
                    const BannerShimmer(radius: 8),
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
