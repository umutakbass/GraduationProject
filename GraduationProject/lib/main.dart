import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ekranlarımızı import ediyoruz
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; 
import 'screens/onboarding_screen.dart';
import 'screens/chat_test_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Giriş yapılmış mı ve Onboarding görülmüş mü kontrolü
  final bool isLoggedIn = prefs.containsKey('currentUserId');
  final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn, seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool seenOnboarding;

  const MyApp({
    super.key, 
    required this.isLoggedIn, 
    required this.seenOnboarding
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoadTo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true, 
      ),
      
      home: isLoggedIn 
          ? const HomeScreen() 
          : (seenOnboarding ? const LoginScreen() : const OnboardingScreen()),

      
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/chat': (context) => const ChatTestScreen(),
      },
    );
  }
}