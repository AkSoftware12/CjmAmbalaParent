import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Colors ─────────────────────────────────────────────────────────────
const Color kPrimaryRed = Color(0xFFD32F2F);
const Color kDarkRed = Color(0xFF9A0007);
const Color kLightRed = Color(0xFFFFEBEE);
const Color kAccentRed = Color(0xFFFF5252);
const Color kBgColor = Color(0xFFFFF5F5);
const Color kTextDark = Color(0xFF2D0000);

// ─── Models ───────────────────────────────────────────────────────────────────

class Teacher {
  final int id;
  final String name;

  const Teacher({required this.id, required this.name});

  factory Teacher.fromJson(Map<String, dynamic> j) =>
      Teacher(id: j['id'] as int, name: (j['first_name'] as String).trim());
}

class TimeSlot {
  final int id;
  final String teacherName;
  final String subjectName;
  final String className;
  final String section;
  final int day;
  final int period;

  const TimeSlot({
    required this.id,
    required this.teacherName,
    required this.subjectName,
    required this.className,
    required this.section,
    required this.day,
    required this.period,
  });

  String get dayLabel {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return (day >= 1 && day <= 7) ? days[day] : 'Day $day';
  }

  factory TimeSlot.fromJson(Map<String, dynamic> j, String teacherName) =>
      TimeSlot(
        id: j['id'] as int,
        teacherName: teacherName,
        subjectName: j['subject_name'] as String,
        className: j['class'] as String,
        section: j['section'] as String,
        day: j['day'] as int,
        period: j['period'] as int,
      );
}

// ─── API Service ──────────────────────────────────────────────────────────────
Future<({List<Teacher> teachers, List<TimeSlot> slots})> _fetchData({
  int? teacherId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('teachertoken');

  final uri = teacherId != null
      ? Uri.parse('${ApiRoutes.getAdminTeacherTimeTable}?teacher=$teacherId')
      : Uri.parse(ApiRoutes.getAdminTeacherTimeTable);

  final response = await http
      .get(uri, headers: {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    // Ask server not to send compressed body if it's small enough
    'Connection': 'keep-alive',
  })
      .timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;

  if (json['success'] != true) {
    throw Exception(json['message'] ?? 'Error');
  }

  // Parse teachers
  final teachers = (json['teachers'] as List<dynamic>)
      .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
      .toList();

  // Parse timetable slots (may be absent when no teacher filter)
  final slots = <TimeSlot>[];
  final rawTimetable = json['teacher_timetable'];
  if (rawTimetable is List) {
    for (final entry in rawTimetable) {
      final map = entry as Map<String, dynamic>;
      final teacherName = (map['name'] as String).trim();
      final data = map['data'] as List<dynamic>;
      for (final p in data) {
        slots.add(TimeSlot.fromJson(p as Map<String, dynamic>, teacherName));
      }
    }
  }

  slots.sort((a, b) {
    final dc = a.day.compareTo(b.day);
    return dc != 0 ? dc : a.period.compareTo(b.period);
  });

  return (teachers: teachers, slots: slots);
}

// ─── Color per teacher ────────────────────────────────────────────────────────
final List<Color> _palette = [
  const Color(0xFFD32F2F),
  const Color(0xFFC62828),
  const Color(0xFFB71C1C),
  const Color(0xFFE53935),
  const Color(0xFFEF5350),
  const Color(0xFFFF1744),
  const Color(0xFFFF5252),
  const Color(0xFFFF8A80),
];

final Map<int, Color> _colorCache = {};

Color colorForTeacher(int teacherId) {
  return _colorCache.putIfAbsent(
    teacherId,
        () => _palette[_colorCache.length % _palette.length],
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TeacherTimeTableScreen extends StatefulWidget {
  const TeacherTimeTableScreen({super.key});

  @override
  State<TeacherTimeTableScreen> createState() => _TeacherTimeTableScreenState();
}

class _TeacherTimeTableScreenState extends State<TeacherTimeTableScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  List<Teacher> _teachers = [];

  // ── Cache: teacherId → slots (null key = "All Teachers") ──────────────────
  final Map<int?, List<TimeSlot>> _cache = {};

  List<TimeSlot> _slots = [];
  bool _initialLoading = true;
  bool _loadingSlots = false;
  String? _error;

  Teacher? _selectedTeacher; // null = All Teachers
  int _selectedDay = 0; // 0 = All Days

  // Prevent double-tap racing
  bool _isSwitching = false;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad({bool forceRefresh = false}) async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });

    try {
      // Always fetch "All Teachers" first — single API call gives us
      // both the teachers list and (optionally) full timetable.
      if (forceRefresh) _cache.clear();

      final result = await _fetchData(teacherId: null);

      setState(() {
        _teachers = result.teachers;
        // If API returns slots for all teachers in base call, cache them.
        if (result.slots.isNotEmpty) {
          _cache[null] = result.slots;
        }
        _initialLoading = false;
      });

      // Now load slots for the current selection (may already be cached)
      await _loadSlots(_selectedTeacher, forceRefresh: forceRefresh);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  /// Load slots for [teacher] (null = all).
  /// Uses cache when available; skips network unless [forceRefresh].
  Future<void> _loadSlots(Teacher? teacher, {bool forceRefresh = false}) async {
    final cacheKey = teacher?.id; // null for "All"

    // ── Serve from cache instantly ─────────────────────────────────────────
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      setState(() {
        _slots = _cache[cacheKey]!;
        _loadingSlots = false;
      });
      return;
    }

    setState(() => _loadingSlots = true);

    try {
      List<TimeSlot> slots;

      if (teacher == null) {
        // "All Teachers" — use the same base endpoint
        // If it returned no timetable before, try with each teacher id
        // but first try the base URL one more time.
        final result = await _fetchData(teacherId: null);
        if (result.slots.isNotEmpty) {
          slots = result.slots;
        } else {
          // Fallback: fetch all teachers concurrently (original behaviour)
          // but only if cache is completely empty.
          final futures = _teachers.map(
                (t) => _fetchData(teacherId: t.id)
                .then((r) => r.slots)
                .catchError((_) => <TimeSlot>[]),
          );
          final all = await Future.wait(futures);
          slots = all.expand((s) => s).toList()
            ..sort((a, b) {
              final dc = a.day.compareTo(b.day);
              return dc != 0 ? dc : a.period.compareTo(b.period);
            });
        }
      } else {
        // Single teacher — one API call
        final result = await _fetchData(teacherId: teacher.id);
        slots = result.slots;
      }

      _cache[cacheKey] = slots; // store in cache

      if (mounted) {
        setState(() {
          _slots = slots;
          _loadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingSlots = false;
        });
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<TimeSlot> get _filtered {
    return _slots
        .where((s) => _selectedDay == 0 || s.day == _selectedDay)
        .toList();
  }

  List<int> get _availableDays => [
    0,
    ..._slots.map((s) => s.day).toSet().toList()..sort(),
  ];

  String _dayShort(int day) {
    if (day == 0) return 'All Days';
    const d = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return day <= 7 ? d[day] : 'Day $day';
  }

  // ── Teacher chip selected ──────────────────────────────────────────────────
  Future<void> _onTeacherSelected(Teacher? teacher) async {
    if (_isSwitching) return; // debounce
    if (_selectedTeacher?.id == teacher?.id) return;

    _isSwitching = true;
    setState(() {
      _selectedTeacher = teacher;
      _selectedDay = 0;
      // Show cached data immediately while possibly fetching
      final cached = _cache[teacher?.id];
      if (cached != null) _slots = cached;
    });

    await _loadSlots(teacher);
    _isSwitching = false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: _initialLoading
          ? _fullLoader('Loading teachers...')
          : _error != null && _slots.isEmpty
          ? _fullError()
          : _buildMain(),
    );
  }

  // ── Full loader ────────────────────────────────────────────────────────────
  Widget _fullLoader(String msg) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: kPrimaryRed),
                const SizedBox(height: 16),
                Text(
                  msg,
                  style: const TextStyle(
                    color: kPrimaryRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Full error ─────────────────────────────────────────────────────────────
  Widget _fullError() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 64, color: kPrimaryRed),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load data',
                    style: TextStyle(
                      color: kTextDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _initLoad(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Main content ───────────────────────────────────────────────────────────
  Widget _buildMain() {
    final filtered = _filtered;

    return CustomScrollView(
      slivers: [

        // ── Teacher Filter ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        final sel = _selectedTeacher == null;
                        return _Chip(
                          label: 'All Teachers',
                          selected: sel,
                          loading: sel && _loadingSlots,
                          onTap: () => _onTeacherSelected(null),
                        );
                      }
                      final t = _teachers[i - 1];
                      final sel = _selectedTeacher?.id == t.id;
                      return _Chip(
                        label: t.name,
                        selected: sel,
                        loading: sel && _loadingSlots,
                        onTap: () => _onTeacherSelected(t),
                      );
                    },
                  ),
                ),

                // ── Day Filter ─────────────────────────────────────────────
                const SizedBox(height: 14),
                _label('Filter by Day'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableDays.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final d = _availableDays[i];
                      final sel = _selectedDay == d;
                      return _DayChip(
                        label: _dayShort(d),
                        selected: sel,
                        onTap: () => setState(() => _selectedDay = d),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Count / Loading Banner ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                if (_loadingSlots)
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kPrimaryRed,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: kPrimaryRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kLightRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filtered.length} period${filtered.length == 1 ? '' : 's'} found',
                      style: const TextStyle(
                        color: kPrimaryRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Spacer(),
                if (_selectedTeacher != null)
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorForTeacher(_selectedTeacher!.id),
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
                    ],
                  ),
              ],
            ),
          ),
        ),

        // ── Timetable List ──────────────────────────────────────────────────
        if (!_loadingSlots && filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 64,
                    color: kPrimaryRed.withOpacity(0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No periods found',
                    style: TextStyle(
                      color: kPrimaryRed.withOpacity(0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final slot = filtered[i];
                final showHeader = i == 0 || filtered[i - 1].day != slot.day;
                final teacherId = _teachers
                    .firstWhere(
                      (t) => t.name == slot.teacherName,
                  orElse: () => Teacher(id: 0, name: slot.teacherName),
                )
                    .id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader) _DayHeader(slot.dayLabel),
                    _SlotCard(slot: slot, color: colorForTeacher(teacherId)),
                  ],
                );
              },
              childCount: filtered.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: kTextDark,
    ),
  );
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimaryRed : kLightRed,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
            BoxShadow(
              color: kPrimaryRed.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : kPrimaryRed,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kDarkRed : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kDarkRed : const Color(0xFFFFCDD2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kPrimaryRed,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String day;

  const _DayHeader(this.day);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: kPrimaryRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            day.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: kPrimaryRed,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final TimeSlot slot;
  final Color color;

  const _SlotCard({required this.slot, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryRed.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            slot.subjectName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: kTextDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kLightRed,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Period ${slot.period}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Info(
                      Icons.person_outline_rounded,
                      slot.teacherName,
                      const Color(0xFF880000),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _Info(Icons.class_outlined, 'Class ${slot.className}', color),
                        const SizedBox(width: 14),
                        _Info(
                          Icons.groups_outlined,
                          'Sec ${slot.section}',
                          const Color(0xFF880000),
                        ),
                      ],
                    ),
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

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Info(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}