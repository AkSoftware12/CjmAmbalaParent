import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:avi/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_searchable_dropdown/flutter_searchable_dropdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:searchable_paginated_dropdown/searchable_paginated_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../CommonCalling/data_not_found.dart';
import '../../HexColorCode/HexColor.dart';
import '../Auth/login_screen.dart';
import 'package:flutter/widgets.dart';

class LibraryScreen extends StatefulWidget {
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  TextEditingController textController = TextEditingController();
  bool _isLoading = true; // Track loading state
  late SearchableDropdownController<int> searchableDropdownController;
  late SearchableDropdownController<int> searchableDropdownController2;
  bool isLoading = false;
  List<dynamic> books = []; // Declare a list to hold API data
  List<dynamic> filteredBooks = [];

  List type = []; // Declare a list to hold API data
  List category = []; // Declare a list to hold API data
  List<dynamic> publishers = []; // Declare a list to hold API data
  List<dynamic> supplier = []; // Declare a list to hold API data
  // List<Map<String, String>> publishers = [];

  // Sample list of books

  String? selectedType;
  String? selectedCategory;
  String? selectedPublishers;
  String? selectedSupplier;
  String? selectedOption;

  @override
  void initState() {
    super.initState();
    searchableDropdownController = SearchableDropdownController<int>();
    searchableDropdownController2 = SearchableDropdownController<int>();

    fetchTypeData();
    fetchCategoryData();
    fetchPublishersData();
    fetchSupplierData();
    fetchAssignmentsData('', '', 0, 0);

    filteredBooks = List.from(books);
  }

  void filterList(String query) {
    List<dynamic> filtered = [];
    if (query.isNotEmpty) {
      books.forEach((item) {
        if (item.toString().toLowerCase().contains(query.toLowerCase())) {
          filtered.add(item);
        }
      });
    } else {
      filtered = books;
    }
    setState(() {
      filteredBooks = filtered;
    });
  }

  void _clearSearch() {
    setState(() {
      textController.clear();
      filteredBooks = List.from(books);
    });
  }

