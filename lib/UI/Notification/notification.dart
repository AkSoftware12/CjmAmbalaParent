import 'package:avi/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../CommonCalling/data_not_found.dart';
import '../../CommonCalling/progressbarWhite.dart';
import '../../utils/date_time_utils.dart';
import '../Auth/login_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isLoading = false;
  List notifications = [];

  @override
  void initState() {
    super.initState();
    fetchSubjectData();
  }

  Future<void> fetchSubjectData() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    final response = await http.get(
      Uri.parse(ApiRoutes.notifications),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      setState(() {
        notifications = jsonResponse['notifications'];
        isLoading = false;
      });
    } else {
      // _showLoginDialog();
      setState(() {
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,

      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,

      ),
      body: isLoading
          ? WhiteCircularProgressWidget()
          : notifications.isEmpty
          ? Center(
          child: DataNotFoundWidget(
            title: 'Notification  Not Available.',
          ))
          : RefreshIndicator(
        onRefresh: fetchSubjectData,
        child: ListView.builder(
          padding: const EdgeInsets.all(0.0),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return GestureDetector(
              onTap: (){
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationDetailScreen(
                      notification: notification,
                      onMarkAsRead: () {
                        setState(() {
                          notifications[index]['isRead'] = true;
                        });
                      },
                    ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                child: ListTile(
                  contentPadding:  EdgeInsets.all(3),
                  leading: Container(
                    width: 30.sp,
                    height: 30.sp,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child:  Icon(Icons.notifications, color: AppColors.primary),
                  ),
                  title: Text(
                    notification['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: notification['isRead'] == true ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['description'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 11.sp),
                        ),
                        Text(
                          AppDateTimeUtils.date( notification['date']?? ''),
                          style: GoogleFonts.poppins(
                            fontSize: 9.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // trailing: notification['attachment'] != null
                  //     ?  Icon(Icons.attachment, color: AppColors.primary)
                  //     : null,
                ),
              ),
            );
          },
        ),
      ),



    );
  }
}


class NotificationDetailScreen extends StatefulWidget {
  final Map notification;
  final VoidCallback onMarkAsRead;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
    required this.onMarkAsRead,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen>
    with SingleTickerProviderStateMixin {
  bool isMarking = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> markAsRead() async {
    setState(() {
      isMarking = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onMarkAsRead();
    setState(() {
      isMarking = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Marked as Read',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;

    return WillPopScope(
      onWillPop: () async {
        if (widget.notification['isRead'] == false) {
          await markAsRead();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Notification',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header Section
              SliverAppBar(
                expandedHeight: screenHeight * 0.13,
                floating: false,
                pinned: false,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: EdgeInsets.fromLTRB(
                      screenWidth * 0.05,
                      screenWidth * 0.03,
                      screenWidth * 0.05,
                      screenWidth * 0.05,
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          widget.notification['title'] ?? 'Notification',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 20 : 16.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenWidth * 0.02),
                        // Date & Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: screenWidth > 600 ? 18 : 16,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            SizedBox(width: screenWidth * 0.025),
                            Text(
                              AppDateTimeUtils.date(
                                widget.notification['date'] ?? '',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 15 : 13,
                                color: Colors.grey.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Content Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenWidth * 0.05,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description Card
                      _buildContentCard(
                        title: 'Description',
                        content: widget.notification['description'] ??
                            'No description available',
                        screenWidth: screenWidth,
                        isTablet: isTablet,
                      ),
                      SizedBox(height: screenWidth * 0.06),

                      // Attachment Section
                      if (widget.notification['attachment'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attachments',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: screenWidth * 0.035),
                            _buildAttachmentTile(
                              widget.notification['attachment'],
                              screenWidth,
                              isTablet,
                            ),
                            SizedBox(height: screenWidth * 0.06),
                          ],
                        ),

                      // Action Button
                      if (widget.notification['isRead'] == false)
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB71C1C)
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isMarking ? null : markAsRead,
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isMarking)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Colors.white,
                                      size: isTablet ? 24 : 22,
                                    ),
                                  SizedBox(width: screenWidth * 0.03),
                                  Text(
                                    isMarking
                                        ? 'Processing...'
                                        : 'Mark as Read',
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 17 : 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: screenWidth * 0.08),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required String content,
    required double screenWidth,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: screenWidth * 0.035),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFB71C1C).withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 16 : 14,
              color: Colors.black87,
              height: 1.8,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentTile(
      dynamic attachment,
      double screenWidth,
      bool isTablet,
      ) {
    String fileName = 'File';
    String fileType = 'UNKNOWN';
    IconData fileIcon = Icons.attachment_rounded;

    if (attachment is String) {
      fileName = attachment.split('/').last;

      if (attachment.contains('.pdf')) {
        fileType = 'PDF';
        fileIcon = Icons.picture_as_pdf_rounded;
      } else if (attachment.contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)'))) {
        fileType = 'IMAGE';
        fileIcon = Icons.image_rounded;
      } else if (attachment.contains(RegExp(r'\.(doc|docx)'))) {
        fileType = 'DOCUMENT';
        fileIcon = Icons.description_rounded;
      } else if (attachment.contains(RegExp(r'\.(xls|xlsx)'))) {
        fileType = 'SPREADSHEET';
        fileIcon = Icons.table_chart_rounded;
      } else if (attachment.contains(RegExp(r'\.(zip|rar|7z)'))) {
        fileType = 'ARCHIVE';
        fileIcon = Icons.folder_zip_rounded;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB71C1C).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenWidth * 0.03,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFB71C1C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            fileIcon,
            color: const Color(0xFFB71C1C),
            size: isTablet ? 26 : 24,
          ),
        ),
        title: Text(
          fileName,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          fileType,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 13 : 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFB71C1C).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.download_rounded,
              color: const Color(0xFFB71C1C),
              size: isTablet ? 22 : 20,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.download, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'Downloading...',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFB71C1C),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(
                      bottom: 20, left: 16, right: 16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}