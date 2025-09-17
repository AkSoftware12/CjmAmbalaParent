import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Album/album.dart';
import 'Video/video_album_list.dart';



class GalleryVideoTabScreen extends StatefulWidget {
  const GalleryVideoTabScreen({super.key});

  @override
  _GalleryVideoTabScreenState createState() => _GalleryVideoTabScreenState();
}

class _GalleryVideoTabScreenState extends State<GalleryVideoTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Gallery",
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            color: AppColors.textwhite,
          ),

        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50), // Adjust the height as needed
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white, // Customize the indicator color
            labelColor: Colors.white, // Customize the selected tab label color
            unselectedLabelColor: Colors.black, // Customize the unselected tab label color
            indicatorWeight: 3.0, // Thickness of the indicator
            tabs: const [
              Tab(
                icon: Icon(Icons.image),
                text: "Gallery",
              ),
              Tab(
                icon: Icon(Icons.video_collection),
                text: "Video Gallery",
              ),
            ],
          ),
        ),

      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          GalleryScreen(),
          // VideoAlbumListScreen(),
        ],
      ),
    );
  }
}




