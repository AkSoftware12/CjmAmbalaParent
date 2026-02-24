import 'dart:convert';

import 'package:avi/utils/date_time_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;

import '../../HexColorCode/HexColor.dart';
import '../../constants.dart';

class CalendarScreen extends StatefulWidget {
  final String title;
  const CalendarScreen({super.key, required this.title});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarFormat _calendarFormat;

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  // ✅ IMPORTANT: lastDay must be >= focusedDay, otherwise TableCalendar assertion fails
  final DateTime _firstDay = DateTime(2025, 1, 1);
  final DateTime _lastDay = DateTime(2050, 12, 31);

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  Set<DateTime> _highlightedDays = {};
  List<Map<String, dynamic>> _monthlyEvents = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;

    // ✅ Clamp focused/selected day within range
    if (_focusedDay.isBefore(_firstDay)) _focusedDay = _firstDay;
    if (_focusedDay.isAfter(_lastDay)) _focusedDay = _lastDay;

    if (_selectedDay.isBefore(_firstDay)) _selectedDay = _firstDay;
    if (_selectedDay.isAfter(_lastDay)) _selectedDay = _lastDay;

    _fetchEvents();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _fetchEvents() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // ✅ If token missing, stop loader (you can redirect to login if you want)
      if (token == null || token.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(ApiRoutes.events),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> events = (data['events'] ?? []) as List<dynamic>;

        final Map<DateTime, List<Map<String, dynamic>>> tempEvents = {};
        final Set<DateTime> tempHighlightedDays = {};
        final Set<int> uniqueEventIds = {};
        final List<Map<String, dynamic>> tempMonthlyEvents = [];

        for (final e in events) {
          final Map<String, dynamic> event = Map<String, dynamic>.from(e);

          // ✅ Safety parsing
          if (event['start_date'] == null || event['end_date'] == null) continue;

          DateTime startDate = DateTime.parse(event['start_date']).toLocal();
          DateTime endDate = DateTime.parse(event['end_date']).toLocal();

          startDate = _normalize(startDate);
          endDate = _normalize(endDate);

          // ✅ ensure end >= start
          if (endDate.isBefore(startDate)) {
            final tmp = startDate;
            startDate = endDate;
            endDate = tmp;
          }

          // ✅ add all days in range
          for (DateTime date = startDate;
          !date.isAfter(endDate);
          date = date.add(const Duration(days: 1))) {
            final normalizedDate = _normalize(date);
            tempHighlightedDays.add(normalizedDate);

            tempEvents.putIfAbsent(normalizedDate, () => []);
            tempEvents[normalizedDate]!.add(event);
          }

          // ✅ add unique monthly list items (for focused month)
          final int? id = event['id'] is int
              ? event['id']
              : int.tryParse((event['id'] ?? '').toString());

          if (_focusedDay.month == startDate.month &&
              _focusedDay.year == startDate.year) {
            if (id == null) {
              // no id? then still include but avoid duplicate by name+date key (optional)
              tempMonthlyEvents.add(event);
            } else if (!uniqueEventIds.contains(id)) {
              uniqueEventIds.add(id);
              tempMonthlyEvents.add(event);
            }
          }
        }

        setState(() {
          _events = tempEvents;
          _highlightedDays = tempHighlightedDays;
          _monthlyEvents = tempMonthlyEvents;
          isLoading = false;
        });
      } else {
        // ✅ stop loader on non-200
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[_normalize(day)] ?? [];
  }

  void _updateMonthlyEvents(DateTime newMonth) {
    final Set<int> uniqueEventIds = {};
    final List<Map<String, dynamic>> tempMonthlyEvents = [];

    _events.forEach((date, events) {
      if (date.month == newMonth.month && date.year == newMonth.year) {
        for (final event in events) {
          final int? id = event['id'] is int
              ? event['id']
              : int.tryParse((event['id'] ?? '').toString());

          if (id == null) {
            tempMonthlyEvents.add(event);
          } else if (!uniqueEventIds.contains(id)) {
            uniqueEventIds.add(id);
            tempMonthlyEvents.add(event);
          }
        }
      }
    });

    setState(() {
      _monthlyEvents = tempMonthlyEvents;
    });
  }

