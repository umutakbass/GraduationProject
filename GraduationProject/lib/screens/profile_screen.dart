import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  // Form kontrolcüleri
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String userName = "Gezgin";
  int userId = 0;
  bool isLoading = false;
  bool isStatsLoading = true;

  // Oyun verileri
  String levelName = "Çaylak";
  String progressText = "0/5 Gezgin olmaya";
  int visitedCount = 0;
  List<dynamic> badges = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileStats();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('currentUserId') ?? 0;
      userName = prefs.getString('currentUserName') ?? "Gezgin";
    });
  }

  Future<void> _loadProfileStats() async {
    setState(() => isStatsLoading = true);
    try {
      final result = await _apiService.getUserProfile();
      if (result['success'] == true && mounted) {
        final profile = result['profile'] ?? {};
        setState(() {
          levelName = (profile['title'] ?? "Çaylak").toString();
          progressText = (profile['progress_text'] ?? "0/5 Gezgin olmaya").toString();
          visitedCount = (profile['visited_count'] ?? 0) as int;
          badges = (profile['badges'] ?? []) as List<dynamic>;
        });
      }
    } catch (_) {
      // sessiz geç
    } finally {
      if (mounted) setState(() => isStatsLoading = false);
    }
  }

  // ---------- UI helpers ----------
  String _levelEmoji(String lvl) {
    final l = lvl.toLowerCase();
    if (l.contains("çaylak")) return "🐣";
    if (l.contains("gezgin")) return "🧍";
    if (l.contains("kaşif")) return "🧭";
    if (l.contains("usta")) return "🏔";
    return "🎮";
  }

  IconData _badgeIcon(String iconName, {required bool unlocked}) {
    // Backend ikon adları: flag / walk / map / mountain (senin server.py)
    switch (iconName) {
      case "flag":
        return Icons.flag;
      case "walk":
        return Icons.directions_walk;
      case "map":
        return Icons.explore;
      case "mountain":
        return Icons.terrain;
      default:
        return unlocked ? Icons.emoji_events : Icons.lock;
    }
  }

  // progressText: "2/5 Kaşif olmaya" gibi
  double _progressValueFromText(String text) {
    if (text.toLowerCase().contains("maksimum")) return 1.0;
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);
    if (match == null) return 0.0;
    final a = int.tryParse(match.group(1) ?? "0") ?? 0;
    final b = int.tryParse(match.group(2) ?? "1") ?? 1;
    if (b <= 0) return 0.0;
    return (a / b).clamp(0.0, 1.0);
  }

  String _motivationalText() {
    // Oyunsu kısa motivasyon cümlesi
    final t = progressText.toLowerCase();
    if (t.contains("maksimum")) return "👑 Zirvedesin! Yeni hedefler belirle.";
    if (t.contains("gezgin olmaya")) return "🔥 Başlıyoruz! Birkaç yer daha, Gezgin oluyorsun.";
    if (t.contains("kaşif olmaya")) return "✨ Harika gidiyorsun! Kaşif olmak çok yakın.";
    if (t.contains("usta gezgin olmaya")) return "🏁 Son düzlük! Usta Gezgin’e az kaldı.";
    return "🚀 Devam! Bir sonraki seviyeye yaklaşıyorsun.";
  }

  String _requirementText(String badgeName) {
    final n = badgeName.toLowerCase();
    if (n.contains("ilk")) return "Bu başarı için 1 yer gezmelisin.";
    if (n.contains("gezgin")) return "Bu başarı için toplam 5 yer gezmelisin.";
    if (n.contains("kaşif")) return "Bu başarı için toplam 10 yer gezmelisin.";
    if (n.contains("usta")) return "Bu başarı için toplam 20 yer gezmelisin.";
    return "Bu başarı için daha fazla yer gezmelisin.";
  }

  void _openBadgeSheet(Map<String, dynamic> badge) {
    final unlocked = badge['unlocked'] == true;
    final name = (badge['name'] ?? "Başarım").toString();
    final iconName = (badge['icon'] ?? "").toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 30,
                backgroundColor: unlocked ? Colors.amber.withOpacity(0.18) : Colors.grey.withOpacity(0.15),
                child: Icon(
                  _badgeIcon(iconName, unlocked: unlocked),
                  size: 34,
                  color: unlocked ? Colors.amber[800] : Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                unlocked ? "✅ Kazanıldı!" : "🔒 Kilitli",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: unlocked ? Colors.green : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                unlocked ? "Bu başarımı aldın, tebrikler! 🎉" : _requirementText(name),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 14),
              if (!unlocked)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.explore, color: Colors.white),
                    label: const Text("Gezmeye devam!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text("Kapat", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------- actions ----------
  Future<void> _updateProfile() async {
    if (_emailController.text.isEmpty && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen en az bir alanı doldurun.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await _apiService.updateProfileSettings(
        userId,
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Sunucudan yanıt gelmedi"),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final progressValue = _progressValueFromText(progressText);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Profilim",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: "Çıkış Yap",
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===================== HERO (LEVEL) =====================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: isStatsLoading
                    ? const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // üst satır: hoşgeldin + küçük chip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Hoşgeldin, $userName",
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.place, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$visitedCount",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // büyük rozet
                          Center(
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.18),
                                border: Border.all(color: Colors.white.withOpacity(0.28), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  _levelEmoji(levelName),
                                  style: const TextStyle(fontSize: 42),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Center(
                            child: Text(
                              levelName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          Center(
                            child: Text(
                              _motivationalText(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // progress text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                progressText,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "${(progressValue * 100).round()}%",
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: progressValue,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 22),

              // ===================== ACHIEVEMENTS =====================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Başarımlar",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _loadProfileStats,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Yenile"),
                  )
                ],
              ),
              const SizedBox(height: 10),

              // 2x2 grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: badges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final b = (badges[index] as Map<String, dynamic>);
                  final unlocked = b['unlocked'] == true;
                  final name = (b['name'] ?? "").toString();
                  final iconName = (b['icon'] ?? "").toString();

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openBadgeSheet(b),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: unlocked
                            ? const LinearGradient(
                                colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [Colors.grey.shade200, Colors.grey.shade100],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: unlocked ? Colors.orange.withOpacity(0.25) : Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          )
                        ],
                        border: Border.all(
                          color: unlocked ? Colors.orange.withOpacity(0.25) : Colors.grey.withOpacity(0.25),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: unlocked ? Colors.white.withOpacity(0.25) : Colors.white,
                                      child: Icon(
                                        _badgeIcon(iconName, unlocked: unlocked),
                                        color: unlocked ? Colors.white : Colors.grey[700],
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      unlocked ? Icons.check_circle : Icons.lock,
                                      color: unlocked ? Colors.white : Colors.grey[600],
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: unlocked ? Colors.white : Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  unlocked ? "Kazandın! 🎉" : "Dokun → nasıl açılır?",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: unlocked ? Colors.white.withOpacity(0.9) : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // kilit overlay
                          if (!unlocked)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 22),

              // ===================== SETTINGS (COLLAPSIBLE) =====================
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: const Icon(Icons.settings, color: Colors.blueAccent),
                  title: Text(
                    "Hesap Ayarları",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "E-posta / şifre güncelle",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                  ),
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Yeni E-posta",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        helperText: "Değiştirmek istemiyorsan boş bırak",
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Yeni Şifre",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        helperText: "En az 6 karakter olmalı",
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                "Değişiklikleri Kaydet",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // küçük ipucu
              Center(
                child: Text(
                  "İpucu: Ekranı aşağı çek → profil verilerini yenile",
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
