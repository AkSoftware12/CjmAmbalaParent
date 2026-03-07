import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Colors ─────────────────────────────────────────────────────────────
const Color kPrimaryRed = Color(0xFFD32F2F);
const Color kDarkRed    = Color(0xFF9A0007);
const Color kLightRed   = Color(0xFFFFEBEE);
const Color kBgColor    = Color(0xFFFFF5F5);
const Color kTextDark   = Color(0xFF2D0000);

// ─── Palette ──────────────────────────────────────────────────────────────────
const List<Color> _kPalette = [
  Color(0xFFD32F2F), Color(0xFFAD1457), Color(0xFF6A1B9A),
  Color(0xFF283593), Color(0xFF00695C), Color(0xFF2E7D32),
  Color(0xFFE65100), Color(0xFF4E342E), Color(0xFF37474F),
  Color(0xFF558B2F),
];

// ─── Models ───────────────────────────────────────────────────────────────────

class Teacher {
  final int    id;
  final String name;
  const Teacher({required this.id, required this.name});

  static int _i(dynamic v) => v is int ? v : (int.tryParse('$v') ?? 0);

  factory Teacher.fromJson(Map<String, dynamic> j) => Teacher(
    id:   _i(j['id']),
    name: (j['first_name'] ?? '').toString().trim(),
  );
}

class TimeSlot {
  final int    id;
  final String teacherName;
  final String subjectName;
  final String className;
  final String section;
  final int    day;
  final int    period;

  const TimeSlot({
    required this.id,
    required this.teacherName,
    required this.subjectName,
    required this.className,
    required this.section,
    required this.day,
    required this.period,
  });

  static int _i(dynamic v) => v is int ? v : (int.tryParse('$v') ?? 0);

  String get dayLabel {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    return (day >= 1 && day <= 5) ? days[day] : 'Day $day';
  }

  factory TimeSlot.fromJson(Map<String, dynamic> j, String teacherName) =>
      TimeSlot(
        id:          _i(j['id']),
        teacherName: teacherName,
        subjectName: (j['subject_name'] ?? '').toString(),
        className:   (j['class']        ?? '').toString(),
        section:     (j['section']      ?? '').toString(),
        day:         _i(j['day']),
        period:      _i(j['period']),
      );
}

// ─── API ──────────────────────────────────────────────────────────────────────

typedef _ApiResult = ({List<Teacher> teachers, List<TimeSlot> slots});

_ApiResult _parse(Map<String, dynamic> json) {
  final teachers = (json['teachers'] as List? ?? [])
      .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
      .toList();

  final slots = <TimeSlot>[];
  final raw   = json['teacher_timetable'];

  if (raw is List) {
    for (final entry in raw) {
      final map         = entry as Map<String, dynamic>;
      final teacherName = (map['name'] ?? '').toString().trim();
      for (final p in (map['data'] as List? ?? [])) {
        final slot = TimeSlot.fromJson(p as Map<String, dynamic>, teacherName);
        if (slot.day >= 1 && slot.day <= 5) slots.add(slot);
      }
    }
  }

  return (teachers: teachers, slots: slots);
}

