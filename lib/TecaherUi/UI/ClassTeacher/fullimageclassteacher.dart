
import 'package:avi/UI/Gallery/Album/album.dart' show Album;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class FullImageTeacher extends StatefulWidget {
  final String images; // Assuming Album contains the list of images

  const FullImageTeacher({
    super.key,
    required this.images,
  });

  @override
  State<FullImageTeacher> createState() => _FullScreenImageSliderState();
}

class _FullScreenImageSliderState extends State<FullImageTeacher> {

  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {
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
          '', // Show current image index
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body:Center(
        child: CachedNetworkImage(
          imageUrl: widget.images,
          height: double.infinity,
          width: double.infinity,
          fit: BoxFit.cover, // Fit image to screen without cropping
          placeholder: (context, url) => const Center(
            child: CupertinoActivityIndicator(radius: 20),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.error,
            color: Colors.white,
            size: 50,
          ),
        ),
      ),
    );
  }
}