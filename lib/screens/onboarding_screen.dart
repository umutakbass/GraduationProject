import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  List<Map<String, dynamic>> contents = [
    {
      "title": "Çevreni Keşfet 🌍",
      "desc": "Etrafındaki restoranları, kafeleri ve tarihi yerleri anında bul.",
      "icon": Icons.map_outlined, 
    },
    {
      "title": "Favorilerini Kaydet ❤️",
      "desc": "Beğendiğin yerleri listene ekle, kişisel notlarını al.",
      "icon": Icons.favorite_border,
    },
    {
      "title": "Rütbeni Yükselt 🏆",
      "desc": "Gezdiğin yerleri işaretle, puan topla ve 'Rota Ustası' ol!",
      "icon": Icons.emoji_events_outlined,
    },
  ];

  // Tanıtım bittiğinde çalışır
  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true); // "Gördüm" diye işaretle
    
    if (mounted) {
      // Direkt giriş ekranına at
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1), // Koyu Mavi Tema
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: contents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // İkon Alanı
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            contents[index]["icon"],
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Başlık
                        Text(
                          contents[index]["title"],
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        // Açıklama
                        Text(
                          contents[index]["desc"],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Alt Kontrol Paneli (Noktalar ve Buton)
            Padding(
              padding: const EdgeInsets.only(bottom: 50, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sayfa Noktaları
                  Row(
                    children: List.generate(
                      contents.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 10,
                        width: _currentPage == index ? 25 : 10,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: _currentPage == index ? Colors.blueAccent : Colors.white54,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  
                  // İleri / Başla Butonu
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == contents.length - 1) {
                        _finishOnboarding();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: Text(
                      _currentPage == contents.length - 1 ? "Başla" : "İleri",
                      style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}