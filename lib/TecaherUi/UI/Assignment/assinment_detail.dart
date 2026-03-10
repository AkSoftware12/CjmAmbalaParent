import 'dart:convert';

import 'package:avi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants.dart';

// ─── Brand Colors ───────────────────────────────────────────────────────────
const _kRed        = Color(0xFFB71C1C);
const _kRedMid     = Color(0xFFD32F2F);
const _kRedLight   = Color(0xFFEF5350);
const _kRedSurface = Color(0xFFFFF5F5);
const _kRedBorder  = Color(0xFFFFCDD2);
const _kBg         = Color(0xFFFAF7F7);

class AssignmentDetailScreen extends StatefulWidget {
  final int id;
  const AssignmentDetailScreen({super.key, required this.id});

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  Future<Map<String, dynamic>> fetchAssignment(int assignmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    final response = await http.get(
      Uri.parse('${ApiRoutes.baseUrl}/teacher-assignment/$assignmentId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load assignment');
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open file',
            style: GoogleFonts.poppins(fontSize: 13.sp),
          ),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
    }
  }

  String _safeString(dynamic v) => (v ?? '').toString().trim();
  bool _hasText(dynamic v) => _safeString(v).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Assignment Details',style: TextStyle(color: Colors.white,fontSize: 15.sp,fontWeight: FontWeight.bold),),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchAssignment(widget.id),
        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 34.sp,
                    width: 34.sp,
                    child: CircularProgressIndicator(
                      color: _kRed,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "Loading Assignment…",
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Error ────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20.sp),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(18.sp),
                      decoration: BoxDecoration(
                        color: _kRedSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kRedBorder),
                      ),
                      child: Icon(Icons.error_outline_rounded,
                          color: _kRed, size: 36.sp),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      "Something went wrong",
                      style: GoogleFonts.poppins(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12.sp, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Empty ────────────────────────────────────────────────────────
          if (!snapshot.hasData || snapshot.data!['success'] != true) {
            return Center(
              child: Text(
                "No Assignment Found",
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          // ── Data ─────────────────────────────────────────────────────────
          final data = snapshot.data!['data'] as Map<String, dynamic>;
          final title = _safeString(data['title']).toUpperCase();
          final desc = _safeString(data['description']);
          final students = (data['students'] as List?) ?? [];
          final startDate = _safeString(data['start_date']);
          final endDate = _safeString(data['end_date']);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── SliverAppBar ─────────────────────────────────────────────

              // ── Body ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitleCard(desc: title),
                      SizedBox(height: 14.h),

                      // ── Date Pills ────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _DatePill(
                              icon: Icons.play_circle_fill_rounded,
                              label: "Start Date",
                              value: AppDateTimeUtils.date(startDate),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _DatePill(
                              icon: Icons.flag_rounded,
                              label: "Due Date",
                              value: AppDateTimeUtils.date(endDate),
                              isDue: true,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 14.h),

                      // ── Description Card ──────────────────────────────────
                      if (desc.isNotEmpty) _DescriptionCard(desc: desc),

                      if (desc.isNotEmpty) SizedBox(height: 14.h),

                      // ── Students Header ───────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Students",
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: -0.2,
                            ),
                          ),
                          _CountBadge(count: students.length),
                        ],
                      ),

                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),

              // ── Students List ─────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 24.h),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final student =
                          (students[index] as Map?)?.cast<String, dynamic>() ??
                              <String, dynamic>{};

                      final name = _safeString(student['student_name']);
                      final isPresent = (student['attendance'] == 1);
                      final dateStr = _safeString(student['date']);
                      final attachUrl = _safeString(student['attach_url']);

                      return _StudentCard(
                        index: index,
                        name: name,
                        isPresent: isPresent,
                        dateStr: dateStr,
                        attachUrl: attachUrl,
                        onOpenFile: () => _openFile(attachUrl),
                        hasText: _hasText,
                      );
                    },
                    childCount: students.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── AppBar Background ───────────────────────────────────────────────────────
