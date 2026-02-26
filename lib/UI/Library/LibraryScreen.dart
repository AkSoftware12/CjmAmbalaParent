import 'dart:async';
import 'dart:convert';

import 'package:avi/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:searchable_paginated_dropdown/searchable_paginated_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../CommonCalling/data_not_found.dart';

class LibraryScreen extends StatefulWidget {
  final String appBar;

  const LibraryScreen({super.key, required this.appBar});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController textController = TextEditingController();

  late SearchableDropdownController<int> searchableDropdownController;
  late SearchableDropdownController<int> searchableDropdownController2;

  // Loading states
  bool booksLoading = true;
  bool filtersLoading = false;

  // Data lists
  List<dynamic> books = [];
  List<dynamic> filteredBooks = [];

  List<dynamic> type = [];
  List<dynamic> category = [];
  List<dynamic> publishers = [];
  List<dynamic> supplier = [];

  // Selected filters
  String? selectedType;
  String? selectedCategory;

  int selectedPublisherId = 0;
  int selectedSupplierId = 0;

  // Pagination
  int currentPage = 1;
  int perPage = 20; // change if backend supports
  int totalPages = 1; // will update from API if available
  int totalItems = 0;

  @override
  void initState() {
    super.initState();
    searchableDropdownController = SearchableDropdownController<int>();
    searchableDropdownController2 = SearchableDropdownController<int>();

    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      fetchTypeData(),
      fetchCategoryData(),
      fetchPublishersData(),
      fetchSupplierData(),
    ]);

    await fetchAssignmentsData(
      type: '',
      category: '',
      publisherId: 0,
      supplierId: 0,
      page: 1,
      key: '',
    );
  }

  @override
  void dispose() {
    textController.dispose();
    searchableDropdownController.dispose();
    searchableDropdownController2.dispose();
    super.dispose();
  }

  // ---------------------------
  // SEARCH FILTER (LOCAL)
  // ---------------------------
  void filterList(String query) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      setState(() => filteredBooks = List<dynamic>.from(books));
      return;
    }

    final List<dynamic> filtered = books.where((item) {
      if (item is! Map) return item.toString().toLowerCase().contains(q);

      final title = (item['title'] ?? '').toString().toLowerCase();
      final author = (item['author'] ?? '').toString().toLowerCase();
      final pubName = (item['publisher_name'] ?? item['publisher'] ?? '')
          .toString()
          .toLowerCase();
      final supName = (item['supplier_name'] ?? item['supplier'] ?? '')
          .toString()
          .toLowerCase();

      final status = (item['status'] ?? '').toString().toLowerCase();

      return title.contains(q) ||
          author.contains(q) ||
          pubName.contains(q) ||
          supName.contains(q) ||
          status.contains(q);
    }).toList();

    setState(() => filteredBooks = filtered);
  }

  void _clearSearch() {
    setState(() {
      textController.clear();
      filteredBooks = List<dynamic>.from(books);
      FocusScope.of(context).unfocus();
    });
  }

  // ---------------------------
  // API: BOOKS LIST (WITH PAGINATION)
  // ---------------------------
  Future<void> fetchAssignmentsData({
    required String type,
    required String category,
    required int publisherId,
    required int? supplierId,
    required String key,
    required int page,
  }) async {
    setState(() => booksLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse(ApiRoutes.getlibrary).replace(
        queryParameters: {
          "type": type,
          "category": category,
          "publisher": publisherId.toString(),
          if (supplierId != null) "supplier": supplierId.toString(),

          // ✅ Pagination params (common)
          "page": page.toString(),
          "key": key.toString(),
          "per_page": perPage.toString(),
          // if backend doesn't support, remove
          // "title": textController.text.trim(), // if backend supports server search
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        final dynamic data = jsonResponse['data'];

        List<dynamic> list = [];
        int? lastPage;
        int? total;

        // ✅ Case 1: data is direct List
        if (data is List) {
          list = data;
          lastPage = 1;
          total = list.length;
        }
        // ✅ Case 2: data is pagination map {data:[], last_page:.., total:..}
        else if (data is Map<String, dynamic>) {
          final inner = data['data'];
          if (inner is List) list = inner;

          // Support multiple possible keys
          lastPage =
              (data['last_page'] ??
                      data['lastPage'] ??
                      jsonResponse['last_page'] ??
                      jsonResponse['lastPage'])
                  as int?;
          total = (data['total'] ?? jsonResponse['total']) as int?;

          // Some APIs use meta
          final meta = data['meta'] ?? jsonResponse['meta'];
          if (meta is Map<String, dynamic>) {
            lastPage = (meta['last_page'] ?? lastPage) as int?;
            total = (meta['total'] ?? total) as int?;
          }
        }

        setState(() {
          books = list;
          filteredBooks = List<dynamic>.from(list);

          currentPage = page;
          totalPages = (lastPage != null && lastPage > 0) ? lastPage : 1;
          totalItems = total ?? totalItems;

          print('allBooks $books');

          booksLoading = false;
        });

        // Apply local search again if user typed something
        if (textController.text.trim().isNotEmpty) {
          filterList(textController.text);
        }
      } else {
        setState(() => booksLoading = false);
        debugPrint("API error: ${response.statusCode} | ${response.body}");
      }
    } catch (e) {
      setState(() => booksLoading = false);
      debugPrint("Exception: $e");
    }
  }

  // ---------------------------
  // FILTERS DATA
  // ---------------------------
  Future<void> fetchTypeData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiRoutes.getBookTypes),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() => type = (jsonResponse['data'] ?? []) as List<dynamic>);
    }
  }

  Future<void> fetchCategoryData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiRoutes.getBookCategories),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() => category = (jsonResponse['data'] ?? []) as List<dynamic>);
    }
  }

  Future<void> fetchPublishersData() async {
    setState(() => filtersLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getBookPublishers),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(
          () => publishers = (jsonResponse['data'] ?? []) as List<dynamic>,
        );
      } else {
        debugPrint("Error fetching publishers: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Publishers exception: $e");
    } finally {
      setState(() => filtersLoading = false);
    }
  }

  Future<void> fetchSupplierData() async {
    setState(() => filtersLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getBookSupplier),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(
          () => supplier = (jsonResponse['data'] ?? []) as List<dynamic>,
        );
      } else {
        debugPrint("Error fetching supplier: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Supplier exception: $e");
    } finally {
      setState(() => filtersLoading = false);
    }
  }

  // ---------------------------
  // DROPDOWN PAGINATED LIST HELPERS
  // ---------------------------
  Future<List<SearchableDropdownMenuItem<int>>> getPublisherList({
    required int page,
    String? key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final filtered = (key != null && key.isNotEmpty)
        ? publishers.where(
            (p) => (p['name'] ?? '').toString().toLowerCase().contains(
              key.toLowerCase(),
            ),
          )
        : publishers;

    return filtered.map((p) {
      return SearchableDropdownMenuItem<int>(
        value: (p['id'] ?? 0) as int,
        label: (p['name'] ?? '').toString(),
        child: Text((p['name'] ?? '').toString(), maxLines: 1),
      );
    }).toList();
  }

  Future<List<SearchableDropdownMenuItem<int>>> getSupplierList({
    required int page,
    String? key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final filtered = (key != null && key.isNotEmpty)
        ? supplier.where(
            (p) => (p['name'] ?? '').toString().toLowerCase().contains(
              key.toLowerCase(),
            ),
          )
        : supplier;

    return filtered.map((p) {
      return SearchableDropdownMenuItem<int>(
        value: (p['id'] ?? 0) as int,
        label: (p['name'] ?? '').toString(),
        child: Text((p['name'] ?? '').toString(), maxLines: 1),
      );
    }).toList();
  }

  // ---------------------------
  // REFRESH / APPLY FILTERS
  // ---------------------------
  Future<void> _applyFilters({int page = 1}) async {
    print('Type : $selectedType');
    await fetchAssignmentsData(
      type: selectedType ?? '',
      category: selectedCategory ?? '',
      publisherId: selectedPublisherId,
      supplierId: (selectedSupplierId == 0) ? 0 : selectedSupplierId,
      page: currentPage,
      key: textController.text,
    );
  }

  Future<void> _resetAll() async {
    setState(() {
      selectedType = null;
      selectedCategory = null;
      selectedPublisherId = 0;
      selectedSupplierId = 0;
      currentPage = 1;
      totalPages = 1;
      totalItems = 0;

      searchableDropdownController.clear();
      searchableDropdownController2.clear();
      textController.clear();
    });

    await _applyFilters(page: 1);
  }

  List<int> _pageOptions() {
    // For UI safety: max 50 options
    final tp = totalPages <= 0 ? 1 : totalPages;
    final maxShow = tp > 50 ? 50 : tp;
    return List.generate(maxShow, (i) => i + 1);
  }

  Timer? _debounce;

  void debounceSearch(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      currentPage = 1;
      await _applyFilters(page: 1);
    });
  }

  Color getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.green; // Available
      case 2:
        return Colors.orange; // Issued
      case 3:
        return Colors.red; // Lost
      case 4:
        return Colors.red; // Damaged
      case 5:
        return Colors.red; // Discard
      default:
        return Colors.grey;
    }
  }

  String getStatusText(int status) {
    switch (status) {
      case 1:
        return "Available";
      case 2:
        return "Issued";
      case 3:
        return "Lost";
      case 4:
        return "Damaged";
      case 5:
        return "Discard";
      default:
        return "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.appBar.isNotEmpty
          ?AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE53935), // red
                Color(0xFFD32F2F), // dark red
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Library",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      )
          : null, // 👈 agar null h to AppBar hide
      body: Column(
        children: [
          SizedBox(
            height: 40.sp,
            child: Material(
              elevation: 5,
              shadowColor: AppColors.secondary,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  // Clear / Reset
                  _smallActionCard(title: 'Clear', onTap: _resetAll),

                  // Type Dropdown
                  _smallDropdownCard(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: false,
                        iconEnabledColor: Colors.black,
                        hint: Text(
                          "Select Type",
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: type.any((o) => o['name'] == selectedType)
                            ? selectedType
                            : null,
                        items: type.map((o) {
                          return DropdownMenuItem<String>(
                            value: (o['name'] ?? '').toString(),
                            child: Text(
                              (o['name'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) async {
                          setState(() {
                            selectedType = v;
                            // currentPage = 1;
                          });
                          await _applyFilters(page: currentPage);
                        },
                      ),
                    ),
                  ),

                  // Category Dropdown (ONLY ONCE ✅)
                  _smallDropdownCard(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: false,
                        iconEnabledColor: Colors.black,
                        hint: Text(
                          "Select Category",
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value:
                            category.any((o) => o['title'] == selectedCategory)
                            ? selectedCategory
                            : null,
                        items: category.map((o) {
                          return DropdownMenuItem<String>(
                            value: (o['title'] ?? '').toString(),
                            child: Text(
                              (o['title'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) async {
                          setState(() {
                            selectedCategory = v;
                            // currentPage = 1;
                          });
                          await _applyFilters(page: currentPage);
                        },
                      ),
                    ),
                  ),

                  // Publisher
                  Card(
                    elevation: 5,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: SizedBox(
                      height: 40.sp,
                      width: 150.sp,
                      child: SearchableDropdownFormField<int>.paginated(
                        controller: searchableDropdownController,
                        hintText: Text(
                          'Select Publishers',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        isDialogExpanded: true,
                        margin: const EdgeInsets.all(6),
                        paginatedRequest: (int page, String? searchKey) async {
                          return await getPublisherList(
                            page: page,
                            key: searchKey,
                          );
                        },
                        onChanged: (val) async {
                          if (val == null) return;
                          setState(() {
                            selectedPublisherId = val;
                            currentPage = 1;
                          });
                          await _applyFilters(page: 1);
                        },
                      ),
                    ),
                  ),

                  // Supplier
                  Card(
                    elevation: 5,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: SizedBox(
                      height: 40.sp,
                      width: 150.sp,
                      child: SearchableDropdownFormField<int>.paginated(
                        controller: searchableDropdownController2,
                        hintText: Text(
                          'Select Supplier',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        margin: const EdgeInsets.all(6),
                        paginatedRequest: (int page, String? searchKey) async {
                          return await getSupplierList(
                            page: page,
                            key: searchKey,
                          );
                        },
                        onChanged: (val) async {
                          if (val == null) return;
                          setState(() {
                            selectedSupplierId = val;
                            currentPage = 1;
                          });
                          await _applyFilters(page: 1);
                        },
                      ),
                    ),
                  ),

                  _smallActionCard(title: 'Reset', onTap: _resetAll),
                ],
              ),
            ),
          ),

          // =======================
          // SEARCH BAR + PAGE FILTER (RIGHT SIDE) ✅
          // =======================
          Material(
            elevation: 5,
            shadowColor: AppColors.secondary,
            child: Padding(
              padding: EdgeInsets.all(5.w),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    child: Container(
                      height: 34.sp,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.sp),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 5,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: TextField(
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        controller: textController,

                        // ✅ Real-time search (typing)
                        onChanged: (value) {
                          debounceSearch(value); // better than direct call
                        },

                        // ✅ Enter press search
                        onSubmitted: (value) async {
                          currentPage = 1; // reset page on new search
                          await _applyFilters(page: 1);
                        },

                        decoration: InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search,
                            size: 21.sp,
                            color: Colors.black,
                          ),
                          suffixIcon: textController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    size: 23.sp,
                                    color: Colors.black,
                                  ),
                                  onPressed: () async {
                                    _clearSearch();
                                    currentPage = 1;
                                    await _applyFilters(page: 1);
                                  },
                                )
                              : SizedBox(width: 1.sp),
                          hintStyle: const TextStyle(color: Colors.grey),
                          hintText: 'Search',
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 8.w),

                  // Page Filter
                  Container(
                    height: 34.sp,
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.sp),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 5,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: (currentPage <= totalPages) ? currentPage : 1,
                        iconEnabledColor: Colors.black,
                        items: _pageOptions().map((p) {
                          return DropdownMenuItem<int>(
                            value: p,
                            child: Text(
                              "Page $p",
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (p) async {
                          if (p == null) return;
                          setState(() => currentPage = p);
                          await _applyFilters(
                            page: p,
                          ); // ✅ fetch according to page
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =======================i
          // BOOKS LIST
          // =======================
          Expanded(
            child: booksLoading
                ? Center(
                    child: CupertinoActivityIndicator(
                      radius: 20,
                      color: AppColors.primary,
                    ),
                  )
                : books.isEmpty
                ? Center(
                    child: ListView(
                      children: const [
                        DataNotFoundWidget(title: 'Book Not Available.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index] as Map<String, dynamic>?;
                      final status =
                          int.tryParse(
                            (books[index]['status'] ?? '0').toString(),
                          ) ??
                          0;
                      final statusColor = getStatusColor(status);
                      if (book == null) return const SizedBox.shrink();

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.sp,
                          vertical: 1.sp,
                        ),
                        child: Stack(
                          children: [
                            Card(
                              elevation: 2,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.sp),
                                side: BorderSide(
                                  color: statusColor.withOpacity(0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(3.sp),

                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.sp),
                                  child: CachedNetworkImage(
                                    imageUrl: (book['cover_page'] ?? '')
                                        .toString(),
                                    height: 50.sp,
                                    width: 50.sp,
                                    // fit: BoxFit.fill,
                                    placeholder: (context, url) => Image.asset(
                                      'assets/physics.png',
                                      fit: BoxFit.cover,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Image.asset(
                                          'assets/physics.png',
                                          fit: BoxFit.cover,
                                        ),
                                  ),
                                ),

                                title: Text(
                                  (book['title'] ?? 'N/A').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Author: ${(book['author'] ?? 'N/A')}",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        color: Colors.black87,
                                      ),
                                    ),

                                    Text(
                                      "Accession No: ${(book['accession_no'] ?? 'N/A')}",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        color: Colors.black87,
                                      ),
                                    ),

                                    SizedBox(height: 6.sp),

                                    /// 🔥 STATUS CHIP
                                  ],
                                ),

                                /// 🔥 RIGHT SIDE ICON
                                // trailing:  Container(
                                //   padding: EdgeInsets.symmetric(
                                //     horizontal: 8.sp,
                                //     vertical: 3.sp,
                                //   ),
                                //   decoration: BoxDecoration(
                                //     color: statusColor.withOpacity(0.1),
                                //     borderRadius: BorderRadius.circular(20),
                                //     border: Border.all(color: statusColor),
                                //   ),
                                //   child: Text(
                                //     getStatusText(status),
                                //     style: GoogleFonts.montserrat(
                                //       fontSize: 8.sp,
                                //       fontWeight: FontWeight.w600,
                                //       color: statusColor,
                                //     ),
                                //   ),
                                // )
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.sp,
                                  vertical: 3.sp,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  getStatusText(status),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // UI HELPERS
  // ---------------------------
  Widget _smallActionCard({
    required String title,
    required Future<void> Function() onTap,
  }) {
    return Card(
      elevation: 5,
      color: Colors.redAccent.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
      child: GestureDetector(
        onTap: () async => onTap(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 0.h),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade100,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallDropdownCard({required Widget child}) {
    return Card(
      elevation: 5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 0.h),
        child: SizedBox(
          height: 30.sp,
          child: Center(child: child),
        ),
      ),
    );
  }
}
