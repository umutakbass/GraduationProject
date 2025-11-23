import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _login() async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun.')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      var user = await DatabaseHelper.instance.getUserByEmailAndPassword(email, password);

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('currentUserId', user.id!);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Giriş başarısız. E-posta veya şifre hatalı.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true, 
      body: SingleChildScrollView(
        child: Container(
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)], // Mavi Arka Plan
            ),
          ),
          child: Stack(
            children: [
              // 1. HEADER KISMI
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: size.height * 0.4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 80, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(height: 10),
                        Text("RoadTo", style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        Text("Keşfetmeye Başla", style: GoogleFonts.poppins(color: Colors.blue[100], fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. FORM KARTI
              Positioned(
                top: size.height * 0.33,
                left: 20, right: 20,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tekrar Hoşgeldin!", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E))),
                      const SizedBox(height: 5),
                      Text("Devam etmek için giriş yapın.", style: GoogleFonts.poppins(color: Colors.grey)),
                      const SizedBox(height: 30),

                      TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _buildInputDecoration("E-posta", Icons.email_outlined)),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: _buildInputDecoration("Şifre", Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () { setState(() { _isPasswordVisible = !_isPasswordVisible; }); },
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --- GİRİŞ BUTONU (YEŞİL OLDU) ---
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Container(
                                decoration: BoxDecoration(
                                  // Canlı Yeşil Gradyan
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF66BB6A), Color(0xFF43A047)], // Açık Yeşilden Koyu Yeşile
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: const Color(0xFF43A047).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  child: Text("Giriş Yap", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. ALT LINK
              Positioned(
                bottom: 30, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Hesabın yok mu? ", style: GoogleFonts.poppins(color: Colors.white70)),
                    GestureDetector(
                      onTap: () { Navigator.pushNamed(context, '/register'); },
                      child: Text("Kayıt Ol", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
      filled: true,
      fillColor: Colors.blue[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2)),
      labelStyle: TextStyle(color: Colors.grey[700]),
    );
  }
}