class _AppBarBackground extends StatelessWidget {
  final int studentCount;
  const _AppBarBackground({required this.studentCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7F0000), _kRed, _kRedMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -30.w,
            top: -20.h,
            child: Container(
              height: 120.sp,
              width: 120.sp,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 40.w,
            bottom: -10.h,
            child: Container(
              height: 70.sp,
              width: 70.sp,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 14.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 46.sp,
                    width: 46.sp,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Assignment Details",
                          style: GoogleFonts.poppins(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            _HeaderChip(
                              icon: Icons.people_alt_rounded,
                              label: "$studentCount Students",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: Colors.white),
          SizedBox(width: 5.w),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date Pill ───────────────────────────────────────────────────────────────
class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDue;

  const _DatePill({
    required this.icon,
    required this.label,
    required this.value,
    this.isDue = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDue ? _kRed : const Color(0xFF388E3C);
    final bgColor = isDue ? _kRedSurface : const Color(0xFFF1FBF4);
    final borderColor = isDue ? _kRedBorder : const Color(0xFFC8E6C9);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 34.sp,
            width: 34.sp,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 18.sp, color: color),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value.isEmpty ? "—" : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Description Card ────────────────────────────────────────────────────────
class _DescriptionCard extends StatelessWidget {
  final String desc;
  const _DescriptionCard({required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _kRedBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 30.sp,
                width: 30.sp,
                decoration: BoxDecoration(
                  color: _kRedSurface,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: _kRedBorder),
                ),
                child: Icon(Icons.notes_rounded, size: 16.sp, color: _kRed),
              ),
              SizedBox(width: 10.w),
              Text(
                "Description",
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
class _TitleCard extends StatelessWidget {
  final String desc;
  const _TitleCard({required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _kRedBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 30.sp,
                width: 30.sp,
                decoration: BoxDecoration(
                  color: _kRedSurface,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: _kRedBorder),
                ),
                child: Icon(Icons.title, size: 16.sp, color: _kRed),
              ),
              SizedBox(width: 10.w),
              Text(
                "Title",
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Count Badge ─────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F0000), _kRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        "$count Total",
        style: GoogleFonts.poppins(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Student Card ─────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final int index;
  final String name;
  final bool isPresent;
  final String dateStr;
  final String attachUrl;
  final VoidCallback onOpenFile;
  final bool Function(dynamic) hasText;

  const _StudentCard({
    required this.index,
    required this.name,
    required this.isPresent,
    required this.dateStr,
    required this.attachUrl,
    required this.onOpenFile,
    required this.hasText,
  });

  // Returns a shade from the red palette based on index (subtle variation)
  Color get _avatarColorA =>
      [
        const Color(0xFF7F0000),
        const Color(0xFFB71C1C),
        const Color(0xFFC62828),
        const Color(0xFFD32F2F),
      ][index % 4];

  Color get _avatarColorB =>
      [
        const Color(0xFFB71C1C),
        const Color(0xFFEF5350),
        const Color(0xFFD32F2F),
        const Color(0xFFEF9A9A),
      ][index % 4];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Container(
            height: 46.sp,
            width: 46.sp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_avatarColorA, _avatarColorB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: _kRed.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              name.isEmpty ? "?" : name[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),

          SizedBox(width: 12.w),

          // ── Details ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? "Unknown" : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    _StatusChip(isPresent: isPresent),
                  ],
                ),

                SizedBox(height: 0.h),

                // Date tag
                _MiniTag(
                  icon: Icons.calendar_today_rounded,
                  text: AppDateTimeUtils.date(dateStr),
                ),

                // Attachment button
                if (hasText(attachUrl)) ...[
                  SizedBox(height: 10.h),
                  _AttachButton(onTap: onOpenFile),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attachment Button ───────────────────────────────────────────────────────
class _AttachButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AttachButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: _kRedSurface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: _kRedBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, size: 16.sp, color: _kRed),
            SizedBox(width: 6.w),
            Text(
              "Open Attachment",
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: _kRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final bool isPresent;
  const _StatusChip({required this.isPresent});

  @override
  Widget build(BuildContext context) {
    final bg = isPresent ? const Color(0xFFE8F5E9) : _kRedSurface;
    final fg = isPresent ? const Color(0xFF2E7D32) : _kRed;
    final border = isPresent ? const Color(0xFFA5D6A7) : _kRedBorder;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13.sp,
            color: fg,
          ),
          SizedBox(width: 5.w),
          Text(
            isPresent ? "Present" : "Absent",
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini Tag ────────────────────────────────────────────────────────────────
class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: Colors.black45),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}