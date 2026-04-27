import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../HexColorCode/HexColor.dart';
import '../Compose/compose_msg.dart';
import '../Inbox/inbox.dart';
import '../SendMsg/send_msg.dart';

class AdminMsgTabScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const AdminMsgTabScreen({super.key, this.messageSendPermissionsApp});

  @override
  State<AdminMsgTabScreen> createState() => _AttendanceTabScreenState();
}

class _AttendanceTabScreenState extends State<AdminMsgTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          iconTheme: IconThemeData(color: AppColors.textwhite),
          backgroundColor: AppColors.secondary,
          title: Text(
            'Messages',
            style: GoogleFonts.montserrat(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.normal,
              color: AppColors.textwhite,
            ),
          ),
        ),
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
            ),
            child: Column(
              children: [
                // _topHeader(),
                SizedBox(height: 2.h),
                _tabBar(),
                SizedBox(height: 2.h),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      InboxScreen(messageSendPermissionsApp: widget.messageSendPermissionsApp,),
                      ComposeMessageScreen(messageSendPermissionsApp: widget.messageSendPermissionsApp,),
                      SendMsgScreen(messageSendPermissionsApp: widget.messageSendPermissionsApp,),

                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3.w),
      child: Container(
        height:35.sp, // ✅ FIXED HEIGHT
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: HexColor('#010071')),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: HexColor('#010071'),

          // 👇 IMPORTANT (text compress)
          labelPadding: EdgeInsets.zero,

          labelStyle: GoogleFonts.poppins(
            fontSize: 9.sp, // 🔥 thoda chhota karo warna overflow aayega
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: "Inbox"),
            Tab(text: "Compose"),
            Tab(text: "Send"),
          ],
        ),
      ),
    );
  }
}
