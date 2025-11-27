
import 'package:avi/UI/Gallery/Album/album.dart' show Album;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class FullScreenImageSlider extends StatefulWidget {
  final Album images; // Assuming Album contains the list of images
  final int initialIndex;

  const FullScreenImageSlider({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageSlider> createState() => _FullScreenImageSliderState();
}

class _FullScreenImageSliderState extends State<FullScreenImageSlider> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background for full-screen view
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1}/${widget.images.albumImages.length}', // Show current image index
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.albumImages.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index; // Update current index when swiping
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: CachedNetworkImage(
              imageUrl: widget.images.albumImages[index].imageUrlFull.toString(),
              fit: BoxFit.contain, // Fit image to screen without cropping
              placeholder: (context, url) => const Center(
                child: CupertinoActivityIndicator(radius: 20),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.error,
                color: Colors.white,
                size: 50,
              ),
            ),
          );
        },
      ),
    );
  }
}