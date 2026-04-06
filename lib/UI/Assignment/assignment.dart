import 'package:avi/UI/Assignment/upload_assignments.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../../constants.dart';
import 'package:html/parser.dart' as html_parser;
import '../Auth/login_screen.dart';
import 'full_assignment.dart';

class AssignmentListScreen extends StatefulWidget {
  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = false;
  List assignments = [];
  late AnimationController _animController;

  static const Color kPrimary = Color(0xFFB71C1C);
  static const Color kAccent = Color(0xFFFF8F00);
  static const Color kBg = Color(0xFFF5F5F5);
  static const Color kTextDark = Color(0xFF1A1A2E);
  static const Color kTextMid = Color(0xFF5C5C7A);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    fetchAssignmentsData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> fetchAssignmentsData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiRoutes.getAssignments),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        assignments = jsonResponse['data'];
        isLoading = false;
      });
      _animController
        ..reset()
        ..forward();
    } else {
      setState(() => isLoading = false);
    }
  }


  String _formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) return "N/A";
      return DateFormat('dd - MM - yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          /// ── Sliver AppBar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 40.h,
            pinned: false,
            stretch: false,
            backgroundColor: Colors.red,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text('Assignments',style: TextStyle(color: Colors.white),),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: fetchAssignmentsData,
              ),
              SizedBox(width: 4.w),
            ],
          ),

          /// ── Body ───────────────────────────────────────────────
          if (isLoading)
            const SliverFillRemaining(
              child: WhiteCircularProgressWidget(),
            )
          else if (assignments.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: DataNotFoundWidget(
                  title: 'Assignments Not Available.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final delay = index * 0.08;
                    final animation = CurvedAnimation(
                      parent: _animController,
                      curve: Interval(
                        delay.clamp(0.0, 0.9),
                        (delay + 0.4).clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.18),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _AssignmentCard(
                        assignment: assignments[index],
                        index: index,
                        formatDate: _formatDate,
                        kPrimary: kPrimary,
                        kAccent: kAccent,
                        kTextDark: kTextDark,
                        kTextMid: kTextMid,
                      ),
                    );
                  },
                  childCount: assignments.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Assignment Card Widget
// ─────────────────────────────────────────────────────────────
class _AssignmentCard extends StatelessWidget {
  final dynamic assignment;
  final int index;
  final String Function(String?) formatDate;
  final Color kPrimary, kAccent, kTextDark, kTextMid;

  const _AssignmentCard({
    required this.assignment,
    required this.index,
    required this.formatDate,
    required this.kPrimary,
    required this.kAccent,
    required this.kTextDark,
    required this.kTextMid,
  });

  @override
  Widget build(BuildContext context) {
    final rawDesc = assignment['description'];
    final descString = (rawDesc == null) ? '' : rawDesc.toString();
    final description =
        html_parser.parse(descString).body?.text.trim() ?? '';

    final String startDate = formatDate(assignment['start_date']);
    final String endDate = formatDate(assignment['due_date']);
    final bool isSubmitted = assignment['attendance_status'] == 'submitted';

    final List<Color> cardColors = [
      const Color(0xFFB71C1C),
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFF6A1B9A),
      const Color(0xFFE65100),
      const Color(0xFF00695C),
    ];
    final Color cardAccent = cardColors[index % cardColors.length];

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: cardAccent.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: Column(
          children: [
            /// Colored top strip
            Container(
              height: 3.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cardAccent, cardAccent.withOpacity(0.4)],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Number badge
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cardAccent,
                              cardAccent.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment['title'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: kTextDark,
                                height: 1.3,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              // ExpandableText(
                              //   text: description,
                              // )
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5.sp,
                                  color: kTextMid,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Status chip
                      _StatusChip(isSubmitted: isSubmitted),
                    ],
                  ),

                  SizedBox(height: 8.h),

                  /// Date row
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8FC),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _DateChip(
                          icon: Icons.calendar_today_rounded,
                          label: 'Start',
                          date: startDate,
                          color: const Color(0xFF1565C0),
                        ),
                        Container(
                          width: 1,
                          height: 32.h,
                          color: Colors.grey.shade300,
                          margin: EdgeInsets.symmetric(horizontal: 12.w),
                        ),
                        _DateChip(
                          icon: Icons.event_busy_rounded,
                          label: 'Due',
                          date: endDate,
                          color: kPrimary,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8.h),

                  /// Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'View',
                          icon: Icons.visibility_rounded,
                          color: const Color(0xFF1565C0),
                          onTap: () async {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignmentDetailScreen(
                                  assignment: assignment, // aapka JSON map
                                ),
                              ),
                            );

                          },
                        ),
                      ),
                      if (!isSubmitted) ...[
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _ActionButton(
                            label: 'Upload',
                            icon: Icons.upload_rounded,
                            color: kAccent,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AssignmentUploadScreen(
                                        onReturn: () {},
                                        id: assignment['id'].toString(),
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

// ─────────────────────────────────────────────────────────────
//  Small Widgets
// ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isSubmitted;
  const _StatusChip({required this.isSubmitted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: isSubmitted
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isSubmitted
              ? const Color(0xFF2E7D32)
              : const Color(0xFFB71C1C),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSubmitted
                ? Icons.check_circle_rounded
                : Icons.pending_rounded,
            size: 12.sp,
            color: isSubmitted
                ? const Color(0xFF2E7D32)
                : const Color(0xFFB71C1C),
          ),
          SizedBox(width: 4.w),
          Text(
            isSubmitted ? 'Done' : 'Pending',
            style: GoogleFonts.poppins(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: isSubmitted
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFB71C1C),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final Color color;

  const _DateChip({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                date,
                style: GoogleFonts.poppins(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15.sp, color: color),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class ExpandableText extends StatefulWidget {
  final String text;

  const ExpandableText({super.key, required this.text});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: isExpanded ? null : 1, // 👈 yaha 2 lines
          overflow:
          isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 11.5.sp,
            color: Colors.black,
            height: 1.5,
          ),
        ),

        GestureDetector(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              isExpanded ? "See Less" : "See More",
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}