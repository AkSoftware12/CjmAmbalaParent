import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentMessageDetailScreen extends StatefulWidget {
  final String userName;
  final String userImage;
  final int partnerId;
  final String classSection;

  const StudentMessageDetailScreen({
    super.key,
    required this.userName,
    required this.userImage,
    required this.partnerId,
    required this.classSection,
  });

  @override
  State<StudentMessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<StudentMessageDetailScreen> {
  bool isLoading = true;

  Map<String, dynamic>? messageData;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> receiversList = [];

  int totalReceivers = 0;
  int seenByReceivers = 0;

  String receiverSearch = "";

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        setState(() => isLoading = false);
        debugPrint("Token not found");
        return;
      }

      final url = Uri.parse(
        "${ApiRoutes.getStudentSendPartner}${widget.partnerId}",
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      debugPrint("API STATUS: ${response.statusCode}");
      debugPrint("API BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          messageData = Map<String, dynamic>.from(data["message"] ?? {});
          userData = Map<String, dynamic>.from(data["user"] ?? {});

          receiversList = List<Map<String, dynamic>>.from(
            (data["receivers"] ?? []).map(
                  (e) => Map<String, dynamic>.from(e),
            ),
          );

          totalReceivers = data["total_receivers"] ?? receiversList.length;
          seenByReceivers = data["seen_by_receivers"] ?? 0;

          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Message API Error: $e");
      setState(() => isLoading = false);
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

                // Text(
                //   body,
                //   style: TextStyle(
                //     fontSize: 12.sp,
                //     height: 1.45,
                //     fontWeight: FontWeight.w500,
                //     color: Colors.black87,
                //   ),
                // ),
                if (attachment.isNotEmpty && attachment != "null") ...[
                  SizedBox(height: 10.h),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(attachment);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        // _showSnackBar(
                        //   'Could not open attachment',
                        //   isError: true,
                        // );
                      }
                    },
                    child: Container(
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
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _onOpen(LinkableElement link) async {
    if (!await launchUrl(Uri.parse(link.url))) {
      throw Exception('Could not launch ${link.url}');
    }
  }
  Widget _buildReceiverCard(Map<String, dynamic> receiver) {
    final name = (receiver["name"] ?? "Receiver").toString();
    final image = (receiver["image"] ?? "").toString();
    final type = (receiver["designation"] ?? "").toString();
    final seenAt = receiver["seen_by_receiver"];
    final read = receiver["read"] == 1;

    final bool isRead = read ||
        (seenAt != null && seenAt.toString().trim().isNotEmpty);

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
          CircleAvatar(
            radius: 20.r,
            backgroundColor: Colors.grey.shade200,
            child: ClipOval(
              child: image.trim().isNotEmpty
                  ? Image.network(
                image,
                width: 40.r,
                height: 40.r,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_outline,
                  color: Colors.grey,
                  size: 22.sp,
                ),
              )
                  : Icon(
                Icons.person_outline,
                color: Colors.grey,
                size: 22.sp,
              ),
            ),
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
                SizedBox(height: 3.h),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
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
    receiverSearch = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredList = receiversList.where((receiver) {
              final name = (receiver["name"] ?? "").toString().toLowerCase();
              final type = (receiver["receiver_type"] ?? "").toString().toLowerCase();
              final search = receiverSearch.toLowerCase().trim();
              return name.contains(search) || type.contains(search);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: const Color(0xffFFF8F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
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
                    child: TextField(
                      onChanged: (value) {
                        setSheetState(() => receiverSearch = value);
                      },
                      decoration: InputDecoration(
                        hintText: "Search receiver...",
                        prefixIcon: Icon(Icons.search, color: Colors.red.shade600),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.red.shade100),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.red.shade500, width: 1.4),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(
                          "Read by : $seenByReceivers/$totalReceivers (${totalReceivers == 0 ? "0" : ((seenByReceivers / totalReceivers) * 100).toStringAsFixed(2)}%) Recipient(s)",
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
                    child: filteredList.isEmpty
                        ? Center(
                      child: Text(
                        "No receivers found",
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                        : ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        return _buildReceiverCard(filteredList[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        onRefresh: fetchMessages,
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