import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants.dart';
import '../AdminMsg/SendMsg/message_detail_screen.dart';
import 'master_report_api.dart';


// Apne project ke hisaab se path adjust kar lena.

/// Loads the people of a chosen class section / staff type for the name dropdown.
typedef PeopleLoader = Future<List<PersonResult>> Function({
int? classSectionId,
int? employeeTypeId,
});

/// ---------------------------------------------------------------------------
/// SCREEN
/// ---------------------------------------------------------------------------
class MasterReportScreen extends StatefulWidget {
  const MasterReportScreen({super.key});

  @override
  State<MasterReportScreen> createState() => _MasterReportScreenState();
}

class _MasterReportScreenState extends State<MasterReportScreen> {
  final _api = MasterReportApi();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  Timer? _debounce;
  int _reqId = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  // Dropdown options
  List<FilterOption> _classSections = const [];
  List<FilterOption> _employeeTypes = const [];

  // Applied filters
  PersonKind? _kind;
  int? _classSectionId;
  String? _classSectionLabel;
  int? _employeeTypeId;
  String? _employeeTypeLabel;
  int? _userId;
  String? _userName;

  // Data
  List<MessageItem> _items = const [];
  ReportStats _stats = const ReportStats();
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _loadOptions();
    _searchCtrl.addListener(_onQueryChanged);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    _api.dispose();
    super.dispose();
  }

  String get _query => _searchCtrl.text.trim();

  bool get _hasFilters =>
      _kind != null ||
          _classSectionId != null ||
          _employeeTypeId != null ||
          _userId != null;

  bool get _hasMore => _page < _lastPage;

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
    setState(() {}); // refresh the clear button
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loading || _loadingMore || !_hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) _loadMore();
  }

  /// Class sections + staff types for the filter dropdowns.
  Future<void> _loadOptions() async {
    try {
      final data = await _api.filters();
      if (!mounted) return;
      setState(() {
        if (data.classSections.isNotEmpty) _classSections = data.classSections;
        if (data.employeeTypes.isNotEmpty) _employeeTypes = data.employeeTypes;
      });
    } catch (_) {
      // Dropdowns stay empty; the report list still works.
    }
  }

  /// Names for the chosen class section or staff type.
  Future<List<PersonResult>> _peopleFor({
    int? classSectionId,
    int? employeeTypeId,
  }) async {
    final data = await _api.filters(
      classSectionId: classSectionId,
      employeeTypeId: employeeTypeId,
    );
    return classSectionId != null ? data.students : data.staff;
  }

  Future<void> _load() async {
    final id = ++_reqId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final page = await _api.report(
        q: _query,
        classSectionId: _classSectionId,
        employeeTypeId: _employeeTypeId,
        userType: _kind,
        userId: _userId,
      );

      if (id != _reqId || !mounted) return; // drop stale responses

      setState(() {
        _items = page.items;
        _stats = page.stats;
        _page = page.currentPage;
        _lastPage = page.lastPage;
        if (page.classSections.isNotEmpty) _classSections = page.classSections;
        if (page.employeeTypes.isNotEmpty) _employeeTypes = page.employeeTypes;
        _loading = false;
      });

      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    } on ApiException catch (e) {
      if (id != _reqId || !mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (id != _reqId || !mounted) return;
      setState(() {
        _error = 'Something went wrong. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final id = _reqId;
    setState(() => _loadingMore = true);

    try {
      final page = await _api.report(
        q: _query,
        classSectionId: _classSectionId,
        employeeTypeId: _employeeTypeId,
        userType: _kind,
        userId: _userId,
        page: _page + 1,
      );
      if (id != _reqId || !mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    _load();
  }

  Future<void> _openFilters() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        classSections: _classSections,
        employeeTypes: _employeeTypes,
        kind: _kind,
        classSectionId: _classSectionId,
        employeeTypeId: _employeeTypeId,
        userId: _userId,
        loadPeople: _peopleFor,
      ),
    );
    if (result == null) return;

    setState(() {
      _kind = result.kind;
      _classSectionId = result.classSectionId;
      _classSectionLabel = result.classSectionLabel;
      _employeeTypeId = result.employeeTypeId;
      _employeeTypeLabel = result.employeeTypeLabel;
      _userId = result.userId;
      _userName = result.userName;
    });
    _load();
  }

  void _removeKind() {
    setState(() {
      _kind = null;
      _classSectionId = null;
      _classSectionLabel = null;
      _employeeTypeId = null;
      _employeeTypeLabel = null;
      _userId = null;
      _userName = null;
    });
    _load();
  }

  void _removeGroup() {
    setState(() {
      _classSectionId = null;
      _classSectionLabel = null;
      _employeeTypeId = null;
      _employeeTypeLabel = null;
      _userId = null;
      _userName = null;
    });
    _load();
  }

  void _removePerson() {
    setState(() {
      _userId = null;
      _userName = null;
    });
    _load();
  }

  void _clearEverything() {
    _searchCtrl.clear();
    setState(() {
      _kind = null;
      _classSectionId = null;
      _classSectionLabel = null;
      _employeeTypeId = null;
      _employeeTypeLabel = null;
      _userId = null;
      _userName = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _Header(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onClear: _clearSearch,
            onFilterTap: _openFilters,
            filterActive: _hasFilters,
            onSubmit: _load,
          ),
          if (_hasFilters)
            _ActiveFilters(
              kindLabel: _kind == null
                  ? null
                  : (_kind == PersonKind.student ? 'Students' : 'Employees'),
              groupLabel: _classSectionId != null
                  ? (_classSectionLabel ?? 'Class #$_classSectionId')
                  : (_employeeTypeId != null
                  ? (_employeeTypeLabel ?? 'Staff type')
                  : null),
              personLabel: _userName == null ? null : _titleCase(_userName!),
              onRemoveKind: _removeKind,
              onRemoveGroup: _removeGroup,
              onRemovePerson: _removePerson,
            ),
          // if (!_loading && _error == null && _items.isNotEmpty)
            // _StatsStrip(stats: _stats),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.red,
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _SkeletonList();

    if (_error != null) {
      return _MessageState(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load the report",
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_items.isEmpty) {
      return _MessageState(
        icon: Icons.mark_email_unread_outlined,
        title: _query.isEmpty ? 'No messages yet' : 'No match for "$_query"',
        message: _hasFilters || _query.isNotEmpty
            ? 'Try a different name or change the filter.'
            : 'Search a name or pick a filter to see messages.',
        actionLabel: _hasFilters || _query.isNotEmpty ? 'Clear all' : null,
        onAction: _clearEverything,
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.red),
              ),
            ),
          );
        }
        final m = _items[i];
        return RepaintBoundary(
          child: _MessageTile(
            message: m,
            query: _query,
            onTap: () => _openMessage(m),
          ),
        );
      },
    );
  }

  void _openMessage(MessageItem m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageSheet(
        message: m,
        onOpenChat: _openChat,
      ),
    );
  }

  /// Sheet band karke us person ki chat kholta hai.
  void _openChat(MessagePerson p) {
    Navigator.pop(context); // close the bottom sheet first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageDetailScreen(
          userName: p.name,
          userImage: p.photo.toString(),
          partnerId: p.newMsgId,
          classSection: p.detail,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// HEADER + SEARCH
/// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.focusNode,
    required this.onClear,
    required this.onFilterTap,
    required this.filterActive,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;
  final VoidCallback onSubmit;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.red, AppColors.redDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Master Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _FilterButton(active: filterActive, onTap: onFilterTap),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by name',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.muted, size: 22),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.muted),
                  onPressed: onClear,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Filter',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// ACTIVE FILTER CHIPS
/// ---------------------------------------------------------------------------
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    this.kindLabel,
    this.groupLabel,
    this.personLabel,
    required this.onRemoveKind,
    required this.onRemoveGroup,
    required this.onRemovePerson,
  });

  final String? kindLabel;
  final String? groupLabel;
  final String? personLabel;
  final VoidCallback onRemoveKind;
  final VoidCallback onRemoveGroup;
  final VoidCallback onRemovePerson;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (kindLabel != null)
            _Removable(
                label: kindLabel!,
                icon: Icons.category_rounded,
                onRemove: onRemoveKind),
          if (groupLabel != null)
            _Removable(
                label: groupLabel!,
                icon: Icons.class_rounded,
                onRemove: onRemoveGroup),
          if (personLabel != null)
            _Removable(
                label: personLabel!,
                icon: Icons.person_rounded,
                onRemove: onRemovePerson),
        ],
      ),
    );
  }
}