  void _showEventDetails(
      BuildContext context, List<Map<String, dynamic>> events) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: events.map((event) {
                  final bool isAcademic = event['type'] == 'Academic';
                  final Color cardColor =
                  isAcademic ? Colors.green[50]! : Colors.red[50]!;
                  final Color iconColor =
                  isAcademic ? Colors.green[600]! : Colors.red[600]!;
                  final Color textColor =
                  isAcademic ? Colors.green[800]! : Colors.red[800]!;
                  final Color subtitleColor =
                  isAcademic ? Colors.green[700]! : Colors.red[700]!;

                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 6.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: cardColor,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(10.sp),
                      leading: Icon(Icons.event, color: iconColor),
                      title: Text(
                        (event['name'] ?? '').toString(),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          "📅 ${AppDateTimeUtils.date(event['start_date'])} - ${AppDateTimeUtils.date(event['end_date'])}\n📌 Type: ${event['type']}",
                          style: TextStyle(color: subtitleColor, fontSize: 14),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: GoogleFonts.montserrat(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.secondary,
      ),
      body: Padding(
        padding: EdgeInsets.all(5.sp),
        child: Column(
          children: [
            // ✅ FIX: fixed calendar height so Column never overflows
            SizedBox(
              height: 300.h,
              child: Card(
                color: Colors.white,
                elevation: 10,
                child: TableCalendar(
                  focusedDay: _focusedDay,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },

                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    titleTextStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
                  ),

                  firstDay: _firstDay,
                  lastDay: _lastDay, // ✅ FIXED
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });

                    final selectedEvents = _getEventsForDay(selectedDay);
                    if (selectedEvents.isNotEmpty) {
                      _showEventDetails(context, selectedEvents);
                    }
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                    _updateMonthlyEvents(focusedDay);
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final normalized = _normalize(date);
                      final isHighlighted =
                      _highlightedDays.contains(normalized);
                      final dayEvents = _getEventsForDay(date);

                      Color? bgColor;
                      if (isHighlighted) {
                        final hasAcademic =
                        dayEvents.any((e) => e['type'] == 'Academic');
                        bgColor = hasAcademic
                            ? Colors.green.shade300
                            : Colors.red.shade300;
                      }

                      return Container(
                        margin: const EdgeInsets.all(4),
                        child: Card(
                          elevation: isHighlighted ? 3 : 0,
                          color: bgColor ?? Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2.sp),
                            child: Column(
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: bgColor != null
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                if (isHighlighted)
                                  Expanded(
                                    child: Builder(builder: (_) {
                                      final events = dayEvents;
                                      if (events.isEmpty) return const SizedBox.shrink();

                                      String name = (events.first['name'] ?? '').toString().trim();
                                      if (name.length > 12) name = '${name.substring(0, 10)}…';

                                      final more = events.length - 1;

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8.sp,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                          if (more > 0)
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                "+$more more",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 7.sp,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            SizedBox(height: 8.h),

            Card(
              color: HexColor('#f0afb2'),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Center(
                  child: Text(
                    "Events in ${_focusedDay.month}/${_focusedDay.year}",
                    style: GoogleFonts.montserrat(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ FIX: rest section in Expanded (no overflow)
            Expanded(
              child: isLoading
                  ? const Center(
                child: CupertinoActivityIndicator(radius: 18),
              )
                  : _monthlyEvents.isEmpty
                  ? SingleChildScrollView(
                child: SizedBox(
                  height: 320.h,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 100.sp,
                          child: Image.asset(
                              'assets/no_attendance.png'),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'Event Not Available.',
                          style: GoogleFonts.radioCanada(
                            textStyle: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _monthlyEvents.length,
                padding: EdgeInsets.symmetric(
                    horizontal: 3.sp, vertical: 0),
                itemBuilder: (context, index) {
                  final event = _monthlyEvents[index];

                  final bool isAcademic =
                      event['type'] == 'Academic';
                  final Color cardColor =
                  isAcademic ? Colors.green[50]! : Colors.red[50]!;
                  final Color iconColor =
                  isAcademic ? Colors.green[600]! : Colors.red[600]!;
                  final Color textColor =
                  isAcademic ? Colors.green[800]! : Colors.red[800]!;
                  final Color subtitleColor =
                  isAcademic ? Colors.green[700]! : Colors.red[700]!;

                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 6.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: cardColor,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(10.sp),
                      leading: Icon(Icons.event, color: iconColor),
                      title: Text(
                        (event['name'] ?? '')
                            .toString()
                            .toUpperCase(),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          "📅 ${AppDateTimeUtils.date(event['start_date'])} - ${AppDateTimeUtils.date(event['end_date'])}\n📌 Type: ${event['type']}",
                          style: TextStyle(
                              color: subtitleColor, fontSize: 14),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios,
                          size: 18, color: subtitleColor),
                      onTap: () => _showEventDetails(context, [event]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
