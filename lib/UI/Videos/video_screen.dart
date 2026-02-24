import 'dart:convert';

import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VideoGallery extends StatefulWidget {
  const VideoGallery({super.key});

  @override
  State<VideoGallery> createState() => _VideoGalleryState();
}

class _VideoGalleryState extends State<VideoGallery> {
  bool isLoading = true;
  String? errorMsg;
  List<dynamic> videoGallery = [];

  @override
  void initState() {
    super.initState();
    galleryVideoApi();
  }

  Future<void> galleryVideoApi() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // ✅ TODO: your API endpoint
    final url = Uri.parse(ApiRoutes.getVideos);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          videoGallery = data['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMsg = "Server error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = "Network error. Please try again.";
      });
      debugPrint('Error fetching Data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          'Video Gallery',
          style: GoogleFonts.openSans(
            fontSize: 14.sp,
            color: AppColors.textwhite,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: galleryVideoApi,
        child: Builder(
          builder: (_) {
            if (isLoading) {
              return _loadingView();
            }

            if (errorMsg != null) {
              return _errorView();
            }

            if (videoGallery.isEmpty) {
              return _emptyView();
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 18.h),
              itemCount: videoGallery.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final item = videoGallery[index] as Map<String, dynamic>? ?? {};

                // ✅ adjust according to your API keys
                final title = (item['title'] ?? item['name'] ?? 'Untitled').toString();
                final subtitle = (item['subtitle'] ?? item['description'] ?? '').toString();
                final thumb = (item['thumbnail'] ?? item['thumb'] ?? item['image'] ?? '').toString();
                final duration = (item['duration'] ?? item['time'] ?? '').toString(); // e.g. "12:30"
                final category = (item['category'] ?? item['tag'] ?? 'Video').toString();

                return _videoCard(
                  title: title,
                  subtitle: subtitle,
                  thumbUrl: thumb,
                  duration: duration,
                  category: category,
                  onTap: () {
                    // ✅ TODO: open player / detail screen
                    // Navigator.push(...)
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _loadingView() {
    return ListView(
      padding: EdgeInsets.all(12.w),
      children: List.generate(6, (i) => _shimmerCard()),
    );
  }

  Widget _errorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 80.h),
        Center(
          child: Container(
            padding: EdgeInsets.all(16.w),
            margin: EdgeInsets.symmetric(horizontal: 18.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 42.sp, color: AppColors.primary),
                SizedBox(height: 10.h),
                Text(
                  errorMsg ?? "Something went wrong",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  "Pull down to refresh or try again.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton.icon(
                    onPressed: galleryVideoApi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: Text(
                      "Retry",
                      style: GoogleFonts.openSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 70.h),
        Center(
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 160.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    color: const Color(0xFFF3F4F8),
                  ),
                  child:Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 90.sp, // size adjust kar sakte ho
                      color: Colors.red, // video jaisa look
                    ),
                  ),

                ),
                SizedBox(height: 12.h),
                Text(
                  'No Videos Found',
                  style: GoogleFonts.openSans(
                    fontSize: 14.sp,
                    color: const Color(0xFF1E1E1E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  "New videos will appear here once available.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoCard({
    required String title,
    required String subtitle,
    required String thumbUrl,
    required String duration,
    required String category,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      height: 86.h,
                      width: 120.w,
                      color: const Color(0xFFF0F2F6),
                      child: thumbUrl.isEmpty
                          ? Icon(Icons.video_library_rounded, size: 32.sp, color: Colors.grey.shade500)
                          : Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_rounded,
                          size: 28.sp,
                          color: Colors.grey.shade500,
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: SizedBox(
                              height: 18.sp,
                              width: 18.sp,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Play overlay
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 34.sp,
                        width: 34.sp,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow_rounded, size: 22.sp, color: Colors.white),
                      ),
                    ),
                  ),

                  // Duration badge
                  if (duration.trim().isNotEmpty)
                    Positioned(
                      bottom: 7.h,
                      right: 7.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          duration,
                          style: GoogleFonts.openSans(
                            fontSize: 10.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Text area
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 12.h, 12.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.openSans(
                              fontSize: 13.sp,
                              color: const Color(0xFF1E1E1E),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(Icons.chevron_right_rounded, size: 22.sp, color: Colors.grey.shade500),
                      ],
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.openSans(
                          fontSize: 11.sp,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        _chip(
                          icon: Icons.local_offer_rounded,
                          text: category,
                        ),
                        SizedBox(width: 8.w),
                        _chip(
                          icon: Icons.hd_rounded,
                          text: "HD",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.95),
            AppColors.primary.withOpacity(0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.openSans(
              fontSize: 10.5.sp,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // simple skeleton card (no package)
  Widget _shimmerCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 86.h,
            width: 120.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12.h, width: double.infinity, color: const Color(0xFFF0F2F6)),
                SizedBox(height: 8.h),
                Container(height: 12.h, width: 180.w, color: const Color(0xFFF0F2F6)),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Container(height: 26.h, width: 70.w, color: const Color(0xFFF0F2F6)),
                    SizedBox(width: 8.w),
                    Container(height: 26.h, width: 54.w, color: const Color(0xFFF0F2F6)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
