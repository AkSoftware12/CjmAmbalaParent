import 'dart:convert';
import 'package:avi/utils/date_time_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../constants.dart';


class AchievementsWaveScreen extends StatefulWidget {
  const AchievementsWaveScreen({super.key});

  @override
  State<AchievementsWaveScreen> createState() => _AchievementsWaveScreenState();
}

class _AchievementsWaveScreenState extends State<AchievementsWaveScreen> {
  // API
  static const String _imgBase = "https://cjmambala.co.in";

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _page = 1;
  int _lastPage = 1;

  final List<AchievementItem> _items = [];
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch(page: 1);

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        if (_hasMore && !_loadingMore && !_loading) _fetchMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch({required int page}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // agar token required ho

      final url = Uri.parse("${ApiRoutes.getAchievement}?page=$page");
      final res = await http.get(
        url,
        headers: {
          "Accept": "application/json",
          if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final parsed = AchievementsResponse.fromJson(map);

        final album = parsed.album;
        final newItems = album?.data ?? [];

        setState(() {
          _items
            ..clear()
            ..addAll(newItems);

          _page = album?.currentPage ?? 1;
          _lastPage = album?.lastPage ?? 1;
          _hasMore = _page < _lastPage;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _snack("Server error: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack("Something went wrong");
      debugPrint("Achievements error: $e");
    }
  }

  Future<void> _fetchMore() async {
    if (_page >= _lastPage) {
      setState(() => _hasMore = false);
      return;
    }
    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = Uri.parse("${ApiRoutes.getAchievement}?page=$nextPage");
      final res = await http.get(
        url,
        headers: {
          "Accept": "application/json",
          if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final parsed = AchievementsResponse.fromJson(map);

        final album = parsed.album;
        final newItems = album?.data ?? [];

        setState(() {
          _items.addAll(newItems);
          _page = album?.currentPage ?? nextPage;
          _lastPage = album?.lastPage ?? _lastPage;
          _hasMore = _page < _lastPage;
          _loadingMore = false;
        });
      } else {
        setState(() => _loadingMore = false);
        _snack("Server error: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _loadingMore = false);
      _snack("Load more failed");
      debugPrint("Achievements load more error: $e");
    }
  }

  Future<void> _refresh() async => _fetch(page: 1);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openDetails(AchievementItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AchievementDetailsWaveScreen(
          item: item,
          imageUrl: item.fullCoverUrl(_imgBase),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Achievements",
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),

      body: Column(
        children: [

          Expanded(
            child: _loading
                ? const _ShimmerList()
                : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(5.w, 5.h, 5.w, 5.h),
                itemCount: _items.length + 1,
                itemBuilder: (context, i) {
                  if (i == _items.length) {
                    return _BottomLoader(show: _loadingMore, hasMore: _hasMore);
                  }

                  final item = _items[i];
                  return _AchievementCard(
                    item: item,
                    imageUrl: item.fullCoverUrl(_imgBase),
                    onTap: () => _openDetails(item),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =====================
/// DETAILS SCREEN
/// =====================
class AchievementDetailsWaveScreen extends StatelessWidget {
  final AchievementItem item;
  final String imageUrl;

  const AchievementDetailsWaveScreen({
    super.key,
    required this.item,
    required this.imageUrl,
  });



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Achievement Details",
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),

      ),

      body: Column(
        children: [

          Expanded(
            child: ListView(
              padding:EdgeInsets.zero,
              children: [
                Container(height: 2.h,),

                // Image (tap to zoom)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (_, __, ___) => _ImagePreview(imageUrl: imageUrl),
                      ),
                    );
                  },
                  child: Hero(
                    tag: imageUrl,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(0.r),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        // height: 280.h,
                        width: double.infinity,
                        // fit: BoxFit.fill,
                        placeholder: (_, __) => Container(
                          height: 280.h,
                          color: const Color(0xFFEFF2F7),
                          child: Center(
                            child: SizedBox(
                              height: 22.sp,
                              width: 22.sp,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 280.h,
                          color: const Color(0xFFEFF2F7),
                          child: Center(
                            child: Icon(Icons.image_not_supported_rounded,
                                size: 30.sp, color: Colors.black26),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 5.h),

                // Title Card
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? "Achievement",
                        style: GoogleFonts.montserrat(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF141414),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _Chip(icon: Icons.place_rounded, text: item.venue ?? "—"),
                          _Chip(icon: Icons.event_rounded, text: AppDateTimeUtils.date(item.eventDate) ?? "—"),
                          _Chip(icon: Icons.calendar_month_rounded, text: "Entry: ${AppDateTimeUtils.date(item.entryDate) ?? "-"}"),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 5.h),

                // Description
                if ((item.description ?? "").trim().isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.05),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: HtmlWidget(
                      item.description!,
                      textStyle: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        height: 1.45,
                        color: const Color(0xFF2B2B2B),
                      ),
                    ),
                  ),

                SizedBox(height: 12.h),

                // Action buttons
                Row(
                  children: [

                    SizedBox(width: 12.w),
                    Expanded(
                      child: _OutlineBtn(
                        text: "Back",
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 50.h),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =====================
/// IMAGE PREVIEW (Zoom)
/// =====================
class _ImagePreview extends StatelessWidget {
  final String imageUrl;
  const _ImagePreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(.92),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: imageUrl,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _GlassIconBtn(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// WAVE HEADER
/// =====================
class _WaveHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final Widget? rightWidget;

  const _WaveHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
    this.rightWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120.h,
      child: Stack(
        children: [
          ClipPath(
            child: Container(
              height: 100.h,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary,

                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              child: Row(
                children: [
                  _GlassIconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
                  const Spacer(),
                  if (rightWidget != null) rightWidget!,
                  if (rightWidget != null) SizedBox(width: 10.w),
                  _GlassIconBtn(icon: Icons.refresh_rounded, onTap: () => onRefresh()),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Container(
        height: 42.h,
        width: 42.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.14),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withOpacity(.22)),
        ),
        child: Icon(icon, color: Colors.white, size: 22.sp),
      ),
    );
  }
}


/// =====================
/// LIST CARD
/// =====================
class _AchievementCard extends StatelessWidget {
  final AchievementItem item;
  final String imageUrl;
  final VoidCallback onTap;

  const _AchievementCard({
    required this.item,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 190.h,
                    width: double.infinity,
                    // fit: BoxFit.fill,
                    placeholder: (_, __) => Container(
                      height: 190.h,
                      color: const Color(0xFFEFF2F7),
                      child: const Center(
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 190.h,
                      color: const Color(0xFFEFF2F7),
                      child: Center(
                        child: Icon(Icons.image_not_supported_rounded,
                            size: 30.sp, color: Colors.black26),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 0.w,
                    right: 0.w,
                    bottom: 0.h,
                    child: Container(
                      color: Colors.black54,
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Text(
                          item.title ?? "Achievement",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 5.h, 5.w, 5.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _Chip(icon: Icons.place_rounded, text: item.venue ?? "—"),
                      _Chip(icon: Icons.event_rounded, text: AppDateTimeUtils.date(item.eventDate) ?? "—"),
                    ],
                  ),
                  SizedBox(height: 0.h),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16.sp, color: Colors.black45),
                      SizedBox(width: 6.w),
                      Text(
                        "Entry: ${AppDateTimeUtils.date(item.entryDate) ?? "-"}",
                        style: GoogleFonts.poppins(
                          fontSize: 11.5.sp,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(.10),
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: Text(
                          "Open",
                          style: GoogleFonts.poppins(
                            fontSize: 11.5.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
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
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 230.w),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF202124),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =====================
/// BUTTONS
/// =====================

class _OutlineBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Container(
        height: 35.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.primary.withOpacity(.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: AppColors.primary),
            SizedBox(width: 8.w),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// LOADERS
/// =====================
class _BottomLoader extends StatelessWidget {
  final bool show;
  final bool hasMore;
  const _BottomLoader({required this.show, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    if (show) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: const Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: EdgeInsets.only(top: 4.h, bottom: 18.h),
        child: Center(
          child: Text(
            "No more achievements",
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return SizedBox(height: 10.h);
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 18.h),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          height: 260.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.black.withOpacity(.04)),
          ),
          child: Column(
            children: [
              Container(
                height: 170.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  children: [
                    Container(height: 12.h, color: const Color(0xFFEFF2F7)),
                    SizedBox(height: 10.h),
                    Container(height: 12.h, color: const Color(0xFFEFF2F7)),
                    SizedBox(height: 10.h),
                    Container(height: 12.h, color: const Color(0xFFEFF2F7)),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

/// =====================
/// MODELS (API ke according)
/// =====================
class AchievementsResponse {
  final String? message;
  final Album? album;
  final bool? success;
  final int? status;

  AchievementsResponse({this.message, this.album, this.success, this.status});

  factory AchievementsResponse.fromJson(Map<String, dynamic> json) {
    return AchievementsResponse(
      message: json['message'] as String?,
      album: json['album'] == null ? null : Album.fromJson(json['album']),
      success: json['success'] as bool?,
      status: _asInt(json['status']),
    );
  }
}

class Album {
  final int? currentPage;
  final List<AchievementItem> data;
  final int? lastPage;

  Album({this.currentPage, this.data = const [], this.lastPage});

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      currentPage: _asInt(json['current_page']),
      lastPage: _asInt(json['last_page']),
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => AchievementItem.fromJson(e))
          .toList() ??
          const [],
    );
  }
}

class AchievementItem {
  final int? id;
  final String? title;
  final String? venue;
  final String? eventDate;
  final String? description;
  final String? coverImage;
  final String? entryDate;
  final int? status;

  AchievementItem({
    this.id,
    this.title,
    this.venue,
    this.eventDate,
    this.description,
    this.coverImage,
    this.entryDate,
    this.status,
  });

  factory AchievementItem.fromJson(dynamic json) {
    final Map<String, dynamic> map = json as Map<String, dynamic>;
    return AchievementItem(
      id: _asInt(map['id']),
      title: map['title'] as String?,
      venue: map['venue'] as String?,
      eventDate: map['event_date'] as String?,
      description: map['description'] as String?,
      coverImage: map['cover_image'] as String?,
      entryDate: map['entry_date'] as String?,
      status: _asInt(map['status']),
    );
  }

  String fullCoverUrl(String baseUrl) {
    if (coverImage == null || coverImage!.isEmpty) return "";
    if (coverImage!.startsWith("http")) return coverImage!;
    if (baseUrl.endsWith("/")) {
      return "${baseUrl.substring(0, baseUrl.length - 1)}$coverImage";
    }
    return "$baseUrl$coverImage";
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}


