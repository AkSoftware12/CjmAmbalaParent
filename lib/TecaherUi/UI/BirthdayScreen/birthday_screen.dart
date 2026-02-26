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
      data: BirthdayData.fromJson(json['data'] ?? {}),
    );
  }
}

class BirthdayData {
  final List<TeacherBirthday> teacherBirthdays;
  final List<StudentBirthday> studentBirthdays;
  final List<UpcomingTeacherBirthday> upcomingTeacherBirthdays;
  final List<UpcomingStudentBirthday> upcomingStudentBirthdays;

  BirthdayData({
    required this.teacherBirthdays,
    required this.studentBirthdays,
    required this.upcomingTeacherBirthdays,
    required this.upcomingStudentBirthdays,
  });

  factory BirthdayData.fromJson(Map<String, dynamic> json) {
    return BirthdayData(
      teacherBirthdays: (json['today_teacher_birthdays'] as List? ?? [])
          .map((e) => TeacherBirthday.fromJson(e))
          .toList(),
      studentBirthdays: (json['today_student_birthdays'] as List? ?? [])
          .map((e) => StudentBirthday.fromJson(e))
          .toList(),

      upcomingTeacherBirthdays: (json['upcoming_teacher_birthdays'] as List? ?? [])
          .map((e) => UpcomingTeacherBirthday.fromJson(e))
          .toList(),
      upcomingStudentBirthdays: (json['upcoming_student_birthdays'] as List? ?? [])
          .map((e) => UpcomingStudentBirthday.fromJson(e))
          .toList(),
    );
  }
}

class TeacherBirthday {
  final int id;
  final String name;
  final String dob;
  final String photo;
  final String designation;

  TeacherBirthday({
    required this.id,
    required this.name,
    required this.dob,
    required this.photo,
    required this.designation,
  });

  factory TeacherBirthday.fromJson(Map<String, dynamic> json) {
    return TeacherBirthday(
      id: json['id'] ?? 0,
      name: json['first_name'] ?? '',
      dob: json['dob'] ?? '',
      photo: json['photo'] ?? '',
      designation: json['designation']?['title'] ?? '',
    );
  }
}
class UpcomingTeacherBirthday {
  final int id;
  final String name;
  final String dob;
  final String photo;
  final String designation;

  UpcomingTeacherBirthday({
    required this.id,
    required this.name,
    required this.dob,
    required this.photo,
    required this.designation,
  });

  factory UpcomingTeacherBirthday.fromJson(Map<String, dynamic> json) {
    return UpcomingTeacherBirthday(
      id: json['id'] ?? 0,
      name: json['first_name'] ?? '',
      dob: json['dob'] ?? '',
      photo: json['photo'] ?? '',
      designation: json['designation']?['title'] ?? '',
    );
  }
}
class UpcomingStudentBirthday {
  final int id;
  final String studentName;
  final String photo;
  final String dob;
  final String className;
  final String section;

  UpcomingStudentBirthday({
    required this.id,
    required this.studentName,
    required this.photo,
    required this.dob,
    required this.className,
    required this.section,
  });

  factory UpcomingStudentBirthday.fromJson(Map<String, dynamic> json) {
    return UpcomingStudentBirthday(
      id: json['id'] ?? 0,
      studentName: json['student']?['student_name'] ?? '',
      photo: json['student']?['picture_data'] ?? '',
      dob: json['student']?['dob'] ?? '',
      className: json['academic_class']?['title'] ?? '',
      section: json['section']?['title'] ?? '',
    );
  }
}

class StudentBirthday {
  final int id;
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
      id: json['id'] ?? 0,
      studentName: json['student']?['student_name'] ?? '',
      photo: json['student']?['picture_data'] ?? '',
      dob: json['student']?['dob'] ?? '',
      className: json['academic_class']?['title'] ?? '',
      section: json['section']?['title'] ?? '',
    );
  }
}

/// =======================
/// ✅ API SERVICE
/// =======================

class BirthdayApi {
  static Future<String> _getBestToken() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ yaha aapke app me jo keys hain wahi rakho
    final teacherToken = prefs.getString('teachertoken') ?? '';
    final studentToken = prefs.getString('studenttoken') ?? ''; // ✅ alag key
    final commonToken  = prefs.getString('token') ?? '';        // ✅ common fallback

    if (teacherToken.isNotEmpty) return teacherToken;
    if (studentToken.isNotEmpty) return studentToken;
    return commonToken;
  }

  static Future<BirthdayResponse> fetchBirthdays() async {
    final token = await _getBestToken();
    final url = Uri.parse(ApiRoutes.getBirthdays);

    final res = await http.get(
      url,
      headers: {
        "Accept": "application/json",
        if (token.isNotEmpty) "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      final jsonMap = json.decode(res.body) as Map<String, dynamic>;
      return BirthdayResponse.fromJson(jsonMap);
    } else {
      throw Exception("Failed: ${res.statusCode} ${res.body}");
    }
  }

  // ✅ screen ko token check karne me help
  static Future<String> currentToken() => _getBestToken();
}/// =======================
/// ✅ SCREEN (FULL UI)
/// =======================

