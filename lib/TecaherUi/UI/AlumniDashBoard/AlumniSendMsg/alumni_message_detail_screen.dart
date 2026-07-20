import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AlumniMessageDetailScreen extends StatefulWidget {
  final String userName;
  final String userImage;
  final int partnerId;
  final String classSection;

  const AlumniMessageDetailScreen({
    super.key,
    required this.userName,
    required this.userImage,
    required this.partnerId,
    required this.classSection,
  });

  @override
  State<AlumniMessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<AlumniMessageDetailScreen> {
  bool isLoading = true;
  bool isLoadingMore = false;

  Map<String, dynamic>? mainMessage;
  List<Map<String, dynamic>> repliesList = [];

  int currentPage = 1;
  int lastPage = 1;
  int totalReplies = 0;
  bool hasMoreReplies = true;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    fetchMessages(page: 1, reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentScroll = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (currentScroll >= maxScroll - 150) {
      loadMoreReplies();
    }
  }

  String formatDate(String rawDate) {
    if (rawDate.trim().isEmpty || rawDate == "null") return "";
    try {
      final dt = DateTime.parse(rawDate);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return "$day-$month-${dt.year}";
    } catch (e) {
      return rawDate;
    }
  }

  List<Map<String, dynamic>> get filteredReplies {
    if (searchQuery.trim().isEmpty) return repliesList;

    final q = searchQuery.toLowerCase().trim();

    return repliesList.where((reply) {
      final alumni = Map<String, dynamic>.from(reply["alumni"] ?? {});
      final name = (alumni["name"] ?? "").toString().toLowerCase();
      final email = (alumni["email"] ?? "").toString().toLowerCase();
      final mobile =
      (alumni["mobile"] ?? alumni["phone"] ?? "").toString().toLowerCase();

      return name.contains(q) || email.contains(q) || mobile.contains(q);
    }).toList();
  }

  Future<void> fetchMessages({int page = 1, bool reset = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
        return;
      }

      if (reset) {
        setState(() {
          isLoading = true;
          currentPage = 1;
          lastPage = 1;
          hasMoreReplies = true;
          isLoadingMore = false;
          repliesList.clear();
        });
      }

      final uri = Uri.parse(
        "${ApiRoutes.getAdminAlumniDetailsMessageSendList}${widget.partnerId}",
      ).replace(
        queryParameters: {
          "page": page.toString(),
          "per_page": "50",
        },
      );

      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      debugPrint("API URL: $uri");
      debugPrint("API STATUS: ${response.statusCode}");
      debugPrint("API BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if ((data["status"] ?? "") != "success") {
          setState(() {
            isLoading = false;
            isLoadingMore = false;
          });
          return;
        }

        final List<Map<String, dynamic>> newReplies =
        List<Map<String, dynamic>>.from(
          (data["data"] ?? []).map(
                (e) => Map<String, dynamic>.from(e),
          ),
        );

        final pagination = data["pagination"] ?? {};

        setState(() {
          mainMessage =
          Map<String, dynamic>.from(data["main_message"] ?? {});

          if (reset) {
            repliesList = newReplies;
          } else {
            repliesList.addAll(newReplies);
          }

          totalReplies = pagination["total"] ?? repliesList.length;
          currentPage = pagination["current_page"] ?? page;
          lastPage = pagination["last_page"] ?? 1;
          hasMoreReplies = currentPage < lastPage;

          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Message API Error: $e");
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<void> loadMoreReplies() async {
    if (isLoadingMore || !hasMoreReplies || isLoading) return;

    setState(() {
      isLoadingMore = true;
    });

    await fetchMessages(page: currentPage + 1, reset: false);
  }

  Future<void> _onOpen(LinkableElement link) async {
    if (!await launchUrl(Uri.parse(link.url))) {
      throw Exception('Could not launch ${link.url}');
    }
  }

  Future<void> _openAttachment(String attachment) async {
    final url = Uri.parse(attachment);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _networkAvatar({
    required String image,
    double radius = 18,
    double iconSize = 20,
  }) {
    final img = image.trim();

    return CircleAvatar(
      radius: radius.r,
      backgroundColor: Colors.red.shade100,
      child: ClipOval(
        child: img.isNotEmpty && img != "null"
            ? Image.network(
          img,
          width: (radius * 2).r,
          height: (radius * 2).r,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Icon(
              Icons.person,
              color: Colors.red,
              size: iconSize.sp,
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Icon(
              Icons.person,
              color: Colors.red,
              size: iconSize.sp,
            );
          },
        )
            : Icon(
          Icons.person,
          color: Colors.red,
          size: iconSize.sp,
        ),
      ),
    );
  }

  Widget _attachmentChip(String attachment) {
    return GestureDetector(
      onTap: () => _openAttachment(attachment),
      child: Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file,
              color: Colors.red.shade700,
              size: 17.sp,
            ),
            SizedBox(width: 5.w),
            Text(
              "Attachment",
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainMessageBox() {
    final body = (mainMessage?["message"] ?? "").toString();
    final time = formatDate((mainMessage?["created_at"] ?? "").toString());
    final attachment = (mainMessage?["attachment"] ?? "").toString();
    final recipientCount = mainMessage?["recipient_count"] ?? 0;

    final senderName = widget.userName;
    final senderImage = widget.userImage;

    return Container(
      margin: EdgeInsets.all(8.w),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkAvatar(
            image: senderImage,
            radius: 18,
            iconSize: 20,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                SelectableLinkify(
                  text: body,
                  onOpen: _onOpen,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  linkStyle: TextStyle(
                    color: Colors.blue,
                    fontSize: 12.sp,
                    height: 1.45,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
                if (attachment.isNotEmpty && attachment != "null")
                  _attachmentChip(attachment),
                if (recipientCount > 0) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      "$recipientCount Recipient(s)",
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        style: TextStyle(fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: "Search by name, email or number...",
          hintStyle: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey.shade500,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20.sp,
            color: Colors.red.shade700,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.close,
              size: 18.sp,
              color: Colors.grey.shade600,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                searchQuery = "";
              });
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyCard(Map<String, dynamic> reply) {
    final time = formatDate((reply["created_at"] ?? "").toString());
    final readAt = reply["read_at"];

    final alumni = Map<String, dynamic>.from(reply["alumni"] ?? {});
    final name = (alumni["name"] ?? "Alumni").toString();
    final photo = (alumni["photo"] ?? "").toString();
    final email = (alumni["email"] ?? "").toString();
    final mobile = (alumni["mobile"] ?? alumni["phone"] ?? "").toString();

    final bool isRead =
        readAt != null && readAt.toString().trim().isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkAvatar(
            image: photo,
            radius: 17,
            iconSize: 19,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty && email != "null") ...[
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Icon(
                        Icons.class_,
                        size: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (mobile.isNotEmpty && mobile != "null") ...[
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        mobile,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isRead) ...[
                  SizedBox(height: 4.h),
                  Text(
                    "Read on: ${formatDate(readAt.toString())}",
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 5.w),
          Icon(
            Icons.done_all,
            size: 18.sp,
            color: isRead ? Colors.green : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Text(
            searchQuery.trim().isEmpty
                ? "Replies ($totalReplies)"
                : "Replies (${filteredReplies.length} found)",
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Colors.red.shade700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final replies = filteredReplies;

    return Scaffold(
      backgroundColor: const Color(0xfff7f7fb),
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _networkAvatar(
              image: widget.userImage,
              radius: 19,
              iconSize: 20,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "$totalReplies Replies",
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.red),
      )
          : mainMessage == null || mainMessage!.isEmpty
          ? Center(
        child: Text(
          "No message available",
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      )
          : RefreshIndicator(
        color: Colors.red,
        onRefresh: () async {
          await fetchMessages(page: 1, reset: true);
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(bottom: 10.h),
          // 1 main message + 1 search bar + 1 header + replies + optional loader/empty
          itemCount: 3 +
              (replies.isEmpty ? 1 : replies.length) +
              (isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) return _buildMainMessageBox();
            if (index == 1) return _buildSearchBar();
            if (index == 2) return _buildRepliesHeader();

            final replyIndex = index - 3;

            if (replies.isEmpty) {
              if (replyIndex == 0) {
                return Padding(
                  padding: EdgeInsets.all(30.h),
                  child: Center(
                    child: Text(
                      searchQuery.trim().isEmpty
                          ? "No replies yet"
                          : "No results found",
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }
            } else if (replyIndex < replies.length) {
              return _buildReplyCard(replies[replyIndex]);
            }

            // Loader at the end
            return Padding(
              padding: EdgeInsets.all(14.h),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.red,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}