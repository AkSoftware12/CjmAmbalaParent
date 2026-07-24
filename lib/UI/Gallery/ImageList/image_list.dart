import 'package:avi/UI/Gallery/Album/album.dart' show Album;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../CommonCalling/data_not_found.dart';
import '../../../constants.dart';
import 'ImageFull/image_full.dart';

class ImageListScreen extends StatefulWidget {
  final Album data;
  const ImageListScreen({super.key, required this.data});

  @override
  State<ImageListScreen> createState() => _ImageListScreenState();
}

class _ImageListScreenState extends State<ImageListScreen> {
  bool isLoading = false;
  bool isExpanded = false;

  void _openFullScreenSlider(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageSlider(
          images: widget.data,
          initialIndex: index,
        ),
      ),
    );
  }

  String _cleanDescription(String? html) {
    if (html == null || html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(r'\r\n', '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
  }

  // ===== Description with inline View More / View Less =====
  Widget _buildDescription(String description) {
    final textStyle = GoogleFonts.montserrat(
      fontSize: 12.sp,
      color: Colors.black,
      fontWeight: FontWeight.w600,
      height: 1.5,
    );

    final linkStyle = GoogleFonts.montserrat(
      fontSize: 12.sp,
      fontWeight: FontWeight.w900,
      color: Colors.red, // apne theme ke hisaab se change karo
      height: 1.5,
    );

    const int maxLines = 3;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 8.sp),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          // Pehle check karo text overflow kar raha hai ya nahi
          final fullPainter = TextPainter(
            text: TextSpan(text: description, style: textStyle),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxWidth);

          final isOverflowing = fullPainter.didExceedMaxLines;

          // Agar text chhota hai toh simple text dikhao
          if (!isOverflowing) {
            return Text(description, style: textStyle);
          }

          // ===== EXPANDED: pura text + "View Less" last mein =====
          if (isExpanded) {
            return RichText(
              text: TextSpan(
                style: textStyle,
                children: [
                  TextSpan(text: description),
                  TextSpan(
                    text: ' View Less',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => setState(() => isExpanded = false),
                  ),
                ],
              ),
            );
          }

          // ===== COLLAPSED: truncated text + "... View More" last line ke end mein =====
          const String moreText = '... View More';

          // "... View More" ki width nikalo
          final morePainter = TextPainter(
            text: TextSpan(text: moreText, style: linkStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxWidth);

          // Last line pe "View More" ke liye jagah chhod ke text kahan cut karna hai
          final cutPosition = fullPainter.getPositionForOffset(
            Offset(
              maxWidth - morePainter.width,
              fullPainter.height - 1, // last line ka end
            ),
          );

          int endIndex = cutPosition.offset;
          if (endIndex > description.length) endIndex = description.length;

          final truncated = description.substring(0, endIndex).trimRight();

          return RichText(
            text: TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: truncated),
                TextSpan(
                  text: '... ',
                  style: textStyle,
                ),
                TextSpan(
                  text: 'View More',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => setState(() => isExpanded = true),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = _cleanDescription(widget.data.description); // apne model ka field name use karo

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.data.albumName.toString(),
          style: GoogleFonts.montserrat(
            textStyle: Theme.of(context).textTheme.displayLarge,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textwhite,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 20))
          : widget.data.albumImages.isEmpty
          ? const Center(child: DataNotFoundWidget(title: 'Image Not Available.'))
          : CustomScrollView(
        slivers: [
          if (description.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildDescription(description),
            ),
          SliverPadding(
            padding: EdgeInsets.all(3.sp),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 5.0,
                mainAxisSpacing: 5.0,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  return GestureDetector(
                    onTap: () => _openFullScreenSlider(index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CachedNetworkImage(
                        imageUrl: widget.data.albumImages[index].imageUrlFull.toString(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                        const Center(child: CupertinoActivityIndicator(radius: 20)),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
                  );
                },
                childCount: widget.data.albumImages.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}