/// API: ?day=1  OR  ?day=1&teacher=128
Future<_ApiResult> _fetchData({required int day, int? teacherId}) async {
  final prefs  = await SharedPreferences.getInstance();
  final token  = prefs.getString('teachertoken');

  final params = <String, String>{'day': '$day'};
  if (teacherId != null) params['teacher'] = '$teacherId';

  final uri = Uri.parse(ApiRoutes.getAdminTeacherTimeTable)
      .replace(queryParameters: params);

  final response = await http.get(uri, headers: {
    'Authorization': 'Bearer $token',
    'Accept':        'application/json',
    'Connection':    'keep-alive',
  }).timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  if (json['success'] != true) throw Exception(json['message'] ?? 'Error');

  return _parse(json);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Mon=1…Fri=5, null on Sat/Sun
int? _weekdayOrNull() {
  final w = DateTime.now().weekday;
  return (w >= 1 && w <= 5) ? w : null;
}

int _currentWeekday() => DateTime.now().weekday;

String _dayShort(int d) {
  const s = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  return d >= 1 && d <= 5 ? s[d] : '';
}

String _dayFull(int d) {
  const s = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  return d >= 1 && d <= 5 ? s[d] : '';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TeacherTimeTableScreen extends StatefulWidget {
  const TeacherTimeTableScreen({super.key});

  @override
  State<TeacherTimeTableScreen> createState() =>
      _TeacherTimeTableScreenState();
}

class _TeacherTimeTableScreenState
    extends State<TeacherTimeTableScreen> {

  // ── Data ──────────────────────────────────────────────────────────────────
  List<Teacher>  _teachers = [];
  List<TimeSlot> _slots    = [];

  // ── Color cache (inside state — zero global conflicts) ────────────────────
  final Map<String, Color> _colorOf = <String, Color>{};

  Color _colorForTeacher(String name) {
    if (_colorOf.containsKey(name)) return _colorOf[name]!;
    final idx   = _teachers.indexWhere((t) => t.name == name);
    final i     = idx >= 0 ? idx : _colorOf.length;
    final color = _kPalette[i % _kPalette.length];
    _colorOf[name] = color;
    return color;
  }

  // ── UI state ──────────────────────────────────────────────────────────────
  bool     _loading    = true;
  bool     _dayLoading = false;
  String?  _error;

  /// -1 = weekend (no day selected), 1–5 = Mon–Fri
  int      _selectedDay     = -1;
  Teacher? _selectedTeacher;          // null = All Teachers

  // Mon–Fri only — Sat/Sun never shown
  static const List<int> _weekDays = [1, 2, 3, 4, 5];

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedDay = _weekdayOrNull() ?? -1;
    _initialLoad();
  }

  // ── Initial load ──────────────────────────────────────────────────────────

  Future<void> _initialLoad() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch Monday's data just to populate teacher list on weekends
      final day = _selectedDay == -1 ? 1 : _selectedDay;
      final r   = await _fetchData(day: day);
      if (!mounted) return;
      setState(() {
        _teachers = r.teachers;
        _slots    = _selectedDay == -1 ? [] : r.slots;
        _colorOf.clear();
        _loading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Reload when day/teacher changes ───────────────────────────────────────

  Future<void> _reload({required int day, Teacher? teacher}) async {
    if (day == -1) {
      setState(() { _slots = []; });
      return;
    }
    setState(() { _dayLoading = true; _error = null; });
    try {
      final r = await _fetchData(day: day, teacherId: teacher?.id);
      if (!mounted) return;
      setState(() {
        if (r.teachers.isNotEmpty) _teachers = r.teachers;
        _slots      = r.slots;
        _colorOf.clear();
        _dayLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _dayLoading = false; });
    }
  }

  // ── Day chip tapped ────────────────────────────────────────────────────────

  void _onDaySelected(int day) {
    if (_selectedDay == day) return;
    setState(() => _selectedDay = day);
    _reload(day: day, teacher: _selectedTeacher);
  }

  // ── Teacher chip tapped ────────────────────────────────────────────────────

  void _onTeacherSelected(Teacher? teacher) {
    if (_selectedTeacher?.id == teacher?.id) return;
    setState(() => _selectedTeacher = teacher);
    if (_selectedDay != -1) _reload(day: _selectedDay, teacher: teacher);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading)                                   return _loaderScaffold();
    if (_error != null && !_dayLoading && _slots.isEmpty) return _errorScaffold();
    return _mainScaffold();
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _loaderScaffold() => Scaffold(
    backgroundColor: kBgColor,
    body: const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: kPrimaryRed),
        SizedBox(height: 16),
        Text('Loading timetable…',
            style: TextStyle(
                color: kPrimaryRed, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  Widget _errorScaffold() => Scaffold(
    backgroundColor: kBgColor,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: kPrimaryRed),
          const SizedBox(height: 16),
          const Text('Failed to load timetable',
              style: TextStyle(
                  color: kTextDark, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initialLoad,
            icon:  const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  Widget _mainScaffold() {
    final isWeekend = _selectedDay == -1;
    final slots     = _slots;

    return Scaffold(
      backgroundColor: kBgColor,
      body: CustomScrollView(slivers: [

        // ── Filter panel ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Teacher chips
                _label('Select Teacher'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _teachers.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _Chip(
                          label:    'All Teachers',
                          selected: _selectedTeacher == null,
                          onTap:    () => _onTeacherSelected(null),
                        );
                      }
                      final t = _teachers[i - 1];
                      return _Chip(
                        label:    t.name,
                        selected: _selectedTeacher?.id == t.id,
                        onTap:    () => _onTeacherSelected(t),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // Day chips — Mon to Fri ONLY (no Sat/Sun)
                _label('Select Day'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _weekDays.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final d       = _weekDays[i];
                      final isToday = d == _currentWeekday();
                      return _DayChip(
                        label:    _dayShort(d),
                        selected: _selectedDay == d,
                        isToday:  isToday,
                        onTap:    () => _onDaySelected(d),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Stats row ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              if (_dayLoading)
                const Row(children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimaryRed),
                  ),
                  SizedBox(width: 8),
                  Text('Loading…',
                      style: TextStyle(
                          color: kPrimaryRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ])
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kLightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isWeekend
                        ? 'Weekend — select a day'
                        : '${slots.length} period${slots.length == 1 ? '' : 's'}  •  ${_dayFull(_selectedDay)}',
                    style: const TextStyle(
                      color: kPrimaryRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              const Spacer(),
              if (_selectedTeacher != null)
                Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _colorForTeacher(_selectedTeacher!.name),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedTeacher!.name.split(' ').first,
                    style: const TextStyle(
                      color: kPrimaryRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ]),
            ]),
          ),
        ),

        // ── Weekend / empty state ──────────────────────────────────────────
        if (isWeekend || (!_dayLoading && slots.isEmpty))
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isWeekend
                        ? Icons.weekend_rounded
                        : Icons.event_busy_rounded,
                    size: 72,
                    color: kPrimaryRed.withOpacity(0.20),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isWeekend ? 'No classes today 🎉' : 'No periods scheduled',
                    style: TextStyle(
                      color: kPrimaryRed.withOpacity(0.65),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isWeekend
                        ? 'Today is a weekend.\nSelect a weekday above to view the timetable.'
                        : 'No timetable found for the selected day'
                        '${_selectedTeacher != null ? ' & teacher' : ''}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kPrimaryRed.withOpacity(0.35),
                      fontSize: 13,
                    ),
                  ),
                ]),
              ),
            ),
          )

        // ── Slot list ──────────────────────────────────────────────────────
        else if (!_dayLoading)
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final slot = slots[i];
                return _SlotCard(
                  slot:  slot,
                  color: _colorForTeacher(slot.teacherName),
                );
              },
              childCount: slots.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ]),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark));
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? kPrimaryRed : kLightRed,
        borderRadius: BorderRadius.circular(20),
        boxShadow: selected
            ? [BoxShadow(
            color: kPrimaryRed.withOpacity(0.35),
            blurRadius: 8, offset: const Offset(0, 3))]
            : [],
      ),
      child: Text(label,
          style: TextStyle(
            color:      selected ? Colors.white : kPrimaryRed,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize:   13,
          )),
    ),
  );
}

