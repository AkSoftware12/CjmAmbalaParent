import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class  WhiteCircularProgressWidget extends StatelessWidget {
  const WhiteCircularProgressWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child:  CupertinoActivityIndicator(radius: 30,color: Colors.white,),// Show progress bar here
    );
  }
}
