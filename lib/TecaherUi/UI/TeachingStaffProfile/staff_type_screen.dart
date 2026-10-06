import 'dart:convert';
import 'package:avi/TecaherUi/UI/TeachingStaffProfile/teaching_staff_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../constants.dart';


// ---------------- Model ----------------
class StaffType {
  final int id;
  final String title;
  final int priorityOrder;

  StaffType({required this.id, required this.title, required this.priorityOrder});

  factory StaffType.fromJson(Map<String, dynamic> json) {
    return StaffType(
      id: json['id'] ?? 0,
      title: (json['title'] ?? '').toString(),
      priorityOrder: json['priority_order'] ?? 0,
    );
  }

  IconData get icon {
    final t = title.toLowerCase();
    if (t.contains('head') || t.contains('principal')) return Icons.workspace_premium_rounded;
    if (t.contains('admin')) return Icons.admin_panel_settings_rounded;
    if (t.contains('non')) return Icons.badge_rounded; // check before "teaching"
    if (t.contains('teaching')) return Icons.school_rounded;
    if (t.contains('support')) return Icons.handyman_rounded;
    if (t.contains('temporary')) return Icons.schedule_rounded;
    return Icons.groups_rounded;
  }

  /// Same color as the top bar for every card
  Color get accent => AppColors.primary;
}

// ---------------- Screen ----------------
class StaffTypeScreen extends StatefulWidget {
  const StaffTypeScreen({super.key});

  @override
  State<StaffTypeScreen> createState() => _StaffTypeScreenState();
}

class _StaffTypeScreenState extends State<StaffTypeScreen> {
  late Future<List<StaffType>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchStaffTypes();
  }

  Future<List<StaffType>> fetchStaffTypes() async {
    final response = await http.get(Uri.parse(ApiRoutes.getStaffType)).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception('Failed to load data');
    }

    final List list = data['staff_type'] ?? [];
    // Same order as the API response
    return list.map((e) => StaffType.fromJson(e)).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = fetchStaffTypes());
    try {
      await _future;
    } catch (_) {}
  }

  void _openProfile(StaffType item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeachingStaffProfile(id: item.id)),
    );
  }

  /// 2 columns on phones, 3 on large phones / small tablets, 4 on tablets
  int _columns(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = _columns(width);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<StaffType>>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final staff = snapshot.data ?? [];

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _Header(count: loading ? null : staff.length),
                if (loading)
                  _LoadingGrid(columns: columns)
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorView(
                      message: snapshot.error.toString().replaceFirst('Exception: ', ''),
                      onRetry: _refresh,
                    ),
                  )
                else if (staff.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_rounded, size: 56, color: AppColors.subtext),
                            const SizedBox(height: 10),
                            Text('No staff categories yet',
                                style: TextStyle(color: AppColors.subtext, fontSize: 15)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      sliver: SliverGrid.builder(
                        itemCount: staff.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.88,
                        ),
                        itemBuilder: (context, index) => _AnimatedEntry(
                          index: index,
                          child: _StaffCard(
                            item: staff[index],
                            onTap: () => _openProfile(staff[index]),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Header ----------------
class _Header extends StatelessWidget {
  final int? count;
  const _Header({this.count});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('Staff', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------- Grid card ----------------
class _StaffCard extends StatefulWidget {
  final StaffType item;
  final VoidCallback onTap;
  const _StaffCard({required this.item, required this.onTap});

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.item.accent;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            splashColor: accent.withOpacity(0.10),
            highlightColor: accent.withOpacity(0.05),
            child: Stack(
              children: [
                // Tinted corner blob
                Positioned(
                  right: -36,
                  top: -36,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Accent strip at the bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 4, color: accent),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon tile
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(widget.item.icon, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'View staff',
                            style: TextStyle(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_forward_rounded, color: accent, size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- One-time staggered entry animation ----------------
class _AnimatedEntry extends StatelessWidget {
  final int index;
  final Widget child;
  const _AnimatedEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 80),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
      ),
      child: child,
    );
  }
}

// ---------------- Loading skeleton (grid) ----------------
class _LoadingGrid extends StatefulWidget {
  final int columns;
  const _LoadingGrid({required this.columns});

  @override
  State<_LoadingGrid> createState() => _LoadingGridState();
}

class _LoadingGridState extends State<_LoadingGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      sliver: SliverGrid.builder(
        itemCount: 6,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.columns,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.88,
        ),
        itemBuilder: (_, __) => FadeTransition(
          opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(54, 54, 16),
                const Spacer(),
                _bar(110, 14, 7),
                const SizedBox(height: 8),
                _bar(80, 10, 5),
                const SizedBox(height: 16),
                _bar(60, 10, 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(double w, double h, double r) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(r),
    ),
  );
}

// ---------------- Error view ----------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            "Couldn't load staff types",
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check that your phone is on the same Wi-Fi as the server.\n$message',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtext, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}