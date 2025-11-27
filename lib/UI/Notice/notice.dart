import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../../HexColorCode/HexColor.dart';
import '../../constants.dart';
import '../Auth/login_screen.dart';

class CalendarScreen extends StatefulWidget {
  final String title;
  const CalendarScreen({super.key, required this.title});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarFormat _calendarFormat;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  Set<DateTime> _highlightedDays = {}; // Store all event dates
  List<Map<String, dynamic>> _monthlyEvents = []; // Unique events in the current month
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      _showLoginDialog();
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.events),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      List<dynamic> events = data['events'];

      Map<DateTime, List<Map<String, dynamic>>> tempEvents = {};
      Set<DateTime> tempHighlightedDays = {};
      Set<int> uniqueEventIds = {}; // Set to track unique events for the month
      List<Map<String, dynamic>> tempMonthlyEvents = [];

      for (var event in events) {
        DateTime startDate = DateTime.parse(event['start_date']).toLocal();
        DateTime endDate = DateTime.parse(event['end_date']).toLocal();

        // Normalize dates (remove time)
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day);

        // Add all event days to highlighted set
        for (DateTime date = startDate;
        date.isBefore(endDate.add(Duration(days: 1)));
        date = date.add(Duration(days: 1))) {
          DateTime normalizedDate = DateTime(date.year, date.month, date.day);
          tempHighlightedDays.add(normalizedDate);

          if (tempEvents[normalizedDate] == null) {
            tempEvents[normalizedDate] = [];
          }
          tempEvents[normalizedDate]!.add(event);
        }

        // Add only unique events to the monthly events list
        if (startDate.month == _focusedDay.month && startDate.year == _focusedDay.year) {
          if (!uniqueEventIds.contains(event['id'])) {
            uniqueEventIds.add(event['id']);
            tempMonthlyEvents.add(event);
          }
        }
      }

      setState(() {
        _events = tempEvents;
        _highlightedDays = tempHighlightedDays;
        _monthlyEvents = tempMonthlyEvents; // Only unique events will be stored
      });
      isLoading = false; // Stop progress bar
    } else {
      _showLoginDialog();
      setState(() {
        isLoading = true; // Show progress bar
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _updateMonthlyEvents(DateTime newMonth) {
    Set<int> uniqueEventIds = {};
    List<Map<String, dynamic>> tempMonthlyEvents = [];

    _events.forEach((date, events) {
      if (date.month == newMonth.month && date.year == newMonth.year) {
        for (var event in events) {
          if (!uniqueEventIds.contains(event['id'])) {
            uniqueEventIds.add(event['id']);
            tempMonthlyEvents.add(event);
          }
        }
      }
    });

    setState(() {
      _monthlyEvents = tempMonthlyEvents;
    });
  }

  void _showEventDetails(BuildContext context, List<Map<String, dynamic>> events) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            widget.title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: events.map((event) {
                  // Determine colors based on event type
                  Color cardColor = event['type'] == 'Academic' ? Colors.green[50]! : Colors.red[50]!;
                  Color iconColor = event['type'] == 'Academic' ? Colors.green[600]! : Colors.red[600]!;
                  Color textColor = event['type'] == 'Academic' ? Colors.green[800]! : Colors.red[800]!;
                  Color subtitleColor = event['type'] == 'Academic' ? Colors.green[700]! : Colors.red[700]!;

                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 3.sp),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: cardColor,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(3.sp),
                      leading: Icon(Icons.event, color: iconColor),
                      title: Text(
                        event['name'],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          "📅 ${event['start_date']} - ${event['end_date']}\n📌 Type: ${event['type']}",
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
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Close"),
            )
          ],
        );
      },
    );
  }

  void _showLoginDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Please log in again to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
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
            Card(
              color: Colors.white,
              elevation: 10,
              child: TableCalendar(
                focusedDay: _focusedDay,
                firstDay: DateTime(2025, 1, 1),
                lastDay: DateTime(2025, 12, 31),
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });

                  List<Map<String, dynamic>> selectedEvents = _getEventsForDay(selectedDay);
                  if (selectedEvents.isNotEmpty) {
                    _showEventDetails(context, selectedEvents);
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                  _updateMonthlyEvents(focusedDay);
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, date, _) {
                    bool isHighlighted = _highlightedDays.contains(DateTime(date.year, date.month, date.day));
                    List<Map<String, dynamic>> dayEvents = _getEventsForDay(date);
                    Color? bgColor;
                    if (isHighlighted) {
                      // Check if any event is Academic
                      bool hasAcademic = dayEvents.any((event) => event['type'] == 'Academic');
                      bgColor = hasAcademic ? Colors.green.shade300 : Colors.red.shade300;
                    }

                    return Container(
                      margin: EdgeInsets.all(4),
                      child: Card(
                        elevation: isHighlighted ? 3 : 0,
                        color: bgColor ?? Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(2.sp),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: bgColor != null ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                              if (isHighlighted)
                                Expanded(
                                  child: Column(
                                    children: dayEvents.take(2).map((event) {
                                      // Truncate event name to avoid overflow
                                      String eventName = event['name'].toString();
                                      if (eventName.length > 10) {
                                        eventName = '${eventName.substring(0, 8)}...';
                                      }
                                      return Text(
                                        eventName,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.sp,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        maxLines: 1,
                                      );
                                    }).toList(),
                                  ),
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
            SizedBox(height: 0.sp),
            Card(
              color: HexColor('#f0afb2'),
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
            isLoading
                ? Center(
                child: Container(
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: CupertinoActivityIndicator(radius: 25, color: Colors.white)))
                : _monthlyEvents.isEmpty
                ? Center(
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: Container(
                    child: Center(
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.sp),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                        height: MediaQuery.of(context).size.height * 0.3,
                                        child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                    height: 100.sp,
                                                    child: Image.asset('assets/no_attendance.png')),
                                                Center(
                                                    child: Padding(
                                                      padding: EdgeInsets.only(top: 0.sp),
                                                      child: Text(
                                                        'Event Not Available.',
                                                        style: GoogleFonts.radioCanada(
                                                          textStyle: TextStyle(
                                                            fontSize: 12.sp,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ))
                                              ],
                                            )))
                                  ],
                                ),
                              ],
                            ))),
                  ),
                ))
                : Expanded(
              child: ListView.builder(
                itemCount: _monthlyEvents.length,
                padding: EdgeInsets.symmetric(horizontal: 3.sp, vertical: 0.sp),
                itemBuilder: (context, index) {
                  var event = _monthlyEvents[index];
                  // Determine colors based on event type
                  Color cardColor = event['type'] == 'Academic' ? Colors.green[50]! : Colors.red[50]!;
                  Color iconColor = event['type'] == 'Academic' ? Colors.green[600]! : Colors.red[600]!;
                  Color textColor = event['type'] == 'Academic' ? Colors.green[800]! : Colors.red[800]!;
                  Color subtitleColor = event['type'] == 'Academic' ? Colors.green[700]! : Colors.red[700]!;

                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 3.sp),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: cardColor,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(3.sp),
                      leading: Icon(Icons.event, color: iconColor),
                      title: Text(
                        event['name'].toString().toUpperCase(),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          "📅 ${event['start_date']} - ${event['end_date']}\n📌 Type: ${event['type']}",
                          style: TextStyle(color: subtitleColor, fontSize: 14),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: subtitleColor),
                      onTap: () => _showEventDetails(context, [event]),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}