import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../constants.dart';

class DataNotFoundWidget extends StatelessWidget {
  final String title;
  const DataNotFoundWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    );
  }
}

// =============================
// ✅ MODELS
// =============================
class EbooksResponse {
  final bool success;
  final String message;
  final EbooksPage data;

  EbooksResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory EbooksResponse.fromJson(Map<String, dynamic> json) {
    return EbooksResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: EbooksPage.fromJson(json['data'] ?? {}),
    );
  }
}

class EbooksPage {
  final int currentPage;
  final int lastPage;
  final int total;
  final List<EbookItem> items;

  EbooksPage({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.items,
  });

  factory EbooksPage.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>?) ?? [];
    return EbooksPage(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      total: json['total'] ?? 0,
      items: list.map((e) => EbookItem.fromJson(e)).toList(),
    );
  }
}

class EbookItem {
  final int id;
  final String title;
  final String? description;
  final String pdfUrl;
  final String thumbUrl; // API gives "", but we are NOT using thumbnail now
  final int status;

  EbookItem({
    required this.id,
    required this.title,
    required this.description,
    required this.pdfUrl,
    required this.thumbUrl,
    required this.status,
  });

  factory EbookItem.fromJson(Map<String, dynamic> json) {
    return EbookItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      pdfUrl: json['pdf_url'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      status: json['status'] ?? 0,
    );
  }
}

// =============================
// ✅ PROVIDERS
// =============================
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final apiUrlProvider = Provider<String>((ref) => ApiRoutes.getEbooks);

final ebooksProvider =
StateNotifierProvider<EbooksNotifier, AsyncValue<List<EbookItem>>>((ref) {
  return EbooksNotifier(ref, ref.read(apiUrlProvider));
});

// =============================
// ✅ NOTIFIER (pagination supported)
// =============================
class EbooksNotifier extends StateNotifier<AsyncValue<List<EbookItem>>> {
  final Ref ref;
  final String apiUrl;

  int _lastPage = 1;
  bool _isFetching = false;

  EbooksNotifier(this.ref, this.apiUrl) : super(const AsyncValue.loading()) {
    fetchEbooks(page: 1);
  }

  int get lastPage => _lastPage;
  bool get isFetching => _isFetching;

  Future<void> fetchEbooks({required int page}) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      state = const AsyncValue.loading();

      final client = ref.read(httpClientProvider);
      final prefs = await ref.read(sharedPrefsProvider.future);
      final token = prefs.getString('token');

      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await client.get(
        Uri.parse('$apiUrl?page=$page'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> jsonMap = jsonDecode(res.body);
        final parsed = EbooksResponse.fromJson(jsonMap);

        _lastPage = parsed.data.lastPage;
        state = AsyncValue.data(parsed.data.items);
      } else if (res.statusCode == 401) {
        state = AsyncValue.error(
          Exception('Unauthorized: Invalid or expired token'),
          StackTrace.current,
        );
      } else {
        state = AsyncValue.error(
          Exception('Failed: ${res.statusCode} - ${res.reasonPhrase}'),
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() async {
    await fetchEbooks(page: 1);
  }
}



class EbooksScreen extends ConsumerStatefulWidget {
  const EbooksScreen({super.key});

  @override
  ConsumerState<EbooksScreen> createState() => _EbooksScreenState();
}

class _EbooksScreenState extends ConsumerState<EbooksScreen> {
  int _selectedPage = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ebooksProvider);
    final notifier = ref.read(ebooksProvider.notifier);
    final lastPage = notifier.lastPage;
    final pageOptions = List.generate(lastPage, (i) => i + 1);

    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Ebooks",
          style: GoogleFonts.montserrat(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textwhite,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _selectedPage = 1);
              notifier.refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.when(
              loading: () => const Center(
                child: CupertinoActivityIndicator(radius: 30, color: Colors.white),
              ),
              error: (e, st) => Center(
                child: DataNotFoundWidget(
                  title: e.toString().contains('Unauthorized')
                      ? 'Please log in again '
                      : 'Error: ${e.toString()}',
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: DataNotFoundWidget(title: 'Ebooks Not Available.'),
                  );
                }

                return GridView.builder(
                  key: PageStorageKey('ebooks_page_$_selectedPage'), // ✅ scroll retain
                  cacheExtent: 1200, // ✅ pre-build offscreen items (smooth)
                  padding: EdgeInsets.all(5.sp),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 0,
                    mainAxisSpacing: 0,
                    childAspectRatio: 0.67,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final ebook = items[index];

                    return GestureDetector(
                      onTap: () {
                        if (ebook.pdfUrl.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NetworkPdfView(
                              pdfUrl: ebook.pdfUrl,
                              title: ebook.title,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Card(
                            elevation: 4,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(0.sp),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(5.r),topRight: Radius.circular(5.r)),
                                    child: SizedBox(
                                      height: 140.sp,
                                      width: double.infinity,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(14.r),
                                        ),
                                        // ✅ FAST + CACHE (no re-load)
                                        child: _EbookThumb(url: ebook.thumbUrl),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child: Text(
                                      ebook.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.sp,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✅ Pagination (same as your code)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page: ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 10.w),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPage,
                    dropdownColor: const Color(0xFF1C2526),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 26.sp,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    items: pageOptions
                        .map(
                          (p) => DropdownMenuItem<int>(
                        value: p,
                        child: Text(p.toString()),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != _selectedPage) {
                        setState(() => _selectedPage = v);
                        notifier.fetchEbooks(page: v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _EbookThumb extends StatefulWidget {
  final String url;
  const _EbookThumb({required this.url});

  @override
  State<_EbookThumb> createState() => _EbookThumbState();
}

class _EbookThumbState extends State<_EbookThumb>
    with AutomaticKeepAliveClientMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.url.isNotEmpty) {
      precacheImage(CachedNetworkImageProvider(widget.url), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.url.isEmpty) {
      return Container(
        alignment: Alignment.center,
        color: Colors.black12,
        child: const Icon(Icons.picture_as_pdf, size: 42, color: Colors.black54),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 0),
      fadeOutDuration: const Duration(milliseconds: 0),
      memCacheWidth: 400, // ✅ fast decode
      placeholder: (_, __) => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const CupertinoActivityIndicator(),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.black54),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}








class NetworkPdfView extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const NetworkPdfView({
    super.key,
    required this.pdfUrl, required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            color: AppColors.textwhite,
          ),
        ),
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        enableDoubleTapZooming: true,
      ),
    );
  }
}



