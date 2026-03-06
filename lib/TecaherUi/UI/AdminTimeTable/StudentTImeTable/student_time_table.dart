import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class AcademicClass {
  final int id;
  final String title;
  const AcademicClass({required this.id, required this.title});
  factory AcademicClass.fromJson(Map<String, dynamic> json) =>
      AcademicClass(id: json['id'], title: json['title']);
}

class Section {
  final int id;
  final String title;
  const Section({required this.id, required this.title});
  factory Section.fromJson(Map<String, dynamic> json) =>
      Section(id: json['id'], title: json['title']);
}

class ClassSection {
  final int id;
  final int classId;
  final int sectionId;
  final AcademicClass academicClass;
  final Section section;

  const ClassSection({
    required this.id,
    required this.classId,
    required this.sectionId,
    required this.academicClass,
    required this.section,
  });

  String get displayName => '${academicClass.title} (${section.title})';

  factory ClassSection.fromJson(Map<String, dynamic> json) => ClassSection(
    id: json['id'],
    classId: json['class_id'],
    sectionId: json['section_id'],
    academicClass: AcademicClass.fromJson(json['academic_class']),
    section: Section.fromJson(json['section']),
  );
}

class TimetableEntry {
  final int id;
  final String teacherName;
  final String subjectName;
  final String sessionTitle;
  final String className;
  final String sectionTitle;
  final int day;
  final int period;
  final int status;

  const TimetableEntry({
    required this.id,
    required this.teacherName,
    required this.subjectName,
    required this.sessionTitle,
    required this.className,
    required this.sectionTitle,
    required this.day,
    required this.period,
    required this.status,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) => TimetableEntry(
    id: json['id'],
    teacherName: json['teacher_name'] ?? '',
    subjectName: json['subject_name'] ?? '',
    sessionTitle: json['session_title'] ?? '',
    className: json['class_name'] ?? '',
    sectionTitle: json['section_title'] ?? '',
    day: json['day'] ?? 1,
    period: json['period'] ?? 1,
    status: json['status'] ?? 1,
  );
}

class ClassTimetable {
  final String className;
  final List<TimetableEntry> data;

  const ClassTimetable({required this.className, required this.data});

  factory ClassTimetable.fromJson(Map<String, dynamic> json) => ClassTimetable(
    className: json['class'] ?? '',
    data: (json['data'] as List? ?? [])
        .map((e) => TimetableEntry.fromJson(e))
        .toList(),
  );
}

// ─── API Service ──────────────────────────────────────────────────────────────

class TimetableApiService {
  static Future<Map<String, dynamic>> fetchTimetable(int classId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');
    final uri =
    Uri.parse('${ApiRoutes.getAdminStudentTimeTable}?class=$classId');
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 401) {
      throw Exception('Unauthorized: Invalid or expired token');
    }
    throw Exception('Server error: ${response.statusCode}');
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const _daysFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

Color _subjectColor(String s) {
  final l = s.toLowerCase();
  if (l.contains('math')) return const Color(0xFF3B82F6);
  if (l.contains('english')) return const Color(0xFF8B5CF6);
  if (l.contains('hindi')) return const Color(0xFFEF4444);
  if (l.contains('evs') || l.contains('science')) return const Color(0xFF10B981);
  if (l.contains('computer')) return const Color(0xFF06B6D4);
  if (l.contains('art') || l.contains('craft')) return const Color(0xFFF59E0B);
  if (l.contains('music') || l.contains('dance')) return const Color(0xFFEC4899);
  if (l.contains('pt') || l.contains('sport')) return const Color(0xFF84CC16);
  if (l.contains('library')) return const Color(0xFF6366F1);
  if (l.contains('moral') || l.contains('general')) return const Color(0xFF14B8A6);
  return const Color(0xFF64748B);
}

IconData _subjectIcon(String s) {
  final l = s.toLowerCase();
  if (l.contains('math')) return Icons.calculate_outlined;
  if (l.contains('english')) return Icons.menu_book_outlined;
  if (l.contains('hindi')) return Icons.translate_outlined;
  if (l.contains('evs') || l.contains('science')) return Icons.eco_outlined;
  if (l.contains('computer')) return Icons.computer_outlined;
  if (l.contains('art') || l.contains('craft')) return Icons.brush_outlined;
  if (l.contains('music')) return Icons.music_note_outlined;
  if (l.contains('dance')) return Icons.directions_walk_outlined;
  if (l.contains('pt') || l.contains('sport')) return Icons.sports_soccer_outlined;
  if (l.contains('library')) return Icons.local_library_outlined;
  if (l.contains('moral')) return Icons.favorite_border_outlined;
  if (l.contains('general')) return Icons.lightbulb_outline;
  return Icons.school_outlined;
}

String _titleCase(String s) => s
    .split(' ')
    .map((w) =>
w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
    .join(' ');

// ─── Main Widget ──────────────────────────────────────────────────────────────

class StudentTimeTable extends StatefulWidget {
  const StudentTimeTable({super.key});

  @override
  State<StudentTimeTable> createState() => _StudentTimeTableState();
}

class _StudentTimeTableState extends State<StudentTimeTable>
    with SingleTickerProviderStateMixin {
  // ── data ──
  List<ClassSection> _allClasses = [];
  List<ClassTimetable> _timetables = [];

  // ✅ Cache: classId → timetables (avoids re-fetching same data)
  final Map<int, List<ClassTimetable>> _cache = {};

  // ── selection ──
  // null → "All" mode
  int? _selectedSectionId;

  // ── ui ──
  int _selectedDay = 1;
  bool _loadingInit = true;
  bool _loadingTT = false;
  String? _error;
  late TabController _tabController;

  // ── derived ──

  bool get _isAllMode => _selectedSectionId == null;

  ClassSection? get _currentSection => _selectedSectionId == null
      ? null
      : _allClasses.where((c) => c.id == _selectedSectionId).firstOrNull;

  List<TimetableEntry> get _selectedSectionEntries {
    final cs = _currentSection;
    if (cs == null) return [];

    final allEntries = _timetables.expand((t) => t.data).toList();

    final filtered = allEntries
        .where((e) =>
    e.sectionTitle.trim().toLowerCase() ==
        cs.section.title.trim().toLowerCase())
        .toList();

    return filtered.isNotEmpty ? filtered : allEntries;
  }

  Map<int, List<TimetableEntry>> get _periodMap {
    final entries = _selectedSectionEntries
        .where((e) => e.day == _selectedDay)
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));

    final map = <int, List<TimetableEntry>>{};
    for (final e in entries) {
      map.putIfAbsent(e.period, () => []).add(e);
    }
    return map;
  }