class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({super.key});

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen>
    with WidgetsBindingObserver {
  late Future<BirthdayResponse> _future;
  String _lastToken = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    final t = await BirthdayApi.currentToken();
    _lastToken = t;
    setState(() {
      _future = BirthdayApi.fetchBirthdays();
    });
  }

  Future<void> _refresh() async {
    setState(() => _future = BirthdayApi.fetchBirthdays());
    await _future;
  }

  // ✅ app resume pe token change hua ho to auto reload
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkTokenAndReload();
    }
  }

  // ✅ navigation back aane pe bhi kaam aa jata hai (many cases)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkTokenAndReload();
  }

  Future<void> _checkTokenAndReload() async {
    final nowToken = await BirthdayApi.currentToken();
    if (nowToken != _lastToken) {
      _lastToken = nowToken;
      if (!mounted) return;
      setState(() {
        _future = BirthdayApi.fetchBirthdays();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

                  final teachers = data.teacherBirthdays;
                  final students = data.studentBirthdays;
                  final upcomingTeachers = data.upcomingTeacherBirthdays;
                  final upcomingStudents = data.upcomingStudentBirthdays;

                  if (teachers.isEmpty &&
                      students.isEmpty &&
                      upcomingTeachers.isEmpty &&
                      upcomingStudents.isEmpty) {
                    return const Center(
                      child: _EmptyView(
                        title: "No birthdays today 🎉",
                        subtitle: "Come back tomorrow!",
                      ),
                    );
                  }

                  // ✅ aapka existing UI same rahega (cards etc.)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (teachers.isNotEmpty) ...[
                        _SectionTitle(
                          title: "Teachers",
                          count: teachers.length,
                          icon: Icons.school_rounded,
                        ),
                        SizedBox(height: 10.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: teachers.length,
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 5.h,
                            crossAxisSpacing: 5.w,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) =>
                              _TeacherCard(item: teachers[i]),
                        ),
                        SizedBox(height: 18.h),
                      ],
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
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8.h,
                            crossAxisSpacing: 8.w,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) =>
                              _StudentCard(item: students[i]),
                        ),
                        SizedBox(height: 18.h),
                      ],
                      if (upcomingTeachers.isNotEmpty) ...[
                        _SectionTitle(
                          title: "Upcoming Teacher Birthdays",
                          count: upcomingTeachers.length,
                          icon: Icons.school_rounded,
                        ),
                        SizedBox(height: 10.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: upcomingTeachers.length,
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 5.h,
                            crossAxisSpacing: 5.w,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) => _UpcomingTeacherCard(
                            item: upcomingTeachers[i],
                          ),
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
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8.h,
                            crossAxisSpacing: 8.w,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) => _UpcomingStudentCard(
                            item: upcomingStudents[i],
                          ),
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

class _TeacherCard extends StatelessWidget {
  final TeacherBirthday item;
  const _TeacherCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);

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
            // TOP HEADER
            Container(
              height: 42.h,
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
                    "Teacher",
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
                  child: GestureDetector(
                    onTap: (){
                    },
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
                          // fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarFallback(size: 84.r),
                        ),
                      ),
                    ),
                  ),
                ),

                // TEXT
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                  child: Column(
                    children: [
                      Text(
                        item.name,
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
                        item.designation.isEmpty ? "Teaching Staff" : item.designation,
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
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                              // AppDateTimeUtils.date(item.dob),
                              'Today',
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
class _UpcomingTeacherCard extends StatelessWidget {
  final UpcomingTeacherBirthday item;
  const _UpcomingTeacherCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);

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
            // TOP HEADER
            Container(
              height: 42.h,
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
                    "Teacher",
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
                  child: GestureDetector(
                    onTap: (){
                    },
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
                          // fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarFallback(size: 84.r),
                        ),
                      ),
                    ),
                  ),
                ),

                // TEXT
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                  child: Column(
                    children: [
                      Text(
                        item.name,
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
                        item.designation.isEmpty ? "Teaching Staff" : item.designation,
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
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                              AppDateTimeUtils.date(item.dob),
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

    final subtitle = "${item.className}-${item.section}";

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
                  child: GestureDetector(
                    onTap: (){
                    },
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
                          // fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarFallback(size: 84.r),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                  child: Column(
                    children: [
                      Text(
                        item.studentName,
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
                        subtitle.trim().isEmpty ? "Student" : subtitle,
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
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              // AppDateTimeUtils.date(item.dob),
                              'Today',
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

    final subtitle = "${item.className}-${item.section}";

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
                  child: GestureDetector(
                    onTap: (){
                    },
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
                          // fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarFallback(size: 84.r),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                  child: Column(
                    children: [
                      Text(
                        item.studentName,
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
                        subtitle.trim().isEmpty ? "Student" : subtitle,
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
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              AppDateTimeUtils.date(item.dob),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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