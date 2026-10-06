import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// CONFIG
/// ---------------------------------------------------------------------------
class ApiConfig {
  ApiConfig._();

  /// Point this at your server.
  static const String baseUrl = 'https://softcjm.cjmambala.co.in';

  /// Some responses still return photo links on the old local IP.
  /// Those are rewritten to the live domain. Empty this list once the
  /// server returns correct links.
  static const List<String> legacyPhotoHosts = [
    'http://192.168.1.10/cjm_ambala12',
    'http://192.168.1.5/cjm_ambala12',
  ];

  static String? fixPhotoUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    for (final host in legacyPhotoHosts) {
      if (url.startsWith(host)) return '$baseUrl${url.substring(host.length)}';
    }
    return url;
  }

  /// Used only when no token has been saved yet.
  /// Set it to an empty string once login is in place.
  static const String devFallbackToken =
      'OpxsBb5jGJdq7fSLpNFFGwHW6d6WwJG8hMw7T5Bko8KARdg09GW9tahaLL9W';

  static Map<String, String> headersWith(String? token) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    // If the backend expects a plain header, drop the Bearer line and use:
    // if (token != null && token.isNotEmpty) 'token': token,
  };

  static const Duration timeout = Duration(seconds: 20);
}

/// ---------------------------------------------------------------------------
/// TOKEN STORE (SharedPreferences)
/// ---------------------------------------------------------------------------
class TokenStore {
  TokenStore._();

  static const String _key = 'auth_token';

  /// In-memory cache so every request does not hit disk.
  static String? _cached;
  static bool _loaded = false;

  /// Call once at startup, inside main() before runApp.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(_key);

