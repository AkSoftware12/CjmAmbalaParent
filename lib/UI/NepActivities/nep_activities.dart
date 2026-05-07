import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:avi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const kRed = Colors.red;
const kRedDark =Colors.red;
const kRedLight = Colors.red;
const kRedSurface = Color(0xfffff5f5);
const kBg = Color(0xfff7f7f7);

class NepScreen extends StatefulWidget {
  const NepScreen({super.key});

  @override
  State<NepScreen> createState() => _NepScreenState();
}

class _NepScreenState extends State<NepScreen> {
  bool isLoading = true;
  String? errorMessage;
  List nepList = [];


  @override
  void initState() {
    super.initState();
    fetchNepActivities();
  }

  Future<void> fetchNepActivities() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await http.get(
        Uri.parse(ApiRoutes.getNepActivityVideos),
        headers: {"Accept": "application/json"},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          nepList = data['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Something went wrong";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String parseHtmlString(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String formatDate(String? date) {
    if (date == null || date.isEmpty) return "No date";
    try {
      return DateFormat("dd MMM yyyy").format(DateTime.parse(date).toLocal());
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        leading: const BackButton(color: Colors.white),
        title: Text(
          "NEP Activities",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15.sp,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kRedLight, kRedDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: kRed,
        onRefresh: fetchNepActivities,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: kRed))
            : errorMessage != null
            ? _buildError()
            : nepList.isEmpty
            ? _buildEmpty()
            : ListView.builder(
          padding: EdgeInsets.fromLTRB(5.w, 5.h, 5.w, 24.h),
          itemCount: nepList.length,
          itemBuilder: (context, index) {
            final item = nepList[index];

            return NepSummaryCard(
              item: item,
              parseHtml: parseHtmlString,
              formatDate: formatDate,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NepDetailScreen(
                      item: item,
                      parseHtml: parseHtmlString,
                      formatDate: formatDate,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(height: 180.h),
        Icon(Icons.wifi_off_rounded, size: 58.sp, color: kRed.withOpacity(.5)),
        SizedBox(height: 12.h),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.r),
              ),
            ),
            onPressed: fetchNepActivities,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Retry"),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: 200.h),
        Icon(Icons.video_library_outlined, size: 60.sp, color: kRed.withOpacity(.5)),
        SizedBox(height: 10.h),
        Center(
          child: Text(
            "No activities found",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

class NepSummaryCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;
  final String Function(String) parseHtml;
  final String Function(String?) formatDate;

  const NepSummaryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.parseHtml,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final videos = item['videos'] as List? ?? [];
    final desc = parseHtml(item['description'] ?? "");

    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(videos.length),
            Padding(
              padding: EdgeInsets.all(5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    desc,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      height: 1.55,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      _miniChip(Icons.calendar_month_rounded, AppDateTimeUtils.date(item['event_date'])),
                      SizedBox(width: 8.w),
                      _miniChip(Icons.smart_display_rounded, "${videos.length} Videos"),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: const BoxDecoration(
                          color: kRed,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(int count) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
          child: Image.network(
            item['cover_image'] ?? "",
            height: 185.h,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loading) {
              if (loading == null) return child;
              return Container(
                height: 145.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
                ),
                child: const Center(child: CircularProgressIndicator(color: kRed)),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              height: 145.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
              ),
              child: Center(
                child: Icon(Icons.image_not_supported_rounded, color: Colors.white, size: 44.sp),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12.w,
          bottom: 12.h,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, color: kRed, size: 15.sp),
                SizedBox(width: 5.w),
                Text(
                  "$count Videos",
                  style: GoogleFonts.poppins(
                    color: kRed,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: kRedSurface,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: kRed.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kRed, size: 15.sp),
          SizedBox(width: 5.w),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: kRed,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class NepDetailScreen extends StatelessWidget {
  final dynamic item;
  final String Function(String) parseHtml;
  final String Function(String?) formatDate;

  const NepDetailScreen({
    super.key,
    required this.item,
    required this.parseHtml,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final videos = item['videos'] as List? ?? [];

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150.h,
            pinned: true,
            backgroundColor: Colors.red,
            leading: const BackButton(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 50.w, right: 16.w, bottom: 14.h),
              title: Text(
                item['title'] ?? "",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.sp,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item['cover_image'] ?? "",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kRedLight, kRedDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _infoChip(Icons.calendar_month_rounded, AppDateTimeUtils.date(item['event_date'])),
                      SizedBox(width: 8.w),
                      _infoChip(Icons.smart_display_rounded, "${videos.length} Videos"),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 15,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Text(
                      parseHtml(item['description'] ?? ""),
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        height: 1.7,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "Videos List",
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10.h),

                  GridView.builder(
                    itemCount: videos.length,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      childAspectRatio: .89,
                    ),
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      return YoutubeCard(
                        title: video['title'] ?? "",
                        videoUrl: video['video'] ?? "",
                        coverImage: item['cover_image'] ?? "",
                      );
                    },
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: kRed.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kRed, size: 16.sp),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: kRed,
              fontWeight: FontWeight.w800,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class YoutubeCard extends StatelessWidget {
  final String title;
  final String videoUrl;
  final String coverImage;

  const YoutubeCard({
    super.key,
    required this.title,
    required this.videoUrl,
    required this.coverImage,
  });

  Future<void> openYoutube() async {
    if (videoUrl.isEmpty) return;

    final Uri uri = Uri.parse(videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: openYoutube,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          children: [
            Expanded(child: _thumbnail()),
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: GoogleFonts.poppins(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
          child: Image.network(
            coverImage,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration:  BoxDecoration(
                color: Colors.grey.shade400
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              height: 46.h,
              width: 46.w,
              decoration: BoxDecoration(
                color: kRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kRed.withOpacity(.45),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30.sp),
            ),
          ),
        ),
      ],
    );
  }
}