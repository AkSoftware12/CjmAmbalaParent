import 'package:avi/TecaherUi/UI/Assignment/update_assignments.dart';
import 'package:avi/TecaherUi/UI/Assignment/upload_assignments.dart' show AssignmentUploadScreen;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../CommonCalling/data_not_found.dart';
import '../../../constants.dart';
import 'package:html/parser.dart' as html_parser;
import 'assinment_detail.dart';

class AssignmentListScreen extends StatefulWidget {
  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  bool isLoading = true;
  List assignments = [];

  static const Color _red = Color(0xFFB71C1C);
  static const Color _redDark = Color(0xFF7F0000);
  static const Color _redLight = Color(0xFFEF5350);
  static const Color _redBg = Color(0xFFFFF5F5);
  static const Color _redTint = Color(0xFFFFEBEE);

  @override
  void initState() {
    super.initState();
    fetchAssignmentsData();
  }

  // ✅ FIX: Simple call, no setState wrapping
  void _refresh() {
    fetchAssignmentsData();
  }

  Future<void> fetchAssignmentsData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getTeacherAssignments),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final j = json.decode(response.body);
        if (mounted) setState(() { assignments = j['data']; isLoading = false; });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        title: Text(
          'Assignments',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 5.sp),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                _slideRoute(AssignmentUploadScreen(onReturn: _refresh)),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 5.sp),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: _red, size: 18.sp),
                  SizedBox(width: 5.sp),
                  Text('Create',
                      style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: _red)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(
                child: CupertinoActivityIndicator(radius: 18.sp, color: _red))
                : assignments.isEmpty
                ? Center(
                child: DataNotFoundWidget(
                    title: 'No Assignments Available.'))
                : ListView.builder(
              itemCount: assignments.length,
              padding: EdgeInsets.fromLTRB(8.sp, 8.sp, 8.sp, 8.sp),
              itemBuilder: (context, index) {
                final a = assignments[index];
                final String description =
                    html_parser.parse(a['description']).body?.text ?? '';

                final String startDate = (a['start_date'] != null &&
                    a['start_date'].toString().isNotEmpty)
                    ? DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(a['start_date']))
                    : 'N/A';
                final String endDate = (a['end_date'] != null &&
                    a['end_date'].toString().isNotEmpty)
                    ? DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(a['end_date']))
                    : 'N/A';
                final bool isExpired = a['end_date'] != null &&
                    DateTime.tryParse(a['end_date'].toString()) != null &&
                    DateTime.parse(a['end_date'].toString())
                        .isBefore(DateTime.now());

                return Container(
                  margin: EdgeInsets.only(bottom: 14.sp),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          width: 1, color: Colors.grey.shade300)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8.sp),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // Index + Title + Status
                              Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40.sp,
                                      height: 40.sp,
                                      decoration: BoxDecoration(
                                        gradient: isExpired
                                            ? null
                                            : const LinearGradient(
                                          colors: [
                                            Colors.red,
                                            Colors.red
                                          ],
                                          begin:
                                          Alignment.topLeft,
                                          end: Alignment
                                              .bottomRight,
                                        ),
                                        color: isExpired
                                            ? Colors.grey.shade200
                                            : null,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        boxShadow: isExpired
                                            ? []
                                            : [
                                          BoxShadow(
                                              color: _red
                                                  .withOpacity(
                                                  0.35),
                                              blurRadius: 8,
                                              offset:
                                              const Offset(
                                                  0, 3)),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.sp,
                                            fontWeight:
                                            FontWeight.w800,
                                            color: isExpired
                                                ? Colors.grey
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.sp),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                          children: [
                                            Text(
                                              a['title'].toString(),
                                              style:
                                              GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                fontWeight:
                                                FontWeight.w700,
                                                color: const Color(
                                                    0xFF1A0000),
                                                height: 1.35,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow
                                                  .ellipsis,
                                            ),
                                            if (description
                                                .isNotEmpty) ...[
                                              SizedBox(height: 2.sp),
                                              Text(
                                                description,
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                style: GoogleFonts
                                                    .poppins(
                                                    fontSize:
                                                    11.sp,
                                                    color: Colors
                                                        .grey
                                                        .shade500),
                                              ),
                                            ],
                                          ]),
                                    ),
                                    SizedBox(width: 8.sp),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 9.sp,
                                          vertical: 4.sp),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? Colors.grey.shade100
                                            : Colors.green.shade100,
                                        borderRadius:
                                        BorderRadius.circular(20),
                                        border: Border.all(
                                            color: isExpired
                                                ? Colors.grey.shade300
                                                : Colors.green),
                                      ),
                                      child: Row(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration:
                                              BoxDecoration(
                                                shape:
                                                BoxShape.circle,
                                                color: isExpired
                                                    ? Colors.grey
                                                    : Colors.green,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isExpired
                                                  ? 'Expired'
                                                  : 'Active',
                                              style:
                                              GoogleFonts.poppins(
                                                fontSize: 9.sp,
                                                fontWeight:
                                                FontWeight.w700,
                                                color: isExpired
                                                    ? Colors
                                                    .grey.shade500
                                                    : Colors.green,
                                              ),
                                            ),
                                          ]),
                                    ),
                                  ]),

                              SizedBox(height: 8.sp),

                              // Dates
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12.sp, vertical: 0.sp),
                                decoration: BoxDecoration(
                                  color: _redBg,
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  border:
                                  Border.all(color: _redTint),
                                ),
                                child: Row(children: [
                                  Expanded(
                                    child: Row(children: [
                                      Icon(
                                          Icons
                                              .play_circle_fill_rounded,
                                          size: 15.sp,
                                          color: _red),
                                      SizedBox(width: 6.sp),
                                      Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                          children: [
                                            Text('Start Date',
                                                style: GoogleFonts
                                                    .poppins(
                                                    fontSize:
                                                    9.sp,
                                                    color: Colors
                                                        .grey
                                                        .shade400,
                                                    fontWeight:
                                                    FontWeight
                                                        .w500)),
                                            Text(startDate,
                                                style: GoogleFonts
                                                    .poppins(
                                                    fontSize:
                                                    11.sp,
                                                    fontWeight:
                                                    FontWeight
                                                        .w700,
                                                    color: const Color(
                                                        0xFF1A0000))),
                                          ]),
                                    ]),
                                  ),
                                  Container(
                                      height: 32.sp,
                                      width: 1,
                                      color: _redTint),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          left: 12.sp),
                                      child: Row(children: [
                                        Icon(Icons.flag_rounded,
                                            size: 15.sp,
                                            color: isExpired
                                                ? Colors.grey.shade400
                                                : _redLight),
                                        SizedBox(width: 6.sp),
                                        Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                            children: [
                                              Text('Due Date',
                                                  style: GoogleFonts
                                                      .poppins(
                                                      fontSize:
                                                      9.sp,
                                                      color: Colors
                                                          .grey
                                                          .shade400,
                                                      fontWeight:
                                                      FontWeight
                                                          .w500)),
                                              Text(endDate,
                                                  style: GoogleFonts
                                                      .poppins(
                                                      fontSize:
                                                      11.sp,
                                                      fontWeight:
                                                      FontWeight
                                                          .w700,
                                                      color: const Color(
                                                          0xFF1A0000))),
                                            ]),
                                      ]),
                                    ),
                                  ),
                                ]),
                              ),

                              SizedBox(height: 8.sp),

                              // Action Buttons
                              Row(children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                AssignmentDetailScreen(
                                                    id: a['id']))),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 5.sp),
                                      decoration: BoxDecoration(
                                          color: const Color(
                                              0xFFE3F2FD),
                                          borderRadius:
                                          BorderRadius.circular(
                                              12)),
                                      child: Column(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [
                                            Icon(Icons.info_rounded,
                                                color: const Color(
                                                    0xFF1565C0),
                                                size: 15.sp),
                                            Text('Report',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 9.sp,
                                                    fontWeight:
                                                    FontWeight
                                                        .w700,
                                                    color: const Color(
                                                        0xFF1565C0))),
                                          ]),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 7.sp),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final url =
                                      a['attach_url'].toString();
                                      if (await canLaunchUrl(
                                          Uri.parse(url))) {
                                        await launchUrl(
                                            Uri.parse(url),
                                            mode: LaunchMode
                                                .externalApplication);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: const Text(
                                                  'Could not open file'),
                                              backgroundColor: _red,
                                              behavior: SnackBarBehavior
                                                  .floating,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                      10))),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 5.sp),
                                      decoration: BoxDecoration(
                                          color: const Color(
                                              0xFFE8F5E9),
                                          borderRadius:
                                          BorderRadius.circular(
                                              12)),
                                      child: Column(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [
                                            Icon(
                                                Icons
                                                    .open_in_new_rounded,
                                                color: const Color(
                                                    0xFF2E7D32),
                                                size: 15.sp),
                                            Text('View',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 9.sp,
                                                    fontWeight:
                                                    FontWeight
                                                        .w700,
                                                    color: const Color(
                                                        0xFF2E7D32))),
                                          ]),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 7.sp),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showUpdateDialog(
                                      a['id'],
                                      a['start_date'].toString(),
                                      a['end_date'].toString(),
                                      a['title'].toString(),
                                      a['description'].toString(),
                                      a['total_marks'].toString(),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 5.sp),
                                      decoration: BoxDecoration(
                                          color: const Color(
                                              0xFFFFF3E0),
                                          borderRadius:
                                          BorderRadius.circular(
                                              12)),
                                      child: Column(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded,
                                                color: const Color(
                                                    0xFFE65100),
                                                size: 15.sp),
                                            Text('Edit',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 9.sp,
                                                    fontWeight:
                                                    FontWeight
                                                        .w700,
                                                    color: const Color(
                                                        0xFFE65100))),
                                          ]),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 7.sp),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showDeleteDialog(
                                        a['id'].toString()),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 5.sp),
                                      decoration: BoxDecoration(
                                          color: _redTint,
                                          borderRadius:
                                          BorderRadius.circular(
                                              12)),
                                      child: Column(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [
                                            Icon(
                                                Icons.delete_rounded,
                                                color: _red,
                                                size: 15.sp),
                                            Text('Delete',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 9.sp,
                                                    fontWeight:
                                                    FontWeight
                                                        .w700,
                                                    color: _red)),
                                          ]),
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(22.sp),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60.sp,
              height: 60.sp,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_redDark, _red],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _red.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Icon(Icons.delete_forever_rounded,
                  color: Colors.white, size: 28.sp),
            ),
            SizedBox(height: 14.sp),
            Text('Delete Assignment',
                style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A0000)),
                textAlign: TextAlign.center),
            SizedBox(height: 6.sp),
            Text('This action cannot be undone. Are you sure?',
                style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                    height: 1.5),
                textAlign: TextAlign.center),
            SizedBox(height: 22.sp),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 12.sp),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                ),
              ),
              SizedBox(width: 10.sp),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient:
                    const LinearGradient(colors: [_redDark, _red]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: _red.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteAssignment(id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12.sp),
                    ),
                    child: Text('Delete',
                        style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showUpdateDialog(
      int id, String start, String end, String title, String desc, String marks) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(22.sp),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60.sp,
              height: 60.sp,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFE65100), Color(0xFFF4511E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFE65100).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child:
              Icon(Icons.edit_rounded, color: Colors.white, size: 28.sp),
            ),
            SizedBox(height: 14.sp),
            Text('Update Assignment',
                style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A0000)),
                textAlign: TextAlign.center),
            SizedBox(height: 6.sp),
            Text('Open editor to make changes to this assignment?',
                style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                    height: 1.5),
                textAlign: TextAlign.center),
            SizedBox(height: 22.sp),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 12.sp),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                ),
              ),
              SizedBox(width: 10.sp),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFF4511E)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFE65100).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          _slideRoute(AssignmentUpdateScreen(
                            onReturn: _refresh,
                            startDate: start,
                            endDate: end,
                            id: id,
                            title: title,
                            descripation: desc,
                            marks: marks,
                          )));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12.sp),
                    ),
                    child: Text('Edit Now',
                        style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteAssignment(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');
      final res = await http.get(
        Uri.parse('${ApiRoutes.deleteTeacherAssignment}/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Assignment deleted!',
                  style: GoogleFonts.poppins(fontSize: 13.sp)),
            ]),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(14.sp),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          _refresh();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to delete',
                style: GoogleFonts.poppins(fontSize: 13.sp)),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(14.sp),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error while deleting',
              style: GoogleFonts.poppins(fontSize: 13.sp)),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(14.sp),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  PageRouteBuilder _slideRoute(Widget page) => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOut))
          .animate(anim),
      child: child,
    ),
  );
}