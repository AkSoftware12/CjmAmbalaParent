import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// Ek hi jagah saare alumni counts — dono screens (bottombar + dashboard)
/// isi ko watch karengi, to hamesha same rahenge.
class AlumniCounts {
  final int message;
  final int vacancies;
  final int fees;
  final int assignment;
  final int gallery;
  final int achievement;
  final int video;
  final int notice;
  final bool isLoading;

  const AlumniCounts({
    this.message = 0,
    this.vacancies = 0,
    this.fees = 0,
    this.assignment = 0,
    this.gallery = 0,
    this.achievement = 0,
    this.video = 0,
    this.notice = 0,
    this.isLoading = true,
  });

  AlumniCounts copyWith({
    int? message,
    int? vacancies,
    int? fees,
    int? assignment,
    int? gallery,
    int? achievement,
    int? video,
    int? notice,
    bool? isLoading,
  }) {
    return AlumniCounts(
      message: message ?? this.message,
      vacancies: vacancies ?? this.vacancies,
      fees: fees ?? this.fees,
      assignment: assignment ?? this.assignment,
      gallery: gallery ?? this.gallery,
      achievement: achievement ?? this.achievement,
      video: video ?? this.video,
      notice: notice ?? this.notice,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AlumniCountsNotifier extends StateNotifier<AlumniCounts> {
  AlumniCountsNotifier() : super(const AlumniCounts()) {
    refresh(); // pehli baar app khulte hi fetch
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('alumniToken');
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse(ApiRoutes.getAlumniCount),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = Map<String, dynamic>.from(decoded['data'] ?? {});

        state = AlumniCounts(
          message: _toInt(data['message_count']),
          vacancies: _toInt(data['vacancies_count']),
          assignment: _toInt(data['assignment_count']),
          fees: _toInt(data['fee_count']),
          gallery: _toInt(data['photo_count']),
          achievement: _toInt(data['achivement_count']),
          video: _toInt(data['video_count']),
          notice: _toInt(data['notice']),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final alumniCountsProvider =
StateNotifierProvider<AlumniCountsNotifier, AlumniCounts>(
      (ref) => AlumniCountsNotifier(),
);