class _Removable extends StatelessWidget {
  const _Removable({required this.label, required this.onRemove, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onRemove,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: AppColors.red),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.close_rounded, size: 16, color: AppColors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// STATS
/// ---------------------------------------------------------------------------
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});

  final ReportStats stats;

  @override
  Widget build(BuildContext context) {
    // No fixed height: the row sizes itself, so a larger system font
    // can never overflow it.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(
        children: [
          _StatChip(label: 'Messages', value: stats.total),
          _StatChip(label: 'Unread', value: stats.unread, accent: true),
          _StatChip(label: 'Read', value: stats.read),
          _StatChip(label: 'Attachments', value: stats.withAttachment),
          _StatChip(label: 'Senders', value: stats.uniqueSenders),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final int value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? AppColors.redSoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accent ? AppColors.red : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: accent ? AppColors.red : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// MESSAGE TILE
/// ---------------------------------------------------------------------------
class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.query,
    required this.onTap,
  });

  final MessageItem message;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = message;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(person: m.sender, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HighlightedText(
                            text: _titleCase(m.sender.name),
                            query: query,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _KindBadge(isStudent: m.sender.isStudent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.sender.detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5, color: AppColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (m.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.red, shape: BoxShape.circle),
                      ),
                  ],
                ),

                const SizedBox(height: 10),
                _ToLine(
                    receiver: m.receiver,
                    total: m.totalReceivers,
                    query: query),

                if (m.title != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    m.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        m.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.ink,
                            height: 1.35),
                      ),
                    ),
                    if (m.hasAttachment) ...[
                      const SizedBox(width: 10),
                      _AttachmentThumb(message: m, size: 46),
                    ],
                  ],
                ),

                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      m.createdAtRaw,
                      style:
                      const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const Spacer(),
                    _StatusPill(isUnread: m.isUnread),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToLine extends StatelessWidget {
  const _ToLine({
    required this.receiver,
    required this.total,
    required this.query,
  });

  final MessagePerson receiver;
  final int total;
  final String query;

  @override
  Widget build(BuildContext context) {
    final extra = total > 1 ? ' +${total - 1}' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_forward_rounded,
              size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Flexible(
            child: _HighlightedText(
              text: '${_titleCase(receiver.name)}$extra',
              query: query,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '· ${receiver.detail}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isUnread});

  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final color = isUnread ? AppColors.red : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isUnread ? 'Unread' : 'Read',
        style:
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Student ko Employee se alag pehchanne ke liye chhota pill.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.isStudent});

  final bool isStudent;

  @override
  Widget build(BuildContext context) {
    final color = isStudent ? AppColors.red : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isStudent ? Icons.school_rounded : Icons.badge_rounded,
              size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            isStudent ? 'Student' : 'Employee',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.message, required this.size});

  final MessageItem message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.attach_file_rounded,
          size: 18, color: AppColors.muted),
    );

    if (!message.attachmentIsImage) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        message.attachment!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
        frameBuilder: (_, child, frame, wasSync) =>
        (wasSync || frame != null) ? child : fallback,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, required this.size});

  final MessagePerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.redSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        person.initials(),
        style: TextStyle(
          color: AppColors.red,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );

    if (person.photo == null) return fallback;

    return ClipOval(
      child: Image.network(
        person.photo!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(), // lower memory, smoother scrolling
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
        frameBuilder: (_, child, frame, wasSync) =>
        (wasSync || frame != null) ? child : fallback,
      ),
    );
  }
}

