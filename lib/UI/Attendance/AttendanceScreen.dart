import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../constants.dart';
import '../Auth/login_screen.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String title;
  const AttendanceCalendarScreen({super.key, required this.title});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  bool isLoading = false;
  String? _error;

  final Map<DateTime, List<Map<String, dynamic>>> _attendanceRecords = {};
  final Set<DateTime> _highlightedDays = {};

  // Monthly totals (mini row)
  int monthPresent = 0;
  int monthAbsent = 0;
  int monthLeave = 0;
  int monthHoliday = 0;

  // ✅ Overall totals (From 01 April - Till Today) => API: root["total"]
  int totalSchoolDays = 0; // total.total_working
  int totalPresentDays = 0; // total.total_present
  int totalAbsentDays = 0; // total.total_absent
  int totalLeaveDays = 0; // total.total_leave
  int totalHolidayDays = 0; // not in api

  // ✅ current_month stored only (UI me show nahi)
  int currentWorking = 0;
  int currentPresent = 0;
  int currentAbsent = 0;
  int currentLeave = 0;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  int _safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _statusSymbol(int? status) {
    switch (status) {
      case 1:
        return 'P';
      case 2:
        return 'A';
      case 3:
        return 'L';
      case 4:
        return 'H';
      default:
        return '-';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'P':
        return Colors.green;
      case 'A':
        return Colors.red;
      case 'L':
        return Colors.blue;
      case 'H':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    return _attendanceRecords[_normalize(day)] ?? [];
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      isLoading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Optional: login redirect (if you want)
    // if (token == null || token.isEmpty) {
    //   if (!mounted) return;
    //   setState(() => isLoading = false);
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(builder: (_) => const LoginScreen()),
    //   );
    //   return;
    // }

    try {
      final uri = Uri.parse(
        '${ApiRoutes.attendance}?month=${_focusedDay.month}&year=${_focusedDay.year}',
      );

      final res = await http.get(
        uri,
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        setState(() {
          isLoading = false;
          _error = "Failed: ${res.statusCode}";
        });
        return;
      }

      final root = json.decode(res.body) as Map<String, dynamic>;

      final data = (root['data'] ?? {}) as Map<String, dynamic>;
      final currentMonth = (root['current_month'] ?? {}) as Map<String, dynamic>;
      final total = (root['total'] ?? {}) as Map<String, dynamic>;

      final attendance = data['attendance'];

      final Map<DateTime, List<Map<String, dynamic>>> tempRecords = {};
      final Set<DateTime> tempHighlighted = {};

      int mP = 0, mA = 0, mL = 0, mH = 0;

      void addRecord(DateTime date, int? statusCode, String rawDate) {
        final nd = _normalize(date);
        tempHighlighted.add(nd);

        tempRecords.putIfAbsent(nd, () => []);
        final s = _statusSymbol(statusCode);

        tempRecords[nd]!.add({
          "date": rawDate,
          "status": s,
          "status_code": statusCode ?? 0,
        });

        // Monthly counts by parsing attendance map (current focused month)
        if (nd.month == _focusedDay.month && nd.year == _focusedDay.year) {
          switch (s) {
            case 'P':
              mP++;
              break;
            case 'A':
              mA++;
              break;
            case 'L':
              mL++;
              break;
            case 'H':
              mH++;
              break;
          }
        }
      }

      // ✅ handle both map & list response formats
      if (attendance is Map) {
        attendance.forEach((k, v) {
          final raw = k.toString();
          final parsed = DateTime.parse(raw).toLocal();
          final map = (v ?? {}) as Map;
          addRecord(parsed, _safeInt(map['status']), raw);
        });
      } else if (attendance is List) {
        for (final item in attendance) {
          final it = (item ?? {}) as Map;
          final raw = (it['date'] ?? it['attendance_date'] ?? "").toString();
          if (raw.isEmpty) continue;
          final parsed = DateTime.parse(raw).toLocal();
          addRecord(parsed, _safeInt(it['status']), raw);
        }
      }

      // ✅ OVERALL TOTALS: root["total"]
      final tWorking = _safeInt(total['total_working']);
      final tPresent = _safeInt(total['total_present']);
      final tAbsent = _safeInt(total['total_absent']);
      final tLeave = _safeInt(total['total_leave']);

      // ✅ CURRENT MONTH TOTALS: root["current_month"] (stored only)
      final cWorking = _safeInt(currentMonth['total_working']);
      final cPresent = _safeInt(currentMonth['total_present']);
      final cAbsent = _safeInt(currentMonth['total_absent']);
      final cLeave = _safeInt(currentMonth['total_leave']);

      setState(() {
        _attendanceRecords
          ..clear()
          ..addAll(tempRecords);
        _highlightedDays
          ..clear()
          ..addAll(tempHighlighted);

        // ✅ Monthly mini row (attendance parsing based)
        monthPresent = mP;
        monthAbsent = mA;
        monthLeave = mL;
        monthHoliday = mH;

        // ✅ Overall section (From 01 April - Till Today)
        // If API gives working=0, we fallback to sum, but if ALL are 0 -> 0 will show (as you want)
        totalSchoolDays = tWorking == 0 ? (tPresent + tAbsent + tLeave) : tWorking;
        totalPresentDays = tPresent;
        totalAbsentDays = tAbsent;
        totalLeaveDays = tLeave;
        totalHolidayDays = 0;

        // ✅ stored only
        currentWorking =
        cWorking == 0 ? (cPresent + cAbsent + cLeave) : cWorking;
        currentPresent = cPresent;
        currentAbsent = cAbsent;
        currentLeave = cLeave;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        _error = "Error: $e";
      });
    }
  }

  Widget _miniLegendRow() {
    Widget item(String label, int value, Color c) {
      return SizedBox(
        width: 50.sp,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: c,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              "$value",
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: c,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final schoolDays = (monthPresent + monthAbsent + monthLeave + monthHoliday);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          item("School Days", schoolDays, Colors.grey.shade700),
          item("Present", monthPresent, Colors.green),
          item("Absent", monthAbsent, Colors.red),
          item("Leave", monthLeave, Colors.blue),
        ],
      ),
    );
  }

  Widget _overallSection() {
    Widget row(String title, int value, Color color) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 5.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Text(
              "$value",
              style: GoogleFonts.montserrat(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Column(
          children: [
            Text(
              "From 01 April - Till Today",
              style: GoogleFonts.montserrat(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8.h),
            Divider(height: 1, color: Colors.grey.shade300),
            row("Total School Days", totalSchoolDays, Colors.grey.shade800),
            row("Total present Days", totalPresentDays, Colors.green),
            row("Total Absent", totalAbsentDays, Colors.red),
            row("Total Leave", totalLeaveDays, Colors.blue),
          ],
        ),
      ),
    );
  }

  DateTime get _today => DateTime.now();

  DateTime get _fyStart {
    // Apr (4) se start hota hai
    final y = _today.year;
    return (_today.month >= 4) ? DateTime(y, 4, 1) : DateTime(y - 1, 4, 1);
  }

  DateTime get _fyEnd {
    // 31 March next year
    return DateTime(_fyStart.year + 1, 3, 31);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      // backgroundColor: AppColors.secondary,
      appBar: widget.title.isNotEmpty
          ? AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.secondary,
        title: Text(
          widget.title,
          style: GoogleFonts.montserrat(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Card(
                          color: Colors.white,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0.r),
                          ),
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: TableCalendar(
                              focusedDay: _focusedDay,
                              firstDay: _fyStart,   // ✅ auto: 01-04-YYYY
                              lastDay: _fyEnd,
                              calendarFormat: _calendarFormat,
                              availableCalendarFormats: const {
                                CalendarFormat.month: 'Month'
                              },
                              eventLoader: _eventsForDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              onPageChanged: (focusedDay) {
                                setState(() => _focusedDay = focusedDay);
                                _fetchAttendance(); // ✅ single api
                              },
                              headerStyle: HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                leftChevronIcon: Icon(Icons.chevron_left,
                                    size: 26.sp, color: Colors.black),
                                rightChevronIcon: Icon(Icons.chevron_right,
                                    size: 26.sp, color: Colors.black),
                                titleTextStyle: GoogleFonts.montserrat(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: GoogleFonts.montserrat(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                weekendStyle: GoogleFonts.montserrat(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.redAccent,
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: false,
                                todayDecoration: BoxDecoration(
                                  color: Colors.green.withOpacity(.18),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                selectedTextStyle: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                                defaultBuilder: (context, date, _) {
                                  final nd = _normalize(date);
                                  final has = _highlightedDays.contains(nd);
                                  final events = _eventsForDay(nd);
                                  final status = events.isNotEmpty
                                      ? (events.first['status'] ?? '-')
                                      : '-';
                                  final bg = has
                                      ? _statusColor(status.toString())
                                      : Colors.transparent;

                                  return Container(
                                    margin: EdgeInsets.all(6.w),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: bg == Colors.transparent
                                          ? null
                                          : bg.withOpacity(.70),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${date.day}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: has
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Card(
                          margin: EdgeInsets.zero,
                          color: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0.r),
                          ),
                          child: _miniLegendRow(),
                        ),
                        _overallSection(),
                        if (_error != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: Text(
                              _error!,
                              style: GoogleFonts.montserrat(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isLoading) ...[
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(color: Colors.black.withOpacity(.12)),
              ),
              const Center(child: CupertinoActivityIndicator(radius: 18)),
            ],
          ],
        ),
      ),
    );
  }
}