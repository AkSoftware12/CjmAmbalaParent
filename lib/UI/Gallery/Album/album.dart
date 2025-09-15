
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../../CommonCalling/data_not_found.dart';
import '../../../constants.dart';
import '../ImageList/image_list.dart' show ImageListScreen;



// Album and AlbumImage classes (unchanged)
class Album {
  final String coverImageUrl;
  final String albumName;
  final String eventDate;
  final List<AlbumImage> albumImages;

  Album({
    required this.coverImageUrl,
    required this.albumName,
    required this.eventDate,
    required this.albumImages,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    var albumImageList = json['album_image'] as List<dynamic>?;
    List<AlbumImage> images = albumImageList != null
        ? albumImageList
              .map((imageJson) => AlbumImage.fromJson(imageJson))
              .toList()
        : [];

    return Album(
      coverImageUrl: json['cover_image_url'] ?? '',
      albumName: json['album_name'] ?? '',
      eventDate: json['event_date'] ?? '',
      albumImages: images,
    );
  }
}

class AlbumImage {
  final int id;
  final int albumId;
  final String? videoUrl;
  final int status;
  final String entryDate;
  final String createdAt;
  final String updatedAt;
  final String imageUrlFull;

  AlbumImage({
    required this.id,
    required this.albumId,
    this.videoUrl,
    required this.status,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrlFull,
  });

  factory AlbumImage.fromJson(Map<String, dynamic> json) {
    return AlbumImage(
      id: json['id'] ?? 0,
      albumId: json['album_id'] ?? 0,
      videoUrl: json['video_url'],
      status: json['status'] ?? 0,
      entryDate: json['entry_date'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      imageUrlFull: json['image_url_full'] ?? '',
    );
  }
}

// Providers
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final apiUrlProvider = Provider<String>((ref) => ApiRoutes.getPhotos);

final galleryProvider =
    StateNotifierProvider<GalleryNotifier, AsyncValue<List<Album>>>((ref) {
      return GalleryNotifier(ref, ref.read(apiUrlProvider));
    });

// Gallery Notifier
class GalleryNotifier extends StateNotifier<AsyncValue<List<Album>>> {
  final Ref ref;
  final String apiUrl;
  int _lastPage = 1;
  bool _isFetching = false;

  GalleryNotifier(this.ref, this.apiUrl) : super(const AsyncValue.loading()) {
    fetchSubjectData(page: 1);
  }

  bool get isFetching => _isFetching;

  Future<void> fetchSubjectData({required int page}) async {
    if (_isFetching) return;

    _isFetching = true;
    try {
      state = const AsyncValue.loading();

      final client = ref.read(httpClientProvider);
      final prefs = await ref.read(sharedPrefsProvider.future);
      final token = prefs.getString('token');

      // if (token == null || token.isEmpty) {
      //   state = AsyncValue.error(
      //     Exception('Authentication token not found'),
      //     StackTrace.current,
      //   );
      //   _isFetching = false;
      //   return;
      // }
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await client.get(
        Uri.parse('$apiUrl?page=$page'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map<String, dynamic> &&
            jsonResponse.containsKey('album') &&
            jsonResponse['album'].containsKey('data')) {
          final List<dynamic> albumsJson = jsonResponse['album']['data'] ?? [];
          final newAlbums = albumsJson
              .map((json) => Album.fromJson(json))
              .toList();

          _lastPage = jsonResponse['album']['last_page'] ?? 1;

          state = AsyncValue.data(newAlbums);
        } else {
          state = AsyncValue.error(
            Exception('Invalid API response format'),
            StackTrace.current,
          );
        }
      } else if (response.statusCode == 401) {
        state = AsyncValue.error(
          Exception('Unauthorized: Invalid or expired token'),
          StackTrace.current,
        );
      } else {
        state = AsyncValue.error(
          Exception(
            'Failed to load gallery: ${response.statusCode} - ${response.reasonPhrase}',
          ),
          StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() async {
    await fetchSubjectData(page: 1);
  }

  int get lastPage => _lastPage;
}

// Gallery Screen
class GalleryScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _precachedImages = {};
  int _selectedPage = 1;

  @override
  void initState() {
    super.initState();
    // Removed precacheImages call from initState
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final albumsAsync = ref.read(galleryProvider); // returns AsyncValue<List<Album>>
    final albums = albumsAsync.value ?? []; // ✅ use .value
    _precacheImages(albums);
  }


  void _precacheImages(List<Album> albums) {
    for (var album in albums) {
      if (!_precachedImages.contains(album.coverImageUrl) &&
          album.coverImageUrl.isNotEmpty) {
        precacheImage(NetworkImage(album.coverImageUrl), context);
        _precachedImages.add(album.coverImageUrl);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryProvider);
    final lastPage = ref.read(galleryProvider.notifier).lastPage;

    // Precache new images when data changes
    galleryState.whenData((albums) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precacheImages(albums);
      });
    });

    // Generate list of page numbers for dropdown
    final pageOptions = List.generate(lastPage, (index) => index + 1);

    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Gallery",
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            color: AppColors.textwhite,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _precachedImages.clear();
                _selectedPage = 1;
              });
              ref.read(galleryProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: galleryState.when(
              loading: () => const Center(
                child: CupertinoActivityIndicator(
                  radius: 30,
                  color: Colors.white,
                  animating: true,
                ),
              ),
              error: (error, stackTrace) => Center(
                child: DataNotFoundWidget(
                  title: error.toString().contains('Unauthorized')
                      ? 'Please log in again'
                      : 'Error loading images: ${error.toString()}',
                ),
              ),
              data: (albums) => albums.isEmpty
                  ? const Center(
                child: DataNotFoundWidget(title: 'Image Not Available.'),
              )
                  : GridView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(0.sp),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 0.0,
                  mainAxisSpacing: 0.0,
                ),
                itemCount: albums.length,
                cacheExtent: 500,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ImageListScreen(data: albums[index]),
                        ),
                      );
                    },
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(1.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: double.infinity,
                                child: CachedNetworkImage(
                                  imageUrl: albums[index].coverImageUrl,
                                  fit: BoxFit.cover,
                                  height: 100.sp,
                                  placeholder: (context, url) =>
                                  const Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 20,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4.h),
                                Text(
                                  albums[index].albumName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                _buildInfoRow(
                                  Icons.calendar_today,
                                  'Event Date: ${albums[index].eventDate}',
                                ),
                                _buildInfoRow(
                                  Icons.photo_library,
                                  'Total Photo(s): ${albums[index].albumImages.length}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (lastPage > 1) // Only show dropdown if there are multiple pages
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black26, // Dark modern base
                    Colors.black26,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10.r,
                    offset: Offset(0, 4.h),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 10.r,
                    offset: Offset(0, -2.h),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Page: ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'Roboto', // Add google_fonts package for this
                    ),
                  ),
                  SizedBox(width: 10.w),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedPage,
                      dropdownColor: Color(0xFF1C2526), // Matches container gradient
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Roboto',
                      ),
                      icon: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 26.sp,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      items: pageOptions.map((page) {
                        return DropdownMenuItem<int>(
                          value: page,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              page.toString(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(page == _selectedPage ? 1.0 : 0.7),
                                fontSize: 15.sp,
                                fontWeight: page == _selectedPage ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null && value != _selectedPage) {
                          setState(() {
                            _selectedPage = value;
                          });
                          ref.read(galleryProvider.notifier).fetchSubjectData(page: value);
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.h, horizontal: 0.h),
      child: Row(
        children: [
          Icon(icon, size: 10.sp, color: Colors.blueAccent),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}