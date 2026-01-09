import 'package:flutter/material.dart';
import '../api_service.dart'; // API servisini çağır
import 'register_screen.dart'; // Kayıt ekranına gitmek için
import 'home_screen.dart'; // DÜZELTME: Mekanların olduğu ana ekranı (PlacesScreen) çağırıyoruz

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Servisimizi tanımlıyoruz
  final ApiService _apiService = ApiService();
  bool _isLoading = false; // Yükleniyor göstergesi için değişken

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Yükleniyor başlat
    });

    try {
      // API'ye giriş isteği gönderiyoruz
      final result = await _apiService.login(email, password);

      if (!mounted) return;

      setState(() {
        _isLoading = false; // Yükleniyor bitir
      });

      if (result['success'] == true) {
        // --- GİRİŞ BAŞARILI ---
        // DÜZELTİLDİ: Artık Chat ekranına değil, Mekanlar (PlacesScreen) ekranına gidiyor.
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const HomeScreen())
        );
      } else {
        // --- GİRİŞ HATALI ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Hatalı e-posta veya şifre.'), 
            backgroundColor: Colors.red
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Giriş Yap"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 100, color: Color(0xFF0D47A1)),
              const SizedBox(height: 30),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "E-posta",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Şifre",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              
              _isLoading 
                ? const CircularProgressIndicator() // Yüklenirken dönen çember
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Giriş Yap", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
              
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  // Kayıt ekranına git
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const RegisterScreen())
                  );
                },
                child: const Text("Hesabın yok mu? Kayıt Ol"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}