import 'dart:convert';
import 'package:avi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants.dart';

/// =======================
/// ✅ MODELS
/// =======================

class BirthdayResponse {
  final bool success;
  final String message;
  final BirthdayData data;

  BirthdayResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory BirthdayResponse.fromJson(Map<String, dynamic> json) {
    return BirthdayResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: BirthdayData.fromJson((json['data'] ?? {}) as Map<String, dynamic>),
    );
  }
}

class BirthdayData {
  final List<StudentBirthday> studentBirthdays;
  final List<UpcomingStudentBirthday> upcomingStudentBirthdays;

  BirthdayData({
    required this.studentBirthdays,
    required this.upcomingStudentBirthdays,
  });

  factory BirthdayData.fromJson(Map<String, dynamic> json) {
    // ✅ backend key mismatch safe
    List _listFromAny(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is List) return v;
      }
      return const [];
    }

    final todayList = _listFromAny([
      'today_student_birthdays',
      'today_students_birthdays',
      'student_birthdays',
    ]);

    final upcomingList = _listFromAny([
      'upcoming_student_birthdays',
      'upcoming_students_birthdays',
      'upcoming_birthdays',
    ]);

    return BirthdayData(
      studentBirthdays: todayList
          .map((e) => StudentBirthday.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      upcomingStudentBirthdays: upcomingList
          .map((e) =>
          UpcomingStudentBirthday.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// ✅ helper: nested safe string pick
String _pickString(Map? a, List<List<String>> paths) {
  for (final path in paths) {
    dynamic cur = a;
    bool ok = true;
    for (final key in path) {
      if (cur is Map && cur.containsKey(key)) {
        cur = cur[key];
      } else {
        ok = false;
        break;
      }
    }
    if (ok && cur != null) {
      final s = cur.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return "";
}

class StudentBirthday {
  final String id; // ✅ now String (student_id)
  final String studentName;
  final String photo;
  final String dob;
  final String className;
  final String section;

  StudentBirthday({
    required this.id,
    required this.studentName,
    required this.photo,
    required this.dob,
    required this.className,
    required this.section,
  });

  factory StudentBirthday.fromJson(Map<String, dynamic> json) {
    return StudentBirthday(
      // ✅ upcoming me "student_id" aata hai
      id: _pickString(json, [
        ['id'],
        ['student_id'],
        ['student', 'student_id'],
      ]),
      studentName: _pickString(json, [
        ['student_name'],
        ['student', 'student_name'],
        ['name'],
      ]),
      photo: _pickString(json, [
        ['picture_data'],          // ✅ your upcoming has this full url
        ['photo'],
        ['student', 'picture_data'],
        ['student', 'photo'],
        ['student', 'image'],
      ]),
      dob: _pickString(json, [
        ['dob'],
        ['student', 'dob'],
        ['date_of_birth'],
      ]),
      // ✅ class/section upcoming me current_enrolled ke andar hai
      className: _pickString(json, [
        ['current_enrolled', 'academic_class', 'title'],
        ['academic_class', 'title'],
        ['class', 'title'],
        ['class_name'],
      ]),
      section: _pickString(json, [
        ['current_enrolled', 'section', 'title'],
        ['section', 'title'],
        ['section_name'],
      ]),
    );
  }
}

class UpcomingStudentBirthday extends StudentBirthday {
  UpcomingStudentBirthday({
    required super.id,
    required super.studentName,
    required super.photo,
    required super.dob,
    required super.className,
    required super.section,
  });

  factory UpcomingStudentBirthday.fromJson(Map<String, dynamic> json) {
    final s = StudentBirthday.fromJson(json);
    return UpcomingStudentBirthday(
      id: s.id,
      studentName: s.studentName,
      photo: s.photo,
      dob: s.dob,
      className: s.className,
      section: s.section,
    );
  }
}

/// =======================
/// ✅ API SERVICE
/// =======================

class BirthdayApi {
  static Future<BirthdayResponse> fetchBirthdays() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ normal + fallback (agar teacher token set hai)
    final token = (prefs.getString('token') ?? "").trim();
    final url = Uri.parse(ApiRoutes.getBirthdays);

    final res = await http.get(
      url,
      headers: {
        "Accept": "application/json",
         "Authorization": "Bearer $token",
      },
    );

    // ✅ debug
    debugPrint("Birthday API status: ${res.statusCode}");
    debugPrint("Birthday API body: ${res.body}");

    if (res.statusCode == 200) {
      final jsonMap = json.decode(res.body) as Map<String, dynamic>;
      return BirthdayResponse.fromJson(jsonMap);
    } else {
      throw Exception("Failed: ${res.statusCode} ${res.body}");
    }
  }
}

/// =======================
/// ✅ SCREEN (FULL UI)
/// =======================

class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({super.key});

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  late Future<BirthdayResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = BirthdayApi.fetchBirthdays();
  }

  Future<void> _refresh() async {
    setState(() => _future = BirthdayApi.fetchBirthdays());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);
    const bg = Color(0xFFF6F7FB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: red1,
        leading: const BackButton(color: Colors.white),
        title: Text(
          "Today's Birthdays",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 14.sp,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [red1, red2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
              child: FutureBuilder<BirthdayResponse>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _LoadingView();
                  }

                  if (snap.hasError) {
                    return _ErrorView(
                      error: snap.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final data = snap.data?.data;
                  if (data == null) {
                    return const _EmptyView(title: "No data found");
                  }

                  final students = data.studentBirthdays;
                  final upcomingStudents = data.upcomingStudentBirthdays;

                  if (students.isEmpty && upcomingStudents.isEmpty) {
                    return const Center(
                      child: _EmptyView(
                        title: "No birthdays today 🎉",
                        subtitle: "Come back tomorrow!",
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (students.isNotEmpty) ...[
                        _SectionTitle(
                          title: "Students",
                          count: students.length,
                          icon: Icons.emoji_people_rounded,
                        ),
                        SizedBox(height: 10.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8.h,
                            crossAxisSpacing: 8.w,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) {
                            return _StudentCard(item: students[i]);
                          },
                        ),
                        SizedBox(height: 18.h),
                      ],
                      if (upcomingStudents.isNotEmpty) ...[
                        _SectionTitle(
                          title: "Upcoming Students Birthdays",
                          count: upcomingStudents.length,
                          icon: Icons.emoji_people_rounded,
                        ),
                        SizedBox(height: 10.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: upcomingStudents.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8.h,
                            crossAxisSpacing: 8.w,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) {
                            return _UpcomingStudentCard(item: upcomingStudents[i]);
                          },
                        ),
                        SizedBox(height: 18.h),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// ✅ UI WIDGETS
/// =======================

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE53935);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: red.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: red, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: red.withOpacity(.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            "$count",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              color: red,
              fontSize: 12.sp,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final double size;
  const _AvatarFallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFF3F4F6),
      child: Icon(Icons.person_rounded,
          size: size * 0.55, color: Colors.black.withOpacity(.35)),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentBirthday item;
  const _StudentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);

    final subtitle = "${item.className}-${item.section}".trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.black.withOpacity(.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Stack(
          children: [
            Container(
              height: 52.h,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [red1, red2],
                ),
              ),
            ),
            Column(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Student",
                    style: GoogleFonts.montserrat(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFB71C1C)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.12),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 55.r,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: item.photo.isEmpty
                          ? _AvatarFallback(size: 84.r)
                          : Image.network(
                        item.photo,
                        width: 100.r,
                        height: 100.r,
                        fit: BoxFit.cover, // ✅ FIX
                        errorBuilder: (_, __, ___) =>
                            _AvatarFallback(size: 84.r),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                  child: Column(
                    children: [
                      Text(
                        item.studentName.isEmpty ? "Student" : item.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle.isEmpty ? "Student" : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withOpacity(.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cake_rounded,
                                size: 16, color: Color(0xFFE53935)),
                            const SizedBox(width: 6),
                            Text(
                              "Today",
                              style: GoogleFonts.montserrat(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE53935),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingStudentCard extends StatelessWidget {
  final UpcomingStudentBirthday item;
  const _UpcomingStudentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);

    final subtitle = [
      item.className.trim(),
      item.section.trim(),
    ].where((e) => e.isNotEmpty).join("-");

    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
          border: Border.all(color: Colors.black.withOpacity(.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: Center(
            child: Stack(
              children: [
                Container(
                  height: 52.h,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [red1, red2],
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFB71C1C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.12),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55.r,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: item.photo.isEmpty
                                ? _AvatarFallback(size: 84.r)
                                : Image.network(
                              item.photo,
                              width: 100.r,
                              height: 100.r,
                              fit: BoxFit.cover, // ✅ FIX
                              errorBuilder: (_, __, ___) =>
                                  _AvatarFallback(size: 84.r),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                        child: Column(
                          children: [
                            Text(
                              item.studentName.isEmpty ? "Student" : item.studentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              subtitle.isEmpty ? "Student" : subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935).withOpacity(.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cake_rounded,
                                      size: 16, color: Color(0xFFE53935)),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.dob.isEmpty
                                        ? "Upcoming"
                                        : AppDateTimeUtils.date(item.dob),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFE53935),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          SizedBox(height: 30.h),
          const Center(child: CircularProgressIndicator()),
          SizedBox(height: 14.h),
          Text(
            "Loading birthdays...",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          )
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _EmptyView({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          SizedBox(height: 30.h),
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.cake_rounded,
                color: Color(0xFFE53935), size: 32),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 6.h),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
          SizedBox(height: 80.h),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          SizedBox(height: 30.h),
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.error_outline,
                color: Color(0xFFE53935), size: 34),
          ),
          SizedBox(height: 12.h),
          Text(
            "Something went wrong",
            style: GoogleFonts.montserrat(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            error,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 12.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: onRetry,
            child: Text(
              "Retry",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }
}