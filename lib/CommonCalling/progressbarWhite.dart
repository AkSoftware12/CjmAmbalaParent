import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class  WhiteCircularProgressWidget extends StatelessWidget {
  const WhiteCircularProgressWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child:  CupertinoActivityIndicator(radius: 20,color: Colors.white,),// Show progress bar here
    );
  }
}
