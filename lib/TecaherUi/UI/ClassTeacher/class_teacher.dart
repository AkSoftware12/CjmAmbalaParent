import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'fullimageclassteacher.dart';

class ClassTeacher extends StatefulWidget {
  const ClassTeacher({super.key});

  @override
  State<ClassTeacher> createState() => _StaffProfileState();
}

class _StaffProfileState extends State<ClassTeacher> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<StaffMember> _staffList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _fetchStaff();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ If token required, uncomment and use below
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("teachertoken");

      final res = await http.get(
        Uri.parse(ApiRoutes.getClassTeachers),
        headers: {
          "Accept": "application/json",
          // if token needed:
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}");
      }

      final Map<String, dynamic> jsonMap = jsonDecode(res.body);

      final List list = (jsonMap["data"]?["class_teachers"] ?? []) as List;

      final parsed = list.map((e) => StaffMember.fromApi(e)).toList();

      setState(() {
        _staffList = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Something went wrong: $e";
        _loading = false;
      });
    }
  }

  List<StaffMember> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _staffList;

    return _staffList.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.designation.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7FB);
    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);

    final list = _filtered;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: red1,
        leading: const BackButton(color: Colors.white),
        title: Text(
          "Class Teachers",
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
        actions: [
          IconButton(
            onPressed: _fetchStaff,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Search
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 5.h, 5.w, 5.h),
              child: Container(
                height: 46.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.red.withOpacity(.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: Colors.black.withOpacity(.55), size: 20),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.montserrat(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: "Search by name / class-section...",
                          hintStyle: GoogleFonts.montserrat(
                            fontSize: 12.sp,
                            color: Colors.black.withOpacity(.42),
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _searchCtrl.clear(),
                        child: Padding(
                          padding: EdgeInsets.all(6.w),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: Colors.black.withOpacity(.55)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ✅ Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchStaff,
                child: Builder(
                  builder: (context) {
                    if (_loading) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 120.h),
                          Center(
                            child: CircularProgressIndicator(
                              color: red1,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Center(
                            child: Text(
                              "Loading teachers...",
                              style: GoogleFonts.montserrat(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(.55),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (_error != null) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 110.h),
                          Icon(Icons.wifi_off_rounded,
                              size: 48, color: Colors.black.withOpacity(.35)),
                          SizedBox(height: 10.h),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black.withOpacity(.70),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 14.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18.w),
                            child: SizedBox(
                              height: 44.h,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: red1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                ),
                                onPressed: _fetchStaff,
                                child: Text(
                                  "Try Again",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 120.h),
                          Icon(Icons.search_off_rounded,
                              size: 46, color: Colors.black.withOpacity(.35)),
                          SizedBox(height: 10.h),
                          Center(
                            child: Text(
                              "No staff found",
                              style: GoogleFonts.montserrat(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Text(
                                "Try searching by name or class-section.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(.55),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.fromLTRB(5.w, 5.h, 5.w, 5.h),
                      child: GridView.builder(
                        // physics: const BouncingScrollPhysics(
                        //   parent: AlwaysScrollableScrollPhysics(),
                        // ),
                        itemCount: list.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8.w,
                          mainAxisSpacing: 8.h,
                          childAspectRatio: 0.80,
                        ),
                        itemBuilder: (context, index) =>
                            _StaffCardRed(staff: list[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCardRed extends StatelessWidget {
  final StaffMember staff;
  const _StaffCardRed({required this.staff});

  @override
  Widget build(BuildContext context) {
    const red1 = Color(0xFFE53935);
    const red2 = Color(0xFFB71C1C);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF5F5)],
        ),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Stack(
          children: [
            // top header
            Container(
              height: 58.h,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [red1, red2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(right: -25, top: 12, child: _GlassSweep()),
                ],
              ),
            ),

            // ✅ Use Positioned instead of Expanded inside Stack
            Positioned.fill(
              top: 5.h,
              child: Padding(
                padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 5.h),
                child: Column(
                  children: [
                    // avatar
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullImageTeacher(
                                images: staff.imageUrl,
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 60.r,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: staff.imageUrl.isEmpty
                                ? _AvatarFallback(size: 84.r)
                                : Image.network(
                              staff.imageUrl,
                              width: 120.r,
                              height: 120.r,
                              // fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _AvatarFallback(size: 84.r),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),

                    Text(
                      staff.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2.h),

                    Container(
                      padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(
                          color: const Color(0xFFE53935).withOpacity(.20),
                        ),
                      ),
                      child: Text(
                        staff.designation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 11.2.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB71C1C),
                        ),
                      ),
                    ),


                    // SizedBox(
                    //   height: 25.h,
                    //   width: double.infinity,
                    //   child: DecoratedBox(
                    //     decoration: BoxDecoration(
                    //       borderRadius: BorderRadius.circular(14.r),
                    //       gradient: const LinearGradient(
                    //         colors: [red1, red2],
                    //         begin: Alignment.topLeft,
                    //         end: Alignment.bottomRight,
                    //       ),
                    //       boxShadow: [
                    //         BoxShadow(
                    //           color: red1.withOpacity(.22),
                    //           blurRadius: 16,
                    //           offset: const Offset(0, 10),
                    //         )
                    //       ],
                    //     ),
                    //     child: Center(
                    //       child: Text(
                    //         "View Profile",
                    //         style: GoogleFonts.montserrat(
                    //           fontSize: 12.sp,
                    //           fontWeight: FontWeight.w800,
                    //           color: Colors.white,
                    //           letterSpacing: .2,
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
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

class StaffMember {
  final int id;
  final String name;
  final String designation;
  final String imageUrl;

  const StaffMember({
    required this.id,
    required this.name,
    required this.designation,
    required this.imageUrl,
  });

  factory StaffMember.fromApi(Map<String, dynamic> e) {
    final teacher = (e["teacher"] ?? {}) as Map<String, dynamic>;

    final id = (teacher["id"] ?? 0) as int;
    final name = (teacher["first_name"] ?? "").toString();

    final classSection = (e["class_section"] ?? "").toString();
    final designation = classSection.isEmpty ? "Class Teacher" : classSection;

    final photo = teacher["photo"];
    final imageUrl = (photo == null) ? "" : photo.toString();

    return StaffMember(
      id: id,
      name: name,
      designation: designation,
      imageUrl: imageUrl,
    );
  }
}

class _GlassSweep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.35,
      child: Container(
        width: 150.w,
        height: 42.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.14),
          borderRadius: BorderRadius.circular(18.r),
        ),
      ),
    );
  }
}