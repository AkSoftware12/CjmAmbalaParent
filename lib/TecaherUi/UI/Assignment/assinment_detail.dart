import 'dart:convert';

import 'package:avi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants.dart';

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
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  String _safeString(dynamic v) => (v ?? '').toString().trim();
  bool _hasText(dynamic v) => _safeString(v).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF6F7FB);

    return Scaffold(
      backgroundColor: bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchAssignment(widget.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 34.sp,
                    width: 34.sp,
                    child: const CircularProgressIndicator(),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "Loading Assignment...",
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.sp),
                child: Text(
                  "Error: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!['success'] != true) {
            return Center(
              child: Text(
                "No Assignment Found",
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final data = snapshot.data!['data'] as Map<String, dynamic>;
          final title = _safeString(data['title']).toUpperCase();
          final desc = _safeString(data['description']);
          final students = (data['students'] as List?) ?? [];

          final startDate = _safeString(data['start_date']);
          final endDate = _safeString(data['end_date']);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 100.h,
                pinned: true,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: EdgeInsetsDirectional.only(
                    start: 56.w,
                    bottom: 12.h,
                    end: 12.w,
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1B1B1F),
                          Color(0xFF5B21B6), // purple
                          Color(0xFF9333EA), // violet
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 18.h),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 44.sp,
                                width: 44.sp,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.20),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.assignment_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Assignment Details",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.16),
                                        borderRadius:
                                        BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.18),
                                        ),
                                      ),
                                      child: Text(
                                        "${students.length} Students",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
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
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
                  child: Column(
                    children: [
                      // Glassy Detail Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14.sp),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 18,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            )
                          ],
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dates Row
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoPill(
                                    icon: Icons.play_circle_fill_rounded,
                                    title: "Start",
                                    value: AppDateTimeUtils.date(startDate),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: _InfoPill(
                                    icon: Icons.flag_circle_rounded,
                                    title: "Due",
                                    value: AppDateTimeUtils.date(endDate),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "Description",
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              desc.isEmpty ? "—" : desc,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // Students Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Students",
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5B21B6), Color(0xFF9333EA)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "${students.length} Total",
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Students List
              SliverPadding(
                padding: EdgeInsets.fromLTRB(12.w, 2.h, 12.w, 18.h),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final student =
                          (students[index] as Map?)?.cast<String, dynamic>() ??
                              <String, dynamic>{};

                      final name = _safeString(student['student_name']);
                      final marks = student['marks'];
                      final isPresent = (student['attendance'] == 1);
                      final dateStr = _safeString(student['date']);
                      final attachUrl = _safeString(student['attach_url']);

                      return Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(12.sp),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar
                            Container(
                              height: 46.sp,
                              width: 46.sp,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF5B21B6),
                                    Color(0xFF9333EA),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Text(
                                name.isEmpty ? "?" : name[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            SizedBox(width: 12.w),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                      _StatusChip(isPresent: isPresent),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),

                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: [

                                      _MiniTag(
                                        icon: Icons.calendar_month_rounded,
                                        text: "Date: ${AppDateTimeUtils.date(dateStr)}",
                                      ),
                                    ],
                                  ),

                                  if (_hasText(attachUrl)) ...[
                                    SizedBox(height: 10.h),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        borderRadius:
                                        BorderRadius.circular(12.r),
                                        onTap: () => _openFile(attachUrl),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 10.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4FF),
                                            borderRadius:
                                            BorderRadius.circular(12.r),
                                            border: Border.all(
                                              color: const Color(0xFF5B21B6)
                                                  .withOpacity(0.15),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.attach_file_rounded,
                                                size: 18,
                                                color: Color(0xFF5B21B6),
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                "Open Attachment",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                  const Color(0xFF5B21B6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoPill({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            height: 30.sp,
            width: 30.sp,
            decoration: BoxDecoration(
              color: const Color(0xFF5B21B6).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 18.sp, color: const Color(0xFF5B21B6)),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
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
                    color: Colors.black87,
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

class _StatusChip extends StatelessWidget {
  final bool isPresent;
  const _StatusChip({required this.isPresent});

  @override
  Widget build(BuildContext context) {
    final bg = isPresent ? const Color(0xFFEAF7EF) : const Color(0xFFFFECEC);
    final fg = isPresent ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: fg,
          ),
          SizedBox(width: 6.w),
          Text(
            isPresent ? "Present" : "Absent",
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}