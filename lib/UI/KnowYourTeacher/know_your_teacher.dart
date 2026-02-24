import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';


class TeacherApiResponse {
  final bool success;
  final TeacherData? data;

  TeacherApiResponse({required this.success, required this.data});

  factory TeacherApiResponse.fromJson(Map<String, dynamic> json) {
    return TeacherApiResponse(
      success: json['success'] == true,
      data: json['data'] == null ? null : TeacherData.fromJson(json['data']),
    );
  }
}

class TeacherData {
  final Teacher? classTeacher;
  final List<Teacher> subjectTeachers;

  TeacherData({required this.classTeacher, required this.subjectTeachers});

  factory TeacherData.fromJson(Map<String, dynamic> json) {
    return TeacherData(
      classTeacher: json['class_teacher'] == null
          ? null
          : Teacher.fromJson(json['class_teacher']),
      subjectTeachers: (json['subject_teachers'] as List? ?? [])
          .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Teacher {
  final int id;
  final String name;
  final String photo;
  final List<Subject> subjects;

  Teacher({
    required this.id,
    required this.name,
    required this.photo,
    required this.subjects,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      photo: (json['photo'] ?? '') as String,
      subjects: (json['subjects'] as List? ?? [])
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Subject {
  final int id;
  final String name;

  Subject({required this.id, required this.name});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
    );
  }
}

/* ===========================
   ✅ SCREEN (Premium UI + API)
=========================== */

class TeacherListPremiumScreen extends StatefulWidget {
  const TeacherListPremiumScreen({super.key});

  @override
  State<TeacherListPremiumScreen> createState() =>
      _TeacherListPremiumScreenState();
}

class _TeacherListPremiumScreenState extends State<TeacherListPremiumScreen> {
  bool _loading = true;
  String? _error;

  Teacher? _classTeacher;
  List<Teacher> _subjectTeachers = [];





  @override
  void initState() {
    super.initState();
    _hitApi();
  }

  Future<void> _hitApi() async {

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("token: $token");
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final res = await http.get(
        Uri.parse(ApiRoutes.getKnowYourTeacher),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 200) {
        final jsonData = jsonDecode(res.body) as Map<String, dynamic>;
        final api = TeacherApiResponse.fromJson(jsonData);

        setState(() {
          _classTeacher = api.data?.classTeacher;
          _subjectTeachers = api.data?.subjectTeachers ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Server error: ${res.statusCode}\n${res.body}";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ksBlue1 = AppColors.primary;
    final ksBlue2 = AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ksBlue1, ksBlue2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: "Know Your Teacher",
                subtitle: "Class teacher & subject teachers",
                onBack: () => Navigator.pop(context),
                onRefresh: _hitApi,
              ),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6FF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22.r),
                    ),
                  ),
                  child: _loading
                      ? const _LoadingShimmer()
                      : _error != null
                      ? _ErrorView(message: _error!, onRetry: _hitApi)
                      : _buildList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 16.h),
      children: [
        if (_classTeacher != null) ...[
          const _SectionTitle(
            title: "Class Teacher",
            icon: Icons.verified_rounded,
          ),
          SizedBox(height: 10.h),
          TeacherPremiumCard(
            name: _classTeacher!.name,
            photoUrl: _classTeacher!.photo,
            subjects: _classTeacher!.subjects.map((e) => e.name).toList(),
            badgeText: "CLASS TEACHER",
            badgeColor: const Color(0xFF6C5CE7),
            onTap: () {},
            onCall: () {},
            onChat: () {},
          ),
          SizedBox(height: 14.h),
        ],

        const _SectionTitle(
          title: "Subject Teachers",
          icon: Icons.groups_rounded,
        ),
        SizedBox(height: 10.h),

        if (_subjectTeachers.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 30.h),
            child: Center(
              child: Text(
                "No subject teachers found",
                style: GoogleFonts.montserrat(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            ),
          )
        else
          ..._subjectTeachers.map((t) {
            return TeacherPremiumCard(
              name: t.name,
              photoUrl: t.photo,
              subjects: t.subjects.map((e) => e.name).toList(),
              onTap: () {},
              onCall: () {},
              onChat: () {},
            );
          }).toList(),
      ],
    );
  }
}

/* ===========================
   ✅ Premium Top Bar
=========================== */

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      child: Row(
        children: [
          _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          _GlassIconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

/* ===========================
   ✅ Premium Card
=========================== */

class TeacherPremiumCard extends StatelessWidget {
  final String name;
  final String photoUrl;
  final List<String> subjects;

  final String? badgeText;
  final Color? badgeColor;

  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const TeacherPremiumCard({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.subjects,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final ksBlue = AppColors.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: ksBlue.withOpacity(0.14)),
          ),
          child: Row(
            children: [
              _TeacherAvatar(
                name: name,
                photoUrl: photoUrl,
                size: 58,
                borderColor: ksBlue,
              ),
              SizedBox(width: 12.w),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF141414),
                            ),
                          ),
                        ),
                        // if (badgeText != null) ...[
                        //   SizedBox(width: 8.w),
                        //   Container(
                        //     padding: EdgeInsets.symmetric(
                        //         horizontal: 5.w, vertical: 2.h),
                        //     decoration: BoxDecoration(
                        //       color: (badgeColor ?? ksBlue).withOpacity(0.12),
                        //       borderRadius: BorderRadius.circular(999),
                        //       border: Border.all(
                        //         color:
                        //         (badgeColor ?? ksBlue).withOpacity(0.24),
                        //       ),
                        //     ),
                        //     child: Text(
                        //       badgeText!,
                        //       style: GoogleFonts.montserrat(
                        //         fontSize: 7.sp,
                        //         fontWeight: FontWeight.w900,
                        //         color: (badgeColor ?? ksBlue),
                        //       ),
                        //     ),
                        //   ),
                        // ],
                      ],
                    ),
                    SizedBox(height: 8.h),

