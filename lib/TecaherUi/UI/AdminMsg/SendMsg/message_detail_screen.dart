import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MessageDetailScreen extends StatefulWidget {
  final String userName;
  final String userImage;
  final int partnerId;
  final String classSection;

  const MessageDetailScreen({
    super.key,
    required this.userName,
    required this.userImage,
    required this.partnerId,
    required this.classSection,
  });

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  bool isLoading = true;
  bool isReceiverLoadingMore = false;
  bool isSearchingReceiver = false;

  Map<String, dynamic>? messageData;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> receiversList = [];

  int totalReceivers = 0;
  int seenByReceivers = 0;

  int currentPage = 1;
  int lastPage = 1;
  bool hasMoreReceivers = true;

  String receiverSearch = "";
  final TextEditingController receiverSearchController =
  TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchMessages(page: 1, reset: true);
  }

  @override
  void dispose() {
    receiverSearchController.dispose();
    super.dispose();
  }

  Future<void> fetchMessages({
    int page = 1,
    bool reset = true,
    String search = "",
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
          isReceiverLoadingMore = false;
          isSearchingReceiver = false;
        });
        return;
      }

      if (reset) {
        setState(() {
          isLoading = true;
          currentPage = 1;
          lastPage = 1;
          hasMoreReceivers = true;
          isReceiverLoadingMore = false;
          receiversList.clear();
        });
      }

      final uri = Uri.parse(
        "${ApiRoutes.getTeacherSendPartner}${widget.partnerId}",
      ).replace(
        queryParameters: {
          "page": page.toString(),
          "per_page": "100",
          if (search.trim().isNotEmpty) "search": search.trim(),
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

        final List<Map<String, dynamic>> newReceivers =
        List<Map<String, dynamic>>.from(
          (data["receivers"] ?? []).map(
                (e) => Map<String, dynamic>.from(e),
          ),
        );

        final pagination = data["pagination"] ?? {};

        setState(() {
          messageData = Map<String, dynamic>.from(data["message"] ?? {});
          userData = Map<String, dynamic>.from(data["user"] ?? {});

          if (reset) {
            receiversList = newReceivers;
          } else {
            receiversList.addAll(newReceivers);
          }

          totalReceivers = data["total_receivers"] ?? receiversList.length;
          seenByReceivers = data["seen_by_receivers"] ?? 0;

          currentPage = pagination["current_page"] ?? page;
          lastPage = pagination["last_page"] ?? 1;
          hasMoreReceivers = currentPage < lastPage;

          isLoading = false;
          isReceiverLoadingMore = false;
          isSearchingReceiver = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isReceiverLoadingMore = false;
          isSearchingReceiver = false;
        });
      }
    } catch (e) {
      debugPrint("Message API Error: $e");
      setState(() {
        isLoading = false;
        isReceiverLoadingMore = false;
        isSearchingReceiver = false;
      });
    }
  }

  Future<void> loadMoreReceivers(VoidCallback refreshSheet) async {
    if (isReceiverLoadingMore || !hasMoreReceivers) return;

    setState(() {
      isReceiverLoadingMore = true;
    });

    refreshSheet();

    await fetchMessages(
      page: currentPage + 1,
      reset: false,
      search: receiverSearch,
    );

    refreshSheet();
  }

  Future<void> searchReceivers(VoidCallback refreshSheet) async {
    FocusScope.of(context).unfocus();

    setState(() {
      receiverSearch = receiverSearchController.text.trim();
      isSearchingReceiver = true;
    });

    refreshSheet();

    await fetchMessages(
      page: 1,
      reset: true,
      search: receiverSearch,
    );

    refreshSheet();
  }

  Future<void> clearReceiverSearch(VoidCallback refreshSheet) async {
    FocusScope.of(context).unfocus();

    receiverSearchController.clear();

    setState(() {
      receiverSearch = "";
      isSearchingReceiver = true;
    });

    refreshSheet();

    await fetchMessages(
      page: 1,
      reset: true,
      search: "",
    );

    refreshSheet();
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
        child: img.isNotEmpty
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

  Widget _buildMessageBox() {
    final title = (messageData?["title"] ?? "").toString();
    final body = (messageData?["body"] ?? "").toString();
    final time = (messageData?["created_at"] ?? "").toString();
    final senderName = (userData?["name"] ?? widget.userName).toString();
    final senderImage = (userData?["photo"] ?? widget.userImage).toString();
    final attachment = (messageData?["attachment"] ?? "").toString();

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
                if (title.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
                SizedBox(height: 6.h),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                if (attachment.isNotEmpty && attachment != "null") ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverCard(Map<String, dynamic> receiver) {
    final name = (receiver["name"] ?? "Receiver").toString();
    final className = (receiver["class_name"] ?? "").toString();
    final image = (receiver["image"] ?? "").toString();
    final seenAt = receiver["seen_by_receiver"];
    final read = receiver["read"] == 1;

    final bool isRead =
        read || (seenAt != null && seenAt.toString().trim().isNotEmpty);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkAvatar(
            image: image,
            radius: 20,
            iconSize: 22,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                if (className.isNotEmpty)
                  Text(
                    className.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                if (seenAt != null && seenAt.toString().trim().isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    "Read on: ${seenAt.toString()}",
                    style: TextStyle(
                      fontSize: 11.sp,
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
            size: 19.sp,
            color: isRead ? Colors.green : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  void _showReceiversBottomSheet() {
    final ScrollController scrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void onScroll() {
              if (!scrollController.hasClients) return;

              final currentScroll = scrollController.position.pixels;
              final maxScroll = scrollController.position.maxScrollExtent;

              if (currentScroll >= maxScroll - 150) {
                loadMoreReceivers(() {
                  setSheetState(() {});
                });
              }
            }

            scrollController.removeListener(onScroll);
            scrollController.addListener(onScroll);

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: const Color(0xffFFF8F8),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(22.r),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 45.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.red.shade200,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: receiverSearchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) {
                              searchReceivers(() {
                                setSheetState(() {});
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Search receiver...",
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.red.shade600,
                              ),
                              suffixIcon: receiverSearchController.text
                                  .trim()
                                  .isNotEmpty
                                  ? IconButton(
                                onPressed: () {
                                  clearReceiverSearch(() {
                                    setSheetState(() {});
                                  });
                                },
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.red.shade600,
                                ),
                              )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide:
                                BorderSide(color: Colors.red.shade100),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: Colors.red.shade500,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        InkWell(
                          onTap: isSearchingReceiver
                              ? null
                              : () {
                            searchReceivers(() {
                              setSheetState(() {});
                            });
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            height: 35.h,
                            padding: EdgeInsets.symmetric(horizontal: 13.w),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isSearchingReceiver
                                  ? SizedBox(
                                height: 18.h,
                                width: 18.h,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: Colors.white,
                                    size: 17.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "Search",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 0.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(
                          receiverSearch.trim().isEmpty
                              ? "Read by : $seenByReceivers/$totalReceivers "
                              "(${totalReceivers == 0 ? "0" : ((seenByReceivers / totalReceivers) * 100).toStringAsFixed(2)}%) Recipient(s)"
                              : "Search: $receiverSearch | Result: ${receiversList.length}",
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 6.h),

                  Expanded(
                    child: receiversList.isEmpty
                        ? Center(
                      child: isSearchingReceiver
                          ? const CircularProgressIndicator(
                        color: Colors.red,
                      )
                          : Text(
                        "No receivers found",
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                        : ListView.builder(
                      controller: scrollController,
                      itemCount: receiversList.length +
                          (isReceiverLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == receiversList.length) {
                          return Padding(
                            padding: EdgeInsets.all(14.h),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.red,
                              ),
                            ),
                          );
                        }

                        return _buildReceiverCard(receiversList[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      scrollController.dispose();
    });
  }

  Widget _buildReceiverButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      child: InkWell(
        onTap: _showReceiversBottomSheet,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.red.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 34.h,
                width: 34.h,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: Colors.red.shade700,
                  size: 21.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  "View Receivers ($totalReceivers)",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 4.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  "$seenByReceivers / $totalReceivers Read",
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.grey,
                size: 24.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final senderImage = (userData?["photo"] ?? widget.userImage).toString();
    final senderName = (userData?["name"] ?? widget.userName).toString();

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
              image: senderImage,
              radius: 19,
              iconSize: 20,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "$seenByReceivers / $totalReceivers Read",
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
          : messageData == null || messageData!.isEmpty
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
          receiverSearchController.clear();
          receiverSearch = "";
          await fetchMessages(page: 1, reset: true);
        },
        child: ListView(
          padding: EdgeInsets.only(bottom: 10.h),
          children: [
            _buildMessageBox(),
            _buildReceiverButton(),
          ],
        ),
      ),
    );
  }
}