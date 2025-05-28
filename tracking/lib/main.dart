import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracking/views/cubits/Auth_cubit.dart';
import 'package:tracking/views/edit_%20profile.dart';
import 'package:tracking/views/home_view.dart';
import 'package:tracking/views/login_view.dart';
import 'package:tracking/views/register_view.dart';
import 'package:tracking/views/setting_view.dart';
import 'package:tracking/views/splash_screen.dart';
import 'package:tracking/views/welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: "https://bhtbcnfcfjzrtufgxovk.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJodGJjbmZjZmp6cnR1Zmd4b3ZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM0OTI0OTAsImV4cCI6MjA1OTA2ODQ5MH0.kvogHD01C8dpMrj_HWAuj9akfi-TnyI87l0VMeNxrvA",
  );

  runApp(const TrackingSystem());
}

class TrackingSystem extends StatefulWidget {
  const TrackingSystem({super.key});

  @override
  State<TrackingSystem> createState() => _TrackingSystemState();
}

class _TrackingSystemState extends State<TrackingSystem> {
  bool isDarkMode = false;

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        routes: {
          "loginView": (context) => LoginView(),
          "welcomeview": (context) => const WelcomePage(),
          "reisterView": (context) => RegisterView(),
          "homePage": (context) => const HomePage(),
          "splashScreen": (context) => const SplashScreen(),
          "pageView": (context) => PageView(),
          "editprofile": (context) => const EditProfile(),
          "setting": (context) => SettingsPage(
                isDarkMode: isDarkMode,
                toggleTheme: toggleTheme,
              ),
        },
        initialRoute: "splashScreen",
      ),
    );
  }
}