  Future<void> fetchAssignmentsData(String type, String title, int publishers,
      int? supplier) async {
    setState(() {
      isLoading = true; // Show progress bar
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    // if (token == null) {
    //   _showLoginDialog();
    //   return;
    // }

    final response = await http.get(
      // Uri.parse(ApiRoutes.getlibrary),
      Uri.parse(
          '${ApiRoutes.getlibrary}?type=$type&publisher=$publishers&supplier=$supplier&title=${textController.text}'),

      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        books = jsonResponse['data'];
        filteredBooks = books;

        isLoading = false; // Stop progress bar
// Update state with fetched data
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchTypeData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiRoutes.getBookTypes),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        type = jsonResponse['data'];
// Update state with fetched data
      });
    } else {}
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
      setState(() {
        category = jsonResponse['data'];
// Update state with fetched data
      });
    } else {}
  }

  Future<void> fetchPublishersData() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getBookPublishers),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> fetchedData = jsonResponse['data'];

        setState(() {
          publishers = jsonResponse['data']; // Limit to 20
        });
      } else {
        // Handle errors if needed
        print("Error fetching publishers: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception occurred: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchSupplierData() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getBookSupplier),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> fetchedData = jsonResponse['data'];

        setState(() {
          supplier = jsonResponse['data']; // Limit to 20
        });
      } else {
        // Handle errors if needed
        print("Error fetching publishers: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception occurred: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showLoginDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) =>
          CupertinoAlertDialog(
            title: const Text('Session Expired'),
            content: const Text('Please log in again to continue.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ],
          ),
    );
  }

  void _refresh(String type, String cat, int publishers, int? supplier) {
    setState(() {
      fetchAssignmentsData(type, cat, publishers, supplier);
      filteredBooks = List.from(books);
    });
  }

  Future<List<SearchableDropdownMenuItem<int>>> getAnimeList({
    required int page,
    String? key,
  }) async {
    // Simulate a network delay
    await Future.delayed(const Duration(seconds: 2));
    final filteredPublishers = (key != null && key.isNotEmpty)
        ? publishers.where((publisher) =>
        publisher['name']
            .toString()
            .toLowerCase()
            .contains(key.toLowerCase()))
        : publishers;

    // Convert to SearchableDropdownMenuItem list
    return filteredPublishers.map((publisher) {
      return SearchableDropdownMenuItem<int>(
        value: publisher['id'] as int,
        label: publisher['name'] as String,
        child: Text(publisher['name'] as String),
      );
    }).toList();
  }

  Future<List<SearchableDropdownMenuItem<int>>> getAnimeList2({
    required int page,
    String? key,
  }) async {
    // Simulate a network delay
    await Future.delayed(const Duration(seconds: 2));
    final filteredPublishers2 = (key != null && key.isNotEmpty)
        ? supplier.where((publisher) =>
        publisher['name']
            .toString()
            .toLowerCase()
            .contains(key.toLowerCase()))
        : supplier;

    // Convert to SearchableDropdownMenuItem list
    return filteredPublishers2.map((publisher) {
      return SearchableDropdownMenuItem<int>(
        value: publisher['id'] as int,
        label: publisher['name'] as String,
        child: Text(publisher['name'] as String),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // appBar: PreferredSize(
      //   preferredSize: Size.fromHeight(110.sp), // Default height
      //   child: AppBar(
      //     backgroundColor: AppColors.secondary,
      //     flexibleSpace: Column(
      //       mainAxisSize: MainAxisSize.min, // Auto-adjust height
      //       children: [
      //         SizedBox(height: 10), // Add dynamic spacing if needed
      //
      //       ],
      //     ),
      //   ),
      // ),

      body: Column(
        children: [
          SizedBox(
            height: 40.sp,
            child: Material(
              elevation: 5,
              shadowColor: AppColors.secondary,
              child: ListView(
                // This next line does the trick.
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  Card(
                    elevation: 5,
                    color: Colors.redAccent.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedType = null;
                          selectedCategory = null;
                          selectedPublishers = null;
                          selectedSupplier = null;

                          // Agar kisi dropdown controller ki value reset karni ho to:
                          searchableDropdownController.clear();
                          searchableDropdownController2.clear();
                        });
                      },


                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 3.w, vertical: 0.h),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                    color: Colors.grey.shade100,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  Card(
                    elevation: 5,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.h),
                      child: Row(
                        children: [
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 30.sp,
                              padding: EdgeInsets.symmetric(horizontal: 0.w),
                              child: DropdownButton<String>(
                                isExpanded: false,
                                iconEnabledColor: Colors.black,
                                hint: Text(
                                  "Select Type",
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500),
                                ),
                                value: type.any((option) =>
                                option['name'] == selectedType)
                                    ? selectedType
                                    : null,
                                // Ensure the value exists in the list
                                items: type.map((option) {
                                  return DropdownMenuItem<String>(
                                    value: option['name'],
                                    child: Text(
                                      option['name'],
                                      style: TextStyle(
                                          fontSize: 12.sp, color: Colors.black),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedType = newValue;
                                    // fetchAssignmentsData(selectedType.toString(),'');
                                    // print(selectedType);
                                    _refresh(selectedType.toString(),
                                        selectedCategory.toString(), 0, 0);
                                    print(books);
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 5,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.h),
                      child: Row(
                        children: [
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 30.sp,
                              padding: EdgeInsets.symmetric(horizontal: 0.w),
                              child: DropdownButton<String>(
                                isExpanded: false,
                                iconEnabledColor: Colors.black,
                                hint: Text(
                                  "Select Category",
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500),
                                ),
                                value: category.any((option) =>
                                option['title'] == selectedCategory)
                                    ? selectedCategory
                                    : null,
                                // Ensure the value exists in the list
                                items: category.map((option) {
                                  return DropdownMenuItem<String>(
                                    value: option['title'].toString(),
                                    child: Text(
                                      option['title'].toString(),
                                      style: TextStyle(
                                          fontSize: 12.sp, color: Colors.black),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedCategory = newValue;
                                    _refresh(selectedType.toString(),
                                        selectedCategory.toString(), 0, 0);

                                    // fetchAssignmentsData(selectedCategory.toString());
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 5,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: Container(
                      height: 40.sp,
                      width: 150.sp,
                      child: SearchableDropdownFormField<int>.paginated(
                        controller: searchableDropdownController,
                        hintText: Text(
                          'Select Publishers',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500),
                        ),
                        isDialogExpanded: true,
                        margin: const EdgeInsets.all(6),
                        paginatedRequest: (int page, String? searchKey) async {
                          return await getAnimeList(page: page, key: searchKey);
                        },
                        validator: (val) {
                          if (val == null) return 'Cannot be empty';
                          return null;
                        },

                        onChanged: (val) {
                          if (val != null) {
                            debugPrint('Selected Publisher ID: $val');
                            _refresh(selectedType.toString(),
                                selectedCategory.toString(), 0, 0);
                          }
                        },
                        onSaved: (val) {
                          debugPrint('Selected Publisher ID: $val');
                          // _refresh(selectedType.toString(),selectedCategory.toString(),val!.toInt());

                        },


                      ),
                    ),
                  ),
                  Card(
                    elevation: 5,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: Container(
                      height: 40.sp,
                      width: 150.sp,
                      child: SearchableDropdownFormField<int>.paginated(
                        controller: searchableDropdownController2,
                        hintText: Text(
                          'Select Supplier',
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500),
                        ),
                        margin: const EdgeInsets.all(6),
                        paginatedRequest: (int page, String? searchKey) async {
                          return await getAnimeList2(
                              page: page, key: searchKey);
                        },
                        validator: (val) {
                          if (val == null) return 'Cannot be empty';
                          return null;
                        },
                        onChanged: (val) {
                          if (val != null) {
                            debugPrint('Selected Publisher ID: $val');
                            _refresh(selectedType.toString(),
                                selectedCategory.toString(), 0, val);
                          }
                        },
                        onSaved: (val) {
                          debugPrint('Selected Publisher ID: $val');
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 8.sp),
                    child: Card(
                      elevation: 5,
                      color: Colors.redAccent.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedType = null;
                            selectedCategory = null;
                            selectedPublishers = null;
                            selectedSupplier = null;

                            // Agar kisi dropdown controller ki value reset karni ho to:
                            searchableDropdownController.clear();
                            searchableDropdownController2.clear();
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 0.h),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Reset',
                                  style: TextStyle(
                                      color: Colors.grey.shade100,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Material(
            elevation: 5,
            shadowColor: AppColors.secondary,
            child: Padding(
              padding: EdgeInsets.all(5.w),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  height: 40.sp,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.sp),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 5,
                          spreadRadius: 2),
                    ],
                  ),
                  child: TextField(
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                    controller: textController,
                    onChanged: (value) {
                      filterList(value);
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
                        onPressed: () {
                          _clearSearch();
                        },
                      )
                          : Container(
                        width: 1.sp,
                      ),
                      hintStyle: TextStyle(color: Colors.grey),
                      hintText: 'Search',
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Material(
          //   elevation: 5,
          //   child: Padding(
          //     padding: const EdgeInsets.all(0.0),
          //     child: Container(
          //       height: 3.sp,
          //       decoration: BoxDecoration(
          //         gradient: LinearGradient(
          //           colors: [
          //             AppColors.primary, // Change to your desired colors
          //             Colors.purple,
          //           ],
          //           begin: Alignment.topLeft,
          //           end: Alignment.bottomRight,
          //         ),
          //         borderRadius: BorderRadius.circular(0.sp),
          //       ),
          //     ),
          //   ),
          // ),

          Expanded(
            child: isLoading
                ? Center(
                child: CupertinoActivityIndicator(
                  radius: 30,
                  color: AppColors.primary,
                ))
                : filteredBooks.isEmpty
                ? Center(
                child: ListView(
                  children: [
                    DataNotFoundWidget(
                      title: 'Book  Not Available.',
                    ),
                  ],
                ))
                : ListView.builder(
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) {
                final book = filteredBooks[index];
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 3.sp, vertical: 1.sp),
                  child: Card(
                    elevation: 1,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.sp),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(2.sp),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10.sp),
                        child: Image.asset(
                          'assets/physics.png',
                          height: 50.sp,
                          width: 50.sp,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        book['title'],
                        maxLines: 1,
                        style: GoogleFonts.montserrat(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4.sp),
                          Text(
                            "Author: ${book['author']}",
                            style: GoogleFonts.montserrat(
                                fontSize: 11.sp, color: Colors.grey),
                          ),
                          SizedBox(height: 2.sp),
                          Row(
                            children: [
                              Text(
                                "Status: ",
                                style: GoogleFonts.montserrat(
                                    fontSize: 11.sp,
                                    color: Colors.grey),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.sp, vertical: 4.sp),
                                decoration: BoxDecoration(
                                  color: book['status'] == 1
                                      ? Colors.green.withOpacity(0.2)
                                      : book['status'] == 2
                                      ? Colors.orange
                                      .withOpacity(0.2)
                                      : Colors.red
                                      .withOpacity(0.2),
                                  borderRadius:
                                  BorderRadius.circular(6.sp),
                                ),
                                child: Text(
                                  book['status'] == 1
                                      ? 'Available'
                                      : book['status'] == 2
                                      ? 'Damaged'
                                      : 'Lost',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                    color: book['status'] == 1
                                        ? Colors.green
                                        : book['status'] == 2
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // trailing: Icon(
                      //   book['status'] == 1 ? Icons.check_circle : Icons.cancel,
                      //   color: book['status'] == 1 ? Colors.green : Colors.red,
                      //   size: 20.sp,
                      // ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
