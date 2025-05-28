import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(child: LottieBuilder.asset('assets/Animation - 1745343702961.json', height: 200,)),
         const Text(' No History found', style: TextStyle(fontSize: 16),)
        ],

      ),
    );
  }
}