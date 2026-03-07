import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FreeTeachers extends StatefulWidget {
  const FreeTeachers({super.key});

  @override
  State<FreeTeachers> createState() => _FreeTeachersState();
}

class _FreeTeachersState extends State<FreeTeachers> {
  bool _isLoading = true;
  String? _error;
  List<String> _weekdays = [];
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _fetchFreeTeachers();
  }

  Future<void> _fetchFreeTeachers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('teachertoken');

      final response = await http.get(
        Uri.parse(ApiRoutes.getFreeTeachers),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final data = jsonData['data'];
          setState(() {
            _weekdays = List<String>.from(data['weekdays']);
            _teachers = List<Map<String, dynamic>>.from(data['teachers']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = jsonData['message'] ?? 'Failed to load data';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatPeriods(List<dynamic> periods) {
    if (periods.isEmpty) return '—';
    return periods.map((p) => 'P$p').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        title: const Text(
          'Free Teachers Report',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFFC0392B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchFreeTeachers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFC0392B)),
            SizedBox(height: 16),
            Text(
              'Loading free periods...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchFreeTeachers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0392B),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Summary header
          Container(
            color: const Color(0xFFC0392B),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_teachers.length} Teachers  •  ${_weekdays.length} Days',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFE74C3C),
                  ),
                  headingTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith(
                        (states) {
                      return states.contains(WidgetState.selected)
                          ? const Color(0xFFFFEBEE)
                          : null;
                    },
                  ),
                  columnSpacing: 20,
                  horizontalMargin: 16,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Colors.red.shade100,
                      width: 1,
                    ),
                  ),
                  columns: [
                    const DataColumn(
                      label: Text('#'),
                    ),
                    const DataColumn(
                      label: Text('Teacher Name'),
                    ),
                    ..._weekdays.map(
                          (day) => DataColumn(
                        label: Text(day.substring(0, 3).toUpperCase()),
                      ),
                    ),
                  ],
                  rows: _teachers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final teacher = entry.value;
                    final isEven = index % 2 == 0;

                    return DataRow(
                      color: WidgetStateProperty.all(
                        isEven
                            ? Colors.white
                            : const Color(0xFFFFF0F0),
                      ),
                      cells: [
                        DataCell(
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            teacher['teacher_name'].toString().trim(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ..._weekdays.map((day) {
                          final periods =
                              teacher[day] as List<dynamic>? ?? [];
                          return DataCell(
                            periods.isEmpty
                                ? const Text(
                              '—',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            )
                                : Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: periods.map((p) {
                                return Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC0392B),
                                    borderRadius:
                                    BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'P$p',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}