/// Search term ko result me highlight karta hai.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
  });

  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return Text(text,
          maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
    }

    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final i = lower.indexOf(needle, start);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + needle.length),
        style:
        const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800),
      ));
      start = i + needle.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: spans),
    );
  }
}

/// ---------------------------------------------------------------------------
/// STATES
/// ---------------------------------------------------------------------------
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: AppColors.canvas, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 12, width: 150, color: AppColors.canvas),
                      const SizedBox(height: 8),
                      Container(height: 10, width: 90, color: AppColors.canvas),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 30,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Container(
                height: 10, width: double.infinity, color: AppColors.canvas),
            const SizedBox(height: 7),
            Container(height: 10, width: 180, color: AppColors.canvas),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      children: [
        Icon(icon, size: 48, color: AppColors.red.withOpacity(0.55)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style:
          const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// FILTER SHEET — 3 cascading dropdowns
///   1. Student / Employee          -> user_type
///   2. Class section / Staff type  -> class_section_id | employee_type_id
///   3. Name                        -> user_id
/// ---------------------------------------------------------------------------
class _FilterResult {
  const _FilterResult({
    this.kind,
    this.classSectionId,
    this.classSectionLabel,
    this.employeeTypeId,
    this.employeeTypeLabel,
    this.userId,
    this.userName,
  });

  final PersonKind? kind;
  final int? classSectionId;
  final String? classSectionLabel;
  final int? employeeTypeId;
  final String? employeeTypeLabel;
  final int? userId;
  final String? userName;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.classSections,
    required this.employeeTypes,
    required this.kind,
    required this.classSectionId,
    required this.employeeTypeId,
    required this.userId,
    required this.loadPeople,
  });

  final List<FilterOption> classSections;
  final List<FilterOption> employeeTypes;
  final PersonKind? kind;
  final int? classSectionId;
  final int? employeeTypeId;
  final int? userId;
  final PeopleLoader loadPeople;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  PersonKind? _kind;
  int? _section;
  int? _type;
  int? _userId;

  List<PersonResult> _people = const [];
  bool _loadingPeople = false;
  String? _peopleError;
  int _peopleReq = 0;

  @override
  void initState() {
    super.initState();
    _kind = widget.kind;
    _section = widget.classSectionId;
    _type = widget.employeeTypeId;
    _userId = widget.userId;
    if (_kind != null && (_section != null || _type != null)) _loadPeople();
  }

  bool get _isStudent => _kind == PersonKind.student;

  int? get _groupId => _isStudent ? _section : _type;

  bool get _hasSelection =>
      _kind != null || _section != null || _type != null || _userId != null;

  void _onKindChanged(PersonKind? k) {
    if (k == null || k == _kind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kind = k;
      _section = null;
      _type = null;
      _userId = null;
      _people = const [];
      _peopleError = null;
      _peopleReq++; // cancel any in-flight load
      _loadingPeople = false;
    });
  }

  void _onGroupChanged(int? id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isStudent) {
        _section = id;
        _type = null;
      } else {
        _type = id;
        _section = null;
      }
      _userId = null;
      _people = const [];
    });
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    if (_kind == null || _groupId == null) {
      setState(() {
        _people = const [];
        _loadingPeople = false;
        _peopleError = null;
      });
      return;
    }

    final req = ++_peopleReq;
    setState(() {
      _loadingPeople = true;
      _peopleError = null;
    });

    try {
      final list = await widget.loadPeople(
        classSectionId: _section,
        employeeTypeId: _type,
      );
      if (req != _peopleReq || !mounted) return;
      setState(() {
        _people = list;
        _loadingPeople = false;
      });
    } catch (_) {
      if (req != _peopleReq || !mounted) return;
      setState(() {
        _peopleError = "Couldn't load names. Tap to retry.";
        _loadingPeople = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _kind = null;
      _section = null;
      _type = null;
      _userId = null;
      _people = const [];
      _peopleError = null;
      _peopleReq++;
      _loadingPeople = false;
    });
  }

  void _apply() {
    String? label;
    final options = _isStudent ? widget.classSections : widget.employeeTypes;
    for (final o in options) {
      if (o.id == _groupId) {
        label = o.title;
        break;
      }
    }

    String? name;
    for (final p in _people) {
      if (p.id == _userId) {
        name = p.name;
        break;
      }
    }

    Navigator.pop(
      context,
      _FilterResult(
        kind: _kind,
        classSectionId: _isStudent ? _section : null,
        classSectionLabel: _isStudent ? label : null,
        employeeTypeId: _isStudent ? null : _type,
        employeeTypeLabel: _isStudent ? null : label,
        userId: _userId,
        userName: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupOptions =
    _isStudent ? widget.classSections : widget.employeeTypes;

    // Guard against a stale value that is no longer in the list.
    final safeGroupId =
    groupOptions.any((o) => o.id == _groupId) ? _groupId : null;
    final safeUserId = _people.any((p) => p.id == _userId) ? _userId : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                      ),
                    ),
                    if (_hasSelection)
                      TextButton(
                        onPressed: _reset,
                        child: const Text('Reset',
                            style: TextStyle(color: AppColors.red)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    // 1 — Student / Employee
                    _DropdownField<PersonKind>(
                      label: 'Category',
                      hint: 'Select student or employee',
                      value: _kind,
                      onChanged: _onKindChanged,
                      items: const [
                        DropdownMenuItem(
                          value: PersonKind.student,
                          child: _DropdownRow(
                              icon: Icons.school_rounded, text: 'Student'),
                        ),
                        DropdownMenuItem(
                          value: PersonKind.staff,
                          child: _DropdownRow(
                              icon: Icons.badge_rounded, text: 'Employee'),
                        ),
                      ],
                    ),

                    // 2 — Class section / Staff type
                    _DropdownField<int>(
                      label: _isStudent ? 'Class section' : 'Staff type',
                      hint: _kind == null
                          ? 'Pick a category first'
                          : (groupOptions.isEmpty
                          ? 'No options available'
                          : (_isStudent
                          ? 'Select a class section'
                          : 'Select a staff type')),
                      value: safeGroupId,
                      enabled: _kind != null && groupOptions.isNotEmpty,
                      onChanged: _onGroupChanged,
                      items: groupOptions
                          .map((o) => DropdownMenuItem(
                        value: o.id,
                        child: Text(o.title,
                            overflow: TextOverflow.ellipsis),
                      ))
                          .toList(),
                    ),

                    // 3 — Name
                    _DropdownField<int>(
                      label: 'Name',
                      hint: _groupId == null
                          ? (_isStudent
                          ? 'Pick a class section first'
                          : 'Pick a staff type first')
                          : (_loadingPeople
                          ? 'Loading names…'
                          : (_people.isEmpty
                          ? 'No names in this group'
                          : 'Select a name')),
                      value: safeUserId,
                      enabled: _groupId != null &&
                          _people.isNotEmpty &&
                          !_loadingPeople,
                      loading: _loadingPeople,
                      onChanged: (id) {
                        HapticFeedback.selectionClick();
                        setState(() => _userId = id);
                      },
                      items: _people
                          .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(_titleCase(p.name),
                            overflow: TextOverflow.ellipsis),
                      ))
                          .toList(),
                    ),

                    if (_peopleError != null)
                      GestureDetector(
                        onTap: _loadPeople,
                        child: Row(
                          children: [
                            const Icon(Icons.refresh_rounded,
                                size: 15, color: AppColors.red),
                            const SizedBox(width: 6),
                            Text(
                              _peopleError!,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.red),
                            ),
                          ],
                        ),
                      ),

                    if (safeUserId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isStudent
                              ? 'Showing messages for this student only.'
                              : 'Showing messages for this employee only.',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _apply,
                      child: const Text(
                        'Apply filter',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A labelled dropdown that matches the report's card styling.
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    final filled = value != null;

    final hintText = Text(
      hint,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14.5, color: AppColors.muted),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: active ? Colors.white : AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: filled ? AppColors.red : AppColors.line,
                width: filled ? 1.4 : 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                menuMaxHeight: 360,
                borderRadius: BorderRadius.circular(14),
                hint: hintText,
                disabledHint: hintText,
                elevation: 3,
                icon: loading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.red),
                )
                    : Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: active ? AppColors.red : AppColors.muted,
                ),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
                onChanged: active ? onChanged : null,
                items: items,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.red),
        const SizedBox(width: 10),
        Text(text),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// MESSAGE DETAIL SHEET