                    if (subjects.isEmpty)
                      _InfoChip(
                        icon: Icons.menu_book_rounded,
                        text: "No subjects",
                        color: ksBlue,
                      )
                    else
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: subjects
                            .map((s) => _InfoChip(
                          icon: Icons.menu_book_rounded,
                          text: s,
                          color: ksBlue,
                        ))
                            .toList(),
                      ),
                  ],
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }
}

/* ===========================
   ✅ Avatar (Network + fallback)
=========================== */

class _TeacherAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double size;
  final Color borderColor;

  const _TeacherAvatar({
    required this.name,
    required this.photoUrl,
    required this.size,
    required this.borderColor,
  });

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r"\s+"));
    if (parts.isEmpty) return "T";
    if (parts.length == 1) {
      return parts.first.isEmpty
          ? "T"
          : parts.first.characters.first.toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.sp,
      width: size.sp,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor.withOpacity(0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl.isEmpty
            ? _FallbackAvatar(initials: _initials(name), color: borderColor)
            : Image.network(
          photoUrl,
          // fit: BoxFit.fill,
          errorBuilder: (_, __, ___) =>
              _FallbackAvatar(initials: _initials(name), color: borderColor),
        ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _FallbackAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F7FF),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.montserrat(
          fontSize: 16.sp,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

/* ===========================
   ✅ Chips / Buttons
=========================== */

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 170.w),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            height: 42.h,
            width: 42.h,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Icon(icon, color: Colors.white, size: 20.sp),
          ),
        ),
      ),
    );
  }
}

/* ===========================
   ✅ Sections + States
=========================== */

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 22.h,
          width: 22.h,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 14.sp, color: AppColors.primary),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 46.sp, color: Colors.redAccent),
            SizedBox(height: 10.h),
            Text(
              "Something went wrong",
              style: GoogleFonts.montserrat(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(
                "Retry",
                style: GoogleFonts.montserrat(
                  fontSize: 12.sp,
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
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  Widget _box({double? h, double? w, BorderRadius? r}) {
    return Container(
      height: h ?? 14.h,
      width: w ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: r ?? BorderRadius.circular(12.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Simple premium skeleton (without extra packages)
    return ListView(
      padding: EdgeInsets.all(12.w),
      children: List.generate(6, (i) {
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Container(
                height: 58.h,
                width: 58.h,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(h: 14.h, w: 200.w),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        _box(h: 26.h, w: 110.w, r: BorderRadius.circular(999)),
                        SizedBox(width: 8.w),
                        _box(h: 26.h, w: 90.w, r: BorderRadius.circular(999)),
                      ],
                    ),
                  ],
                ),
              ),

            ],
          ),
        );
      }),
    );
  }
}