    // First run with nothing saved: seed the dev token.
    if ((_cached == null || _cached!.isEmpty) &&
        ApiConfig.devFallbackToken.isNotEmpty) {
      _cached = ApiConfig.devFallbackToken;
      await prefs.setString(_key, _cached!);
    }
    _loaded = true;
  }

  /// Reads the token, loading it from prefs if the cache is empty.
  static Future<String?> read() async {
    if (!_loaded) await init();
    return _cached;
  }

  /// Save a new token after login.
  static Future<void> save(String token) async {
    _cached = token;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  /// Called on logout or when the token expires.
  static Future<void> clear() async {
    _cached = null;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// ---------------------------------------------------------------------------
/// MODELS
/// ---------------------------------------------------------------------------
class FilterOption {
  final int id;
  final String title;

  const FilterOption({required this.id, required this.title});

  factory FilterOption.fromJson(Map<String, dynamic> j) => FilterOption(
    id: _asInt(j['id']) ?? 0,
    title: (j['title'] ?? j['name'] ?? '').toString(),
  );

  @override
  bool operator ==(Object other) => other is FilterOption && other.id == id;

  @override
  int get hashCode => id;
}

enum PersonKind { student, staff }

/// API expects user_type=student for students and user_type=user for staff.
String userTypeParam(PersonKind kind) =>
    kind == PersonKind.student ? 'student' : 'user';

class PersonResult {
  final PersonKind kind;
  final int id;
  final String name;
  final String? photo;
  final String? employeeType;
  final int? classSectionId;

  const PersonResult({
    required this.kind,
    required this.id,
    required this.name,
    this.photo,
    this.employeeType,
    this.classSectionId,
  });

  factory PersonResult.fromJson(Map<String, dynamic> j, {PersonKind? fallback}) {
    final rawType = (j['type'] ?? '').toString().toLowerCase();
    final kind = rawType.contains('student')
        ? PersonKind.student
        : (rawType.isEmpty ? (fallback ?? PersonKind.staff) : PersonKind.staff);

    final photo = (j['photo'] ?? j['image'] ?? j['avatar'])?.toString();

    return PersonResult(
      kind: kind,
      id: _asInt(j['id']) ?? 0,
      name: (j['name'] ?? j['title'] ?? '').toString().trim(),
      photo: (photo == null || photo.isEmpty || photo == 'null')
          ? null
          : ApiConfig.fixPhotoUrl(photo),
      employeeType: j['employee_type']?.toString(),
      classSectionId: _asInt(j['class_section_id']),
    );
  }

  String initials() {
    final parts =
    name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length <= 2 ? p : p.substring(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class MasterReportData {
  final List<FilterOption> classSections;
  final List<FilterOption> employeeTypes;
  final List<PersonResult> students;
  final List<PersonResult> staff;
  final int? total;

  const MasterReportData({
    this.classSections = const [],
    this.employeeTypes = const [],
    this.students = const [],
    this.staff = const [],
    this.total,
  });

  int get count => students.length + staff.length;
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// MESSAGE REPORT MODELS
/// ---------------------------------------------------------------------------

/// Sender / receiver inside a message row.
class MessagePerson {
  final PersonKind kind;
  final int id;
  final String name;
  final String? photo;
  final String? className;
  final String? section;
  final String? designation;

  /// Parent message ka new_msg_id — taaki sirf sender/receiver object
  /// paas hone par bhi message id mil jaaye.
  final int newMsgId;

  const MessagePerson({
    required this.kind,
    required this.id,
    required this.name,
    this.photo,
    this.className,
    this.section,
    this.designation,
    this.newMsgId = 0,
  });

  bool get isStudent => kind == PersonKind.student;

  /// "UKG - C" for a student, "Teaching Staff" for an employee.
  String get detail {
    if (isStudent) {
      final parts = [className, section]
          .where((e) => e != null && e.trim().isNotEmpty)
          .toList();
      return parts.isEmpty ? 'Student' : parts.join(' - ');
    }
    final d = designation?.trim();
    return (d == null || d.isEmpty) ? 'Staff' : d;
  }

  String initials() {
    final parts =
    name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length <= 2 ? p : p.substring(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory MessagePerson.fromJson(Map<String, dynamic> j, {int newMsgId = 0}) {
    final type = (j['type'] ?? '').toString().toLowerCase();
    final photo = j['photo']?.toString();
    return MessagePerson(
      kind: type.contains('student') ? PersonKind.student : PersonKind.staff,
      id: _asInt(j['id']) ?? 0,
      name: (j['name'] ?? '').toString().trim(),
      photo: (photo == null || photo.isEmpty || photo == 'null')
          ? null
          : ApiConfig.fixPhotoUrl(photo),
      className: _text(j['class']),
      section: _text(j['section']),
      designation: _text(j['designation']),
      newMsgId: newMsgId,
    );
  }
}

class MessageItem {
  final int id; // new_msg_id
  final int sampleId; // sample_message_id
  final String? title;
  final String? body;
  final String? attachment;
  final MessagePerson sender;
  final MessagePerson receiver;
  final int? receiverType; // 1 = Employee, 2 = Student, 3 = Both
  final int totalReceivers;
  final int seenByReceivers;
  final int unseenByReceivers;
  final String createdAtRaw;
  final DateTime? createdAt;

  const MessageItem({
    required this.id,
    required this.sampleId,
    required this.sender,
    required this.receiver,
    this.title,
    this.body,
    this.attachment,
    this.receiverType,
    this.totalReceivers = 1,
    this.seenByReceivers = 0,
    this.unseenByReceivers = 0,
    required this.createdAtRaw,
    this.createdAt,
  });

  /// Alias — call-site par saaf padhne ke liye.
  int get newMsgId => id;

  bool get isUnread => unseenByReceivers > 0;

  /// receiver_type ka label: 1 = Employee, 2 = Student, 3 = dono.
  String? get receiverTypeLabel {
    switch (receiverType) {
      case 1:
        return 'Employee';
      case 2:
        return 'Student';
      case 3:
        return 'Employee & Student';
    }
    return null;
  }

  bool get hasAttachment => attachment != null && attachment!.isNotEmpty;

  bool get attachmentIsImage {
    if (!hasAttachment) return false;
    final u = attachment!.toLowerCase();
    return u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.webp') ||
        u.endsWith('.gif');
  }

  /// One-line preview for the list.
  String get preview {
    final t = body?.trim();
    if (t != null && t.isNotEmpty) return t.replaceAll(RegExp(r'\s+'), ' ');
    if (hasAttachment) return 'Attachment';
    return 'No message body';
  }

  factory MessageItem.fromJson(Map<String, dynamic> j) {
    final raw = (j['created_at'] ?? '').toString();
    final att = _text(j['attachment']);
    final newMsgId = _asInt(j['new_msg_id'] ?? j['id']) ?? 0;

    return MessageItem(
      id: newMsgId,
      sampleId: _asInt(j['sample_message_id']) ?? 0,
      title: _text(j['title']),
      body: _text(j['body']),
      attachment: att == null ? null : ApiConfig.fixPhotoUrl(att),
      sender: MessagePerson.fromJson(
        Map<String, dynamic>.from(j['sender'] as Map? ?? const {}),
        newMsgId: newMsgId,
      ),
      receiver: MessagePerson.fromJson(
        Map<String, dynamic>.from(j['receiver'] as Map? ?? const {}),
        newMsgId: newMsgId,
      ),
      receiverType: _asInt(j['receiver_type']),
      totalReceivers: _asInt(j['total_receivers']) ?? 1,
      seenByReceivers: _asInt(j['seen_by_receivers']) ?? 0,
      unseenByReceivers: _asInt(j['unseen_by_receivers']) ?? 0,
      createdAtRaw: raw,
      createdAt: _parseDate(raw),
    );
  }
}

class ReportStats {
  final int total;
  final int unread;
  final int read;
  final int withAttachment;
  final int uniqueSenders;
  final int uniqueReceivers;
  final int totalBroadcasts;

  const ReportStats({
    this.total = 0,
    this.unread = 0,
    this.read = 0,
    this.withAttachment = 0,
    this.uniqueSenders = 0,
    this.uniqueReceivers = 0,
    this.totalBroadcasts = 0,
  });

  factory ReportStats.fromJson(Map<String, dynamic> j) => ReportStats(
    total: _asInt(j['total']) ?? 0,
    unread: _asInt(j['unread']) ?? 0,
    read: _asInt(j['read']) ?? 0,
    withAttachment: _asInt(j['with_attachment']) ?? 0,
    uniqueSenders: _asInt(j['unique_senders']) ?? 0,
    uniqueReceivers: _asInt(j['unique_receivers']) ?? 0,
    totalBroadcasts: _asInt(j['total_broadcasts']) ?? 0,
  );
}

class MasterReportPage {
  final List<MessageItem> items;
  final ReportStats stats;
  final int currentPage;
  final int lastPage;
  final int total;

  /// Filled only if the report response also carries the dropdown lists.
  final List<FilterOption> classSections;
  final List<FilterOption> employeeTypes;

  const MasterReportPage({
    required this.items,
    required this.stats,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.classSections = const [],
    this.employeeTypes = const [],
  });

  bool get hasMore => currentPage < lastPage;
}

/// ---------------------------------------------------------------------------
/// SERVICE
/// ---------------------------------------------------------------------------
class MasterReportApi {
  MasterReportApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void dispose() => _client.close();

  /// GET /api/master-report/filters?class_section_id=&employee_type_id=
  /// Dropdown options + the people of the chosen class / staff type.
  Future<MasterReportData> filters({
    int? classSectionId,
    int? employeeTypeId,
  }) async {
    final body = await _request('/api/master-report/filters', {
      'class_section_id': classSectionId?.toString(),
      'employee_type_id': employeeTypeId?.toString(),
    });
    return _parse(body);
  }

  /// GET /api/master-report?q=&class_section_id=&employee_type_id=&user_type=&user_id=&page=
  /// Ye messages return karta hai — list isi se banti hai.
  Future<MasterReportPage> report({
    String? q,
    int? classSectionId,
    int? employeeTypeId,
    PersonKind? userType,
    int? userId,
    int page = 1,
  }) async {
    final body = await _request('/api/master-report', {
      'q': (q == null || q.trim().isEmpty) ? null : q.trim(),
      'class_section_id': classSectionId?.toString(),
      'employee_type_id': employeeTypeId?.toString(),
      'user_type': userType == null ? null : userTypeParam(userType),
      'user_id': userId?.toString(),
      'page': page > 1 ? '$page' : null,
    });
    return _parseReport(body);
  }

  /// Purana people-search wala helper. Ab list messages dikhati hai,
  /// isliye screen ise use nahi karti — compatibility ke liye rakha hai.
  @Deprecated('Use report() — /api/master-report ab messages return karta hai.')
  Future<MasterReportData> search({
    required String q,
    int? classSectionId,
    int? employeeTypeId,
  }) async {
    final body = await _request('/api/master-report', {
      'q': q,
      'class_section_id': classSectionId?.toString(),
      'employee_type_id': employeeTypeId?.toString(),
    });
    return _parse(body);
  }

  // ---------------------------------------------------------------------------
  // HTTP
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _request(
      String path, Map<String, String?> query) async {
    final params = <String, String>{};
    query.forEach((k, v) {
      if (v != null && v.isNotEmpty) params[k] = v;
    });

    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: params.isEmpty ? null : params);

    final token = await TokenStore.read();

    late http.Response res;
    try {
      res = await _client
          .get(uri, headers: ApiConfig.headersWith(token))
          .timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException(
          "The server took too long to respond. Try again.");
    } catch (_) {
      throw const ApiException(
          "Could not reach the server. Check your connection.");
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const ApiException("Your session has expired. Sign in again.");
    }

    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }

    late final dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw const ApiException("The response could not be read.");
    }

    if (body is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response format.');
    }

    final status = body['status']?.toString().toLowerCase();
    if (status != null && status != 'success' && status != 'ok') {
      throw ApiException(body['message']?.toString() ?? "The request failed.");
    }

    return body;
  }

  // ---------------------------------------------------------------------------
  // PARSERS
  // ---------------------------------------------------------------------------

  /// Messages + stats + pagination.
  MasterReportPage _parseReport(Map<String, dynamic> j) {
    final raw = j['data'];
    final items = <MessageItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        // Skip anything that is clearly not a message row.
        if (map['sender'] is! Map && map['receiver'] is! Map) continue;
        items.add(MessageItem.fromJson(map));
      }
    }

    final stats = j['stats'];
    final pag = j['pagination'];

    return MasterReportPage(
      items: items,
      stats: stats is Map
          ? ReportStats.fromJson(Map<String, dynamic>.from(stats))
          : const ReportStats(),
      currentPage: pag is Map ? (_asInt(pag['current_page']) ?? 1) : 1,
      lastPage: pag is Map ? (_asInt(pag['last_page']) ?? 1) : 1,
      total: pag is Map ? (_asInt(pag['total']) ?? items.length) : items.length,
      classSections: _options(j, 'class_sections'),
      employeeTypes: _options(j, 'employee_types'),
    );
  }

  /// Tolerant parser: survives small changes in the response shape.
  MasterReportData _parse(Map<String, dynamic> j) {
    final students = <PersonResult>[];
    final staff = <PersonResult>[];

    void add(dynamic list, PersonKind fallback) {
      if (list is! List) return;
      for (final e in list) {
        if (e is! Map) continue;
        final p = PersonResult.fromJson(Map<String, dynamic>.from(e),
            fallback: fallback);
        if (p.name.isEmpty) continue;
        (p.kind == PersonKind.student ? students : staff).add(p);
      }
    }

    add(_pick(j, const ['students']), PersonKind.student);
    add(_pick(j, const ['users', 'staff', 'employees']), PersonKind.staff);

    // The search endpoint may return a single mixed list.
    if (students.isEmpty && staff.isEmpty) {
      add(_pick(j, const ['results', 'data', 'items', 'records']),
          PersonKind.staff);
    }

    int? total;
    final stats = j['stats'];
    if (stats is Map) total = _asInt(stats['total']);
    total ??= _asInt(j['total']);

    return MasterReportData(
      classSections: _options(j, 'class_sections'),
      employeeTypes: _options(j, 'employee_types'),
      students: students,
      staff: staff,
      total: total,
    );
  }

  List<FilterOption> _options(Map<String, dynamic> j, String key) {
    final v = _pick(j, [key]);
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => FilterOption.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.title.isNotEmpty)
        .toList();
  }

  dynamic _pick(Map j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v is List) return v;
    }
    final d = j['data'];
    if (d is Map) {
      for (final k in keys) {
        final v = d[k];
        if (v is List) return v;
      }
    }
    return null;
  }
}

/// ---------------------------------------------------------------------------
/// HELPERS
/// ---------------------------------------------------------------------------
int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _text(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return (s.isEmpty || s.toLowerCase() == 'null') ? null : s;
}

/// "05-09-2026 22:04" -> DateTime
DateTime? _parseDate(String raw) {
  final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})(?:\s+(\d{1,2}):(\d{2}))?')
      .firstMatch(raw.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(3)!),
    int.parse(m.group(2)!),
    int.parse(m.group(1)!),
    int.tryParse(m.group(4) ?? '0') ?? 0,
    int.tryParse(m.group(5) ?? '0') ?? 0,
  );
}