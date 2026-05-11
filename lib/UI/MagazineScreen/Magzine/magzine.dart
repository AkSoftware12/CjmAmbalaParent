import 'dart:convert';

import 'package:avi/utils/date_time_utils.dart';
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
import 'package:url_launcher/url_launcher.dart';

import '../../../constants.dart';

class DataNotFoundWidget extends StatelessWidget {
  final String title;
  const DataNotFoundWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// =============================
// ✅ MODELS FOR MAGAZINE API
// =============================

class MagazineResponse {
  final bool success;
  final MagazinePage data;

  MagazineResponse({
    required this.success,
    required this.data,
  });

  factory MagazineResponse.fromJson(Map<String, dynamic> json) {
    return MagazineResponse(
      success: json['success'] ?? false,
      data: MagazinePage.fromJson(json),
    );
  }
}

class MagazinePage {
  final int currentPage;
  final int lastPage;
  final int total;
  final List<MagazineItem> items;

  MagazinePage({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.items,
  });

  factory MagazinePage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] ?? {};
    final list = (json['data'] as List<dynamic>?) ?? [];

    return MagazinePage(
      currentPage: pagination['current_page'] ?? 1,
      lastPage: pagination['last_page'] ?? 1,
      total: pagination['total'] ?? list.length,
      items: list.map((e) => MagazineItem.fromJson(e)).toList(),
    );
  }
}

class MagazineItem {
  final int id;
  final String title;
  final String pdfUrl;
  final String thumbUrl;
  final String entryDate;
  final String? page;
  final String? size;

  MagazineItem({
    required this.id,
    required this.title,
    required this.pdfUrl,
    required this.thumbUrl,
    required this.entryDate,
    this.page,
    this.size,
  });

  factory MagazineItem.fromJson(Map<String, dynamic> json) {
    return MagazineItem(
      id: json['id'] ?? 0,
      title: json['name'] ?? '',
      pdfUrl: json['pdf'] ?? '',
      thumbUrl: json['thumbnail'] ?? '',
      entryDate: json['entry_date'] ?? '',
      page: json['no_of_pages'] ?? 'N/A',
      size: json['pdf_size'] ?? 'N/A',
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

final apiUrlProvider = Provider<String>((ref) => ApiRoutes.getMagzine);

final magazinesProvider =
StateNotifierProvider<MagazinesNotifier, AsyncValue<List<MagazineItem>>>(
      (ref) {
    return MagazinesNotifier(ref, ref.read(apiUrlProvider));
  },
);

// =============================
// ✅ NOTIFIER
// =============================

class MagazinesNotifier extends StateNotifier<AsyncValue<List<MagazineItem>>> {
  final Ref ref;
  final String apiUrl;

  int _lastPage = 1;
  bool _isFetching = false;

  MagazinesNotifier(this.ref, this.apiUrl) : super(const AsyncValue.loading()) {
    fetchMagazines(page: 1);
  }

  int get lastPage => _lastPage;
  bool get isFetching => _isFetching;

  Future<void> fetchMagazines({required int page}) async {
    if (_isFetching) return;

    _isFetching = true;

    try {
      state = const AsyncValue.loading();

      final client = ref.read(httpClientProvider);
      final prefs = await ref.read(sharedPrefsProvider.future);
      final token = prefs.getString('token');

      final headers = <String, String>{
        'Accept': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await client.get(
        Uri.parse('$apiUrl?page=$page'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> jsonMap = jsonDecode(res.body);
        final parsed = MagazineResponse.fromJson(jsonMap);

        _lastPage = parsed.data.lastPage;
        state = AsyncValue.data(parsed.data.items);
      } else if (res.statusCode == 401) {
        state = AsyncValue.error(
          Exception('Unauthorized: Please log in again'),
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
    await fetchMagazines(page: 1);
  }
}

// =============================
// ✅ SCREEN
// =============================

class MagazineScreen extends ConsumerStatefulWidget {
  const MagazineScreen({super.key});

  @override
  ConsumerState<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends ConsumerState<MagazineScreen> {
  int _selectedPage = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(magazinesProvider);
    final notifier = ref.read(magazinesProvider.notifier);
    final lastPage = notifier.lastPage;
    final pageOptions = List.generate(lastPage, (i) => i + 1);

    return Scaffold(
      // backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Magazine",
          style: GoogleFonts.montserrat(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textwhite,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
                child: CupertinoActivityIndicator(
                  radius: 30,
                  color: Colors.red,
                ),
              ),
              error: (e, st) => Center(
                child: DataNotFoundWidget(
                  title: e.toString().contains('Unauthorized')
                      ? 'Please log in again'
                      : 'Error: ${e.toString()}',
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: DataNotFoundWidget(
                      title: 'Magazine Not Available.',
                    ),
                  );
                }

                return GridView.builder(
                  key: PageStorageKey('magazine_page_$_selectedPage'),
                  cacheExtent: 1200,
                  padding: EdgeInsets.all(2.sp),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final magazine = items[index];

                    return GestureDetector(
                      // onTap: () {
                      //   if (magazine.pdfUrl.isEmpty) return;
                      //
                      //   Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (_) => NetworkPdfView(
                      //         pdfUrl: magazine.pdfUrl,
                      //         title: magazine.title,
                      //       ),
                      //     ),
                      //   );
                      // },

                      onTap: () async
                      {
                        if (magazine.pdfUrl.isEmpty) return;

                        final Uri url = Uri.parse(magazine.pdfUrl);

                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication, // device browser me open hoga
                          );
                        } else {
                          debugPrint("Could not launch ${magazine.pdfUrl}");
                        }
                      },
                      child: Card(
                        elevation: 4,
                        color: Colors.white,
                        margin: EdgeInsets.all(3.sp),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(5.r),
                                topRight: Radius.circular(5.r),
                              ),
                              child: SizedBox(
                                height: 130.sp,
                                width: double.infinity,
                                child: _MagazineThumb(url: magazine.thumbUrl),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(2.sp),
                              child: Text(
                                magazine.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.sp,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left:2.sp),
                              child: Text(
                                'No. Of Pages: ${magazine.page.toString()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.sp,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left:2.sp),
                              child: Text(
                                'PDF Size : ${magazine.size.toString()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.sp,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (magazine.entryDate.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2.sp),
                                child: Text(
                                  AppDateTimeUtils.date(magazine.entryDate)
                                 ,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (lastPage > 1)
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
                          notifier.fetchMagazines(page: v);
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

// =============================
// ✅ THUMBNAIL WIDGET
// =============================

class _MagazineThumb extends StatefulWidget {
  final String url;
  const _MagazineThumb({required this.url});

  @override
  State<_MagazineThumb> createState() => _MagazineThumbState();
}

class _MagazineThumbState extends State<_MagazineThumb>
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
        child: const Icon(
          Icons.picture_as_pdf,
          size: 42,
          color: Colors.black54,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: 400,
      placeholder: (_, __) => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const CupertinoActivityIndicator(),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image,
          color: Colors.black54,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// =============================
// ✅ PDF VIEW
// =============================

class NetworkPdfView extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const NetworkPdfView({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isValidPdf = pdfUrl.toLowerCase().endsWith('.pdf');

    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.montserrat(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textwhite,
          ),
        ),
      ),
      body: isValidPdf
          ? SfPdfViewer.network(
        pdfUrl,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        enableDoubleTapZooming: true,
      )
          : const Center(
        child: DataNotFoundWidget(
          title: 'PDF file not available.',
        ),
      ),
    );
  }
}