class _DayChip extends StatelessWidget {
  final String label; final bool selected; final bool isToday;
  final VoidCallback onTap;
  const _DayChip({
    required this.label, required this.selected,
    required this.onTap, this.isToday = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? kDarkRed : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? kDarkRed
              : isToday ? kPrimaryRed
              : const Color(0xFFFFCDD2),
          width: isToday && !selected ? 1.5 : 1.0,
        ),
      ),
      child: Text(label,
          style: TextStyle(
            color:      selected ? Colors.white : kPrimaryRed,
            fontWeight: isToday || selected ? FontWeight.w700 : FontWeight.w600,
            fontSize:   12,
          )),
    ),
  );
}

class _SlotCard extends StatelessWidget {
  final TimeSlot slot; final Color color;
  const _SlotCard({required this.slot, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: kPrimaryRed.withOpacity(0.07),
            blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Row(children: [
        Container(width: 6, color: color),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(slot.subjectName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15, color: kTextDark)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: kLightRed,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('Period ${slot.period}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: kPrimaryRed)),
                  ),
                ]),
                const SizedBox(height: 8),
                _Info(Icons.person_outline_rounded,
                    slot.teacherName, const Color(0xFF880000)),
                const SizedBox(height: 5),
                _Info(Icons.calendar_today_outlined, slot.dayLabel, color),
                const SizedBox(height: 5),
                Row(children: [
                  _Info(Icons.class_outlined, 'Class ${slot.className}', color),
                  const SizedBox(width: 14),
                  _Info(Icons.groups_outlined, 'Sec ${slot.section}',
                      const Color(0xFF880000)),
                ]),
              ],
            ),
          ),
        ),
      ]),
    ),
  );
}

class _Info extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Info(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ),
    ],
  );
}