  List<Map<String, dynamic>> get _allModeSections {
    final result = <Map<String, dynamic>>[];
    for (final tt in _timetables) {
      final dayEntries = tt.data
          .where((e) => e.day == _selectedDay)
          .toList()
        ..sort((a, b) => a.period.compareTo(b.period));
      if (dayEntries.isEmpty) continue;
      final map = <int, List<TimetableEntry>>{};
      for (final e in dayEntries) {
        map.putIfAbsent(e.period, () => []).add(e);
      }
      result.add({'label': tt.className, 'periods': map});
    }
    return result;
  }

  // ── init ──
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedDay = _tabController.index + 1);
      }
    });
    _initialLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── API ──

  Future<void> _initialLoad() async {
    // ✅ Serve from cache instantly if available
    if (_cache.containsKey(0) && _allClasses.isNotEmpty) {
      setState(() {
        _timetables = _cache[0]!;
        _selectedSectionId = null;
        _loadingInit = false;
      });
      return;
    }

    setState(() {
      _loadingInit = true;
      _error = null;
    });

    try {
      final data = await TimetableApiService.fetchTimetable(0);

      final classes = (data['classes'] as List? ?? [])
          .map((e) => ClassSection.fromJson(e))
          .toList();

      final timetables = (data['class_timetable'] as List? ?? [])
          .map((e) => ClassTimetable.fromJson(e))
          .toList();

      // ✅ Store in cache
      _cache[0] = timetables;

      setState(() {
        _allClasses = classes;
        _timetables = timetables;
        _loadingInit = false;
      });
    } catch (e) {
      setState(() {
        _loadingInit = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadTimetable(ClassSection cs) async {
    // ✅ Cache hit → instant switch, no API call, no loading spinner
    if (_cache.containsKey(cs.id)) {
      setState(() {
        _selectedSectionId = cs.id;
        _timetables = _cache[cs.id]!;
      });
      return;
    }

    setState(() {
      _selectedSectionId = cs.id;
      _loadingTT = true;
      _error = null;
    });

    try {
      final data = await TimetableApiService.fetchTimetable(cs.id);

      final timetables = (data['class_timetable'] as List? ?? [])
          .map((e) => ClassTimetable.fromJson(e))
          .toList();

      // ✅ Store in cache
      _cache[cs.id] = timetables;

      setState(() {
        _timetables = timetables;
        _loadingTT = false;
      });
    } catch (e) {
      setState(() {
        _loadingTT = false;
        _error = e.toString();
      });
    }
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    if (_loadingInit) return Scaffold(body: _splashLoader());
    if (_error != null && _allClasses.isEmpty) {
      return Scaffold(body: _errorView(_error!));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _chipBar(),
          _dayTabs(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  // ── Splash ──
  Widget _splashLoader() => Container(
    color: Colors.white,
    child: const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: Colors.red),
        SizedBox(height: 20),
        Text('Loading Timetable…',
            style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  // ── Error ──
  Widget _errorView(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded,
            size: 60, color: Color(0xFFEF4444)),
        const SizedBox(height: 16),
        Text(msg,
            textAlign: TextAlign.center,
            style:
            const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            // ✅ Clear cache on retry so fresh data is fetched
            _cache.clear();
            _initialLoad();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  // ── Chip Bar ──
  Widget _chipBar() {
    return Container(
      color: AppColors.primary,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          itemCount: _allClasses.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final isAllChip = i == 0;
            final classObj = isAllChip ? null : _allClasses[i - 1];

            final label = isAllChip
                ? 'All'
                : '${classObj!.academicClass.title} (${classObj.section.title})';

            final bool sel = isAllChip
                ? _isAllMode
                : (!_isAllMode && _selectedSectionId == classObj!.id);

            return GestureDetector(
              onTap: () {
                if (isAllChip) {
                  setState(() => _selectedSectionId = null);
                  _initialLoad();
                } else {
                  _loadTimetable(classObj!);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAllChip) ...[
                      Icon(
                        Icons.grid_view_rounded,
                        size: 12.sp,
                        color: sel ? AppColors.primary : Colors.white,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: sel ? AppColors.primary : Colors.white,
                        fontWeight:
                        sel ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Day Tabs ──
  Widget _dayTabs() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: AppColors.primary,
      unselectedLabelColor: const Color(0xFF94A3B8),
      indicatorColor: AppColors.primary,
      indicatorWeight: 3,
      labelStyle:
      const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle:
      const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      tabs: _days
          .map((d) => Tab(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(d),
        ),
      ))
          .toList(),
    ),
  );

  // ── Body ──
  Widget _body() {
    if (_loadingTT) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text('Loading…', style: TextStyle(color: AppColors.primary)),
        ]),
      );
    }

    if (_error != null) return _errorView(_error!);

    if (_isAllMode) {
      final sections = _allModeSections;
      if (sections.isEmpty) {
        return _emptyDay(
            'No periods scheduled\nfor ${_daysFull[_selectedDay - 1]}.');
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final item = sections[i];
          return _ExpandableClassBlock(
            label: item['label'] as String,
            periods: item['periods'] as Map<int, List<TimetableEntry>>,
            periodCardBuilder: _periodCard,
          );
        },
      );
    }

    // Single section mode
    final periods = _periodMap;
    if (periods.isEmpty) {
      return _emptyDay(
          'No periods scheduled\nfor ${_daysFull[_selectedDay - 1]}.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      itemCount: periods.length,
      itemBuilder: (_, i) {
        final p = periods.keys.elementAt(i);
        return _periodCard(p, periods[p]!);
      },
    );
  }

  Widget _emptyDay(String msg) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
            color: Color(0xFFEEF2FF), shape: BoxShape.circle),
        child: const Icon(Icons.event_busy_outlined,
            color: Color(0xFF818CF8), size: 36),
      ),
      const SizedBox(height: 14),
      Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF94A3B8), fontSize: 15, height: 1.5)),
    ]),
  );

  // ── Period Card ──
  Widget _periodCard(int period, List<TimetableEntry> entries) {
    final isJoint = entries.length > 1;
    final primary = entries.first;
    final color = _subjectColor(primary.subjectName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 50,
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border:
                Border.all(color: color.withOpacity(0.45), width: 1.5),
              ),
              child: Center(
                child: Text('$period',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
            if (isJoint) ...[
              const SizedBox(height: 2),
              Text('Joint',
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.07),
                    border: Border(
                        bottom:
                        BorderSide(color: color.withOpacity(0.15))),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(_subjectIcon(primary.subjectName),
                          color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(primary.subjectName,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('P$period',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                ...entries.map((e) => _teacherRow(e, isJoint)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _teacherRow(TimetableEntry e, bool isJoint) {
    final color = _subjectColor(e.subjectName);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: color.withOpacity(0.12),
          child: Text(
            e.teacherName.isNotEmpty ? e.teacherName[0] : '?',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titleCase(e.teacherName),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                if (isJoint)
                  Text(e.subjectName,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
              ]),
        ),
        Row(children: [
          const Icon(Icons.class_outlined,
              size: 12, color: Color(0xFF94A3B8)),
          const SizedBox(width: 3),
          Text('${e.className}-${e.sectionTitle}',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

// ─── Expandable Class Block (for ALL mode) ────────────────────────────────────

class _ExpandableClassBlock extends StatefulWidget {
  final String label;
  final Map<int, List<TimetableEntry>> periods;
  final Widget Function(int, List<TimetableEntry>) periodCardBuilder;

  const _ExpandableClassBlock({
    required this.label,
    required this.periods,
    required this.periodCardBuilder,
  });

  @override
  State<_ExpandableClassBlock> createState() => _ExpandableClassBlockState();
}

class _ExpandableClassBlockState extends State<_ExpandableClassBlock>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _ctrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _rotate = Tween(begin: 0.0, end: 0.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Class ${widget.label}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.periods.length} period${widget.periods.length == 1 ? '' : 's'}',
                  style:
                  const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const Spacer(),
              RotationTransition(
                turns: _rotate,
                child: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white, size: 22),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              children: widget.periods.entries
                  .map((entry) =>
                  widget.periodCardBuilder(entry.key, entry.value))
                  .toList(),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}