import 'package:flutter/material.dart';

class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 38, 34, 34),
      body: PageView(
        children: [
          _buildPage(
            icon: Icons.track_changes,
            title: 'Track Your Objects',
            description: 'Monitor object locations and movements using AI.',
          ),
          _buildPage(
            icon: Icons.location_on,
            title: 'Find Your Way',
            description: 'Get directions and navigate your way effortlessly.',
          ),
          _buildPage(
            icon: Icons.notifications,
            title: 'Stay Updated',
            description: 'Receive alerts and notifications in real-time.',
          ),
        ],
      ),
    );
  }

  Widget _buildPage({required IconData icon, required String title, required String description}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 100,
              color: Colors.blue,
            ),
          const  SizedBox(height: 30),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          const  SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style:const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          const  SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Handle navigation or action
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child:const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NEXT',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_right_alt, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}