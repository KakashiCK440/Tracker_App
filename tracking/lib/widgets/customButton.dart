
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class CustomButton extends StatelessWidget {
  CustomButton({
    super.key,
    required this.text,
    this.onTap,
    this.color,
    this.textcolor,
    this.borderColor, // Add border color parameter
    this.borderWidth = 2.0, // Default border width
  });

  Color? textcolor;
  Color? color;
  Color? borderColor; // New variable for border color
  final String text;
  final double borderWidth; // New variable for border width
  void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            color: color ?? Colors.transparent,
            border: Border.all(
              color: borderColor ?? Colors.black, // Set border color
              width: borderWidth, // Set border width
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w100,
                fontSize: 16,
                color: textcolor ?? const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