/// ---------------------------------------------------------------------------
class _MessageSheet extends StatelessWidget {
  const _MessageSheet({required this.message, required this.onOpenChat});

  final MessageItem message;
  final void Function(MessagePerson) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final m = message;

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    _PartyRow(
                      label: 'From',
                      person: m.sender,
                      // onTap: () => onOpenChat(m.sender),
                      // onTap: () {
                      //
                      // },
                    ),
                    const SizedBox(height: 12),
                    _PartyRow(
                      label: 'To',
                      person: m.receiver,
                      extra: m.totalReceivers > 1
                          ? '+${m.totalReceivers - 1} more'
                          : null,
                      // onTap: () => onOpenChat(m.receiver),
                      // onTap: () {
                      //
                      // },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => onOpenChat(m.sender),
                        icon: const Icon(Icons.more, size: 18),
                        label: Text(
                          // 'Open chat with ${_firstName(m.sender.name)}',
                          'View Detail',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    if (m.title != null) ...[
                      Text(
                        m.title!,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (m.body != null)
                      SelectableText(
                        m.body!,
                        style: const TextStyle(
                            fontSize: 14.5, color: AppColors.ink, height: 1.5),
                      )
                    else if (!m.hasAttachment)
                      const Text('No message body.',
                          style:
                          TextStyle(fontSize: 14, color: AppColors.muted)),
                    if (m.hasAttachment) ...[
                      const SizedBox(height: 16),
                      _AttachmentBlock(message: m),
                    ],
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.line, height: 1),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Sent', value: m.createdAtRaw),
                    _InfoRow(
                        label: 'Status', value: m.isUnread ? 'Unread' : 'Read'),
                    _InfoRow(label: 'Receivers', value: '${m.totalReceivers}'),
                    _InfoRow(label: 'Seen by', value: '${m.seenByReceivers}'),
                    // _InfoRow(label: 'Message ID', value: '${m.id}'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.label,
    required this.person,
    this.extra,
    // this.onTap,
  });

  final String label;
  final MessagePerson person;
  final String? extra;
  // final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              _Avatar(person: person, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(
                      _titleCase(person.name) +
                          (extra == null ? '' : '  $extra'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _KindBadge(isStudent: person.isStudent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            person.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // if (onTap != null)
              //   const Icon(Icons.chevron_right_rounded,
              //       size: 22, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

String _firstName(String name) {
  final parts =
  name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return 'this person';
  return _titleCase(parts.first);
}

class _AttachmentBlock extends StatelessWidget {
  const _AttachmentBlock({required this.message});

  final MessageItem message;

  @override
  Widget build(BuildContext context) {
    if (!message.attachmentIsImage) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded,
                size: 20, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.attachment!.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImageViewer(url: message.attachment!),
          fullscreenDialog: true,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          message.attachment!,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 140,
            alignment: Alignment.center,
            color: AppColors.canvas,
            child: const Text('Image unavailable',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String input) {
  return input
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) =>
  w.length == 1 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}