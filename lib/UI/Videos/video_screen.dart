import 'dart:convert';

import 'package:avi/TecaherUi/UI/Dashboard/HomeScreen%20.dart';
import 'package:avi/constants.dart';
import 'package:avi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoGallery extends StatefulWidget {
  const VideoGallery({super.key});

  @override
  State<VideoGallery> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGallery> {
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

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getVideos),
        headers: {
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          videoGallery = data['album'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMsg = "Server Error : ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = e.toString();
      });
    }
  }

  Future<void> openYoutube(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.red,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          "Video Gallery",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15.sp,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: RefreshIndicator(
          onRefresh: galleryVideoApi,
          color: Colors.red,
          child: Builder(
            builder: (_) {
              if (isLoading) {
                return _loadingWidget();
              }

              if (errorMsg != null) {
                return _errorWidget();
              }

              if (videoGallery.isEmpty) {
                return _emptyWidget();
              }

              return GridView.builder(
                padding: EdgeInsets.all(8.w),
                itemCount: videoGallery.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 0.68,
                ),
                itemBuilder: (context, index) {
                  final item = videoGallery[index];

                  final title = item['title'] ?? "";
                  final image = item['image_url'] ?? "";
                  final description = item['description'] ?? "";
                  final date = item['event_date'] ?? "";

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerListScreen(
                            albumId: item['id'], title: title,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.07),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10.r),
                                ),
                                child: Image.network(
                                  image,
                                  height: 125.h,
                                  width: double.infinity,
                                  fit: BoxFit.fill,
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      height: 125.h,
                                      color: Colors.red.shade100,
                                      child: Icon(
                                        Icons.image,
                                        size: 40.sp,
                                        color: Colors.red,
                                      ),
                                    );
                                  },
                                ),
                              ),


                              Positioned(
                                top: 4.h,
                                left: 4.w,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text(
                                    "VIDEO",
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),

                                  SizedBox(height: 2.h),

                                  Expanded(
                                    child:Text(
                                      parseHtmlString(description ?? ''),
                                      maxLines: 2,
                                      style: GoogleFonts.poppins(fontSize: 10.sp),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        color: Colors.red.shade700,
                                        size: 13.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Expanded(
                                        child: Text(
                                          AppDateTimeUtils.date(date),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9.sp,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
                },
              );
            },
          ),
        ),
      ),
    );
  }
  String parseHtmlString(String htmlText) {
    final document = htmlText
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    return document.trim();
  }
  Widget _loadingWidget() {
    return ListView.builder(
      padding: EdgeInsets.all(14.w),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Container(
          margin: EdgeInsets.only(bottom: 18.h),
          height: 320.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
          ),
        );
      },
    );
  }

  Widget _errorWidget() {
    return Center(
      child: Text(
        errorMsg ?? "",
        style: GoogleFonts.montserrat(),
      ),
    );
  }

  Widget _emptyWidget() {
    return Center(
      child: Text(
        "No Videos Found",
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String formatDate(String date) {
    try {
      return DateFormat("dd MMM yyyy").format(DateTime.parse(date));
    } catch (e) {
      return date;
    }
  }
}

class VideoPlayerListScreen extends StatefulWidget {
  final int albumId;
  final String title;

  const VideoPlayerListScreen({
    super.key,
    required this.albumId, required this.title,
  });

  @override
  State<VideoPlayerListScreen> createState() =>
      _VideoPlayerListScreenState();
}

class _VideoPlayerListScreenState
    extends State<VideoPlayerListScreen> {

  bool isLoading = true;
  String? errorMsg;

  List<dynamic> videos = [];

  @override
  void initState() {
    super.initState();
    getVideos();
  }

  Future<void> getVideos() async {

    setState(() {
      isLoading = true;
    });

    try {

      final response = await http.get(
        Uri.parse(
          "${ApiRoutes.getVideosId}${widget.albumId}",
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {

        setState(() {
          videos = data['album'] ?? [];
          isLoading = false;
        });

      } else {

        setState(() {
          errorMsg = "Something went wrong";
          isLoading = false;
        });
      }

    } catch (e) {

      setState(() {
        errorMsg = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> openYoutube(String url) async {

    String finalUrl = url;

    if (url.contains("embed/")) {
      final id = url.split("embed/").last;
      finalUrl = "https://www.youtube.com/watch?v=$id";
    }

    final uri = Uri.parse(finalUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xfff5f5f5),

      appBar: AppBar(
        backgroundColor: Colors.red.shade800,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13.sp
          ),
        ),
      ),

      body: Builder(
        builder: (_) {

          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red,),
            );
          }

          if (errorMsg != null) {
            return Center(
              child: Text(errorMsg!),
            );
          }

          if (videos.isEmpty) {
            return const Center(
              child: Text("No Videos Found"),
            );
          }

          return GridView.builder(

            padding: EdgeInsets.all(5.w),


            itemCount: videos.length,

            gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              childAspectRatio: .78,
            ),

            itemBuilder: (context, index) {

              final item = videos[index];

              final image =
                  item['album_image_url'] ?? "";

              final videoUrl =
                  item['video_url'] ?? "";

              return GestureDetector(

                onTap: () {
                  openYoutube(videoUrl);
                },

                child: Container(

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(5.r),
                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.black.withOpacity(.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Column(
                    children: [

                      Expanded(
                        child: Stack(
                          children: [

                            ClipRRect(
                              borderRadius:
                              BorderRadius.vertical(
                                top:
                                Radius.circular(5.r),
                              ),
                              child: Image.network(
                                image,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,

                                errorBuilder:
                                    (_, __, ___) {
                                  return Container(
                                    color: Colors.red
                                        .shade100,
                                    child: Icon(
                                      Icons.image,
                                      size: 45.sp,
                                      color: Colors.red,
                                    ),
                                  );
                                },
                              ),
                            ),

                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  height: 55.h,
                                  width: 55.w,
                                  decoration:
                                  BoxDecoration(
                                    color: Colors.red
                                        .withOpacity(.9),
                                    shape:
                                    BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons
                                        .play_arrow_rounded,
                                    color:
                                    Colors.white,
                                    size: 38.sp,
                                  ),
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          children: [

                            Icon(
                              Icons
                                  .video_collection_rounded,
                              color:
                              Colors.red.shade700,
                              size: 16.sp,
                            ),

                            SizedBox(width: 6.w),

                            Expanded(
                              child: Text(
                                "Watch Video",
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style:
                                GoogleFonts
                                    .montserrat(
                                  fontWeight:
                                  FontWeight.w700,
                                  fontSize: 12.sp,
                                  color:
                                  Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}