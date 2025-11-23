import 'dart:ui'; // Blur efekti için
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

// --- DOSYA İMPORTLARI ---
import 'place_service.dart'; 
import 'models/place.dart';  
import 'data/db_helper.dart'; 
import 'screens/place_details_screen.dart'; 
import 'screens/login_screen.dart'; 
import 'screens/register_screen.dart'; 
import 'screens/onboarding_screen.dart'; // ONBOARDING EKLENDİ

// --- UYGULAMA BAŞLANGIÇ NOKTASI ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  // --- TEST İÇİN: Aşağıdaki satırı yorumdan çıkarıp 1 kere çalıştırırsan Onboarding geri gelir ---
  // await prefs.setBool('seenOnboarding', false); 
  // -----------------------------------------------------------------------------------------

  final isLoggedIn = prefs.containsKey('currentUserId');
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  // Başlangıç Rota Mantığı:
  // 1. Daha önce Onboarding görmediyse -> Onboarding'e git.
  // 2. Gördüyse ve Giriş yaptıysa -> Home'a git.
  // 3. Gördü ama Giriş yapmadıysa -> Login'e git.
  String initialRoute = '/onboarding';
  if (seenOnboarding) {
    initialRoute = isLoggedIn ? '/home' : '/login';
  }

  runApp(GezintooApp(initialRoute: initialRoute));
}

class GezintooApp extends StatelessWidget {
  final String initialRoute;
  const GezintooApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gezintoo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      initialRoute: initialRoute, 
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const PlacesScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

// --- ANA EKRAN (PLACES SCREEN) ---
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PlaceService _placeService = PlaceService();
  final TextEditingController _searchController = TextEditingController();

  List<Place> places = []; 
  bool isLoading = false;
  String statusMessage = "Yükleniyor...";
  String currentUserName = "Misafir"; 
  String currentTitle = "Gezintoo"; 
  String currentSubtitle = "Rotanı Keşfet!"; 
  bool isShowingFavorites = false;
  bool isShowingVisited = false;

  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  late Animation<double> _blurAnimation;
  bool _isMenuOpen = false;

  final Color darkBlue = const Color(0xFF1A237E);
  final Color lightBlue = const Color(0xFF42A5F5);
  final Color accentBlue = const Color(0xFF2962FF);

  @override
  void initState() {
    super.initState();
    searchPlaces("restaurant", "Gezintoo"); 
    _loadUserName();

    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeOut));
    _blurAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void _onMenuItemSelected(VoidCallback action) {
    _toggleMenu(); 
    Future.delayed(const Duration(milliseconds: 200), action);
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('currentUserId');
    if (userId != null) {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        setState(() { 
           currentUserName = (maps.first['name'] as String?) ?? "Gezgin"; 
        });
      }
    }
  }

  void loadFavorites() async {
    setState(() { isLoading = true; places = []; statusMessage = "Favoriler yükleniyor..."; isShowingFavorites = true; isShowingVisited = false; currentTitle = "Favorilerim"; currentSubtitle = "Kaydettiğin mekanlar"; });
    try {
      List<Place> favs = await DatabaseHelper.instance.getPlaces();
      setState(() { places = favs; isLoading = false; if (places.isEmpty) statusMessage = "Henüz hiç favori mekanınız yok."; });
    } catch (e) { setState(() { isLoading = false; statusMessage = "Hata: $e"; }); }
  }

  void loadVisited() async {
    setState(() { isLoading = true; places = []; statusMessage = "Ziyaretler yükleniyor..."; isShowingFavorites = false; isShowingVisited = true; currentTitle = "Ziyaretlerim"; currentSubtitle = "Gezdiğin yerler"; });
    try {
      List<Place> visits = await DatabaseHelper.instance.getVisitedPlaces();
      setState(() { places = visits; isLoading = false; if (places.isEmpty) statusMessage = "Henüz ziyaret işaretlemediniz."; });
    } catch (e) { setState(() { isLoading = false; statusMessage = "Hata: $e"; }); }
  }

  void searchPlaces(String category, [String? customTitle]) async {
    setState(() { 
      isLoading = true; 
      places = []; 
      statusMessage = "Aranıyor..."; 
      isShowingFavorites = false; 
      isShowingVisited = false;
      
      if (customTitle != null) {
        currentTitle = customTitle;
      } else {
        if(category == "search") currentTitle = "Arama Sonuçları";
        else if(category == "restaurant") currentTitle = "Restoranlar";
        else if(category == "cafe") currentTitle = "Kafeler";
        else if(category == "history") currentTitle = "Tarihi Mekanlar";
        else if(category == "tourism") currentTitle = "Turistik Yerler";
        else currentTitle = "Keşfet";
      }
      currentSubtitle = "Rotanı Keşfet!";
    });

    try {
      List<Place> result;
      if (category == "search") {
        result = await _placeService.fetchPlaces("", searchQuery: _searchController.text.trim());
      } else {
        result = await _placeService.fetchPlaces(category);
      }
      setState(() { places = result; isLoading = false; if (places.isEmpty) statusMessage = "Mekan bulunamadı."; });
    } catch (e) { 
      String errorMsg = e.toString();
      if(errorMsg.contains("429")) errorMsg = "Çok fazla istek yapıldı. Lütfen bekleyin.";
      setState(() { isLoading = false; statusMessage = errorMsg; }); 
    }
  }

  void _resetToHome() { searchPlaces("restaurant", "Gezintoo"); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.blue[50],
      endDrawer: _buildGlassDrawer(context),
      
      body: Stack(
        children: [
          Column(
            children: [
              _buildCustomHeader(context, currentTitle, currentSubtitle),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Mekan veya yer ara...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () { if (_searchController.text.isNotEmpty) { searchPlaces("search"); FocusScope.of(context).unfocus(); } }),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: (value) { if (value.isNotEmpty) searchPlaces("search"); },
                ),
              ),

              if (isShowingFavorites || isShowingVisited)
                Padding(padding: const EdgeInsets.all(10.0), child: _buildFilterButton("Keşfet'e Dön", Icons.home, Colors.orange, isSpecial: true, onTap: _resetToHome)),

              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: accentBlue))
                    : places.isEmpty
                        ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(statusMessage, textAlign: TextAlign.center)))
                        : ListView.builder(padding: const EdgeInsets.fromLTRB(15, 5, 15, 100), itemCount: places.length, itemBuilder: (context, index) => _buildPlaceCard(context, places[index])),
              ),
            ],
          ),

          if (_isMenuOpen)
            Positioned.fill(child: GestureDetector(onTap: _toggleMenu, child: AnimatedBuilder(animation: _blurAnimation, builder: (context, child) { return BackdropFilter(filter: ImageFilter.blur(sigmaX: _blurAnimation.value, sigmaY: _blurAnimation.value), child: Container(color: Colors.black.withOpacity(0.3 * _fabController.value))); }))),

          Positioned(
            right: 20,
            bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAnimatedMenuItem(6, "Favorilerim", Icons.favorite, Colors.red, () => _onMenuItemSelected(loadFavorites)),
                const SizedBox(height: 10),
                _buildAnimatedMenuItem(5, "Ziyaretlerim", Icons.check_circle, Colors.green, () => _onMenuItemSelected(loadVisited)),
                const SizedBox(height: 10),
                _buildAnimatedMenuItem(4, "Restoran", Icons.restaurant, Colors.redAccent, () => _onMenuItemSelected(() => searchPlaces("restaurant", "Restoranlar"))),
                const SizedBox(height: 10),
                _buildAnimatedMenuItem(3, "Kafe", Icons.coffee, Colors.orange, () => _onMenuItemSelected(() => searchPlaces("cafe", "Kafeler"))),
                const SizedBox(height: 10),
                _buildAnimatedMenuItem(2, "Tarihi", Icons.museum, Colors.brown, () => _onMenuItemSelected(() => searchPlaces("history", "Tarihi Mekanlar"))),
                const SizedBox(height: 10),
                _buildAnimatedMenuItem(1, "Turistik", Icons.camera_alt, Colors.purple, () => _onMenuItemSelected(() => searchPlaces("tourism", "Turistik Yerler"))),
                const SizedBox(height: 20),
                FloatingActionButton(onPressed: _toggleMenu, backgroundColor: accentBlue, shape: const CircleBorder(), child: RotationTransition(turns: Tween(begin: 0.0, end: 0.125).animate(_fabController), child: Icon(_isMenuOpen ? Icons.add : Icons.explore, size: 30, color: Colors.white))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMenuItem(int index, String label, IconData icon, Color color, VoidCallback onTap) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fabController, curve: Interval((0.1 * index), 1.0, curve: Curves.elasticOut)));
    return ScaleTransition(scale: animation, child: Row(mainAxisSize: MainAxisSize.min, children: [if (_isMenuOpen) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)]), child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color))), FloatingActionButton.small(onPressed: onTap, backgroundColor: color, heroTag: null, child: Icon(icon, color: Colors.white))]));
  }

  Widget _buildGlassDrawer(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)]),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),
            border: Border(left: BorderSide(color: Colors.white.withOpacity(0.3), width: 1)),
          ),
          child: Column(
            children: [
              Flexible(
                child: Column(
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2)))),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const CircleAvatar(radius: 35, backgroundColor: Colors.white, child: Icon(Icons.person, size: 45, color: Color(0xFF0D47A1)))),
                            const SizedBox(height: 10),
                            Text(currentUserName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("Hoşgeldiniz", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildDrawerItem(Icons.person_outline, "Profilim", () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); }),
                            _buildDrawerItem(Icons.settings_outlined, "Ayarlar", () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())); }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.all(20.0), child: ElevatedButton.icon(onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.clear(); if(context.mounted) Navigator.pushReplacementNamed(context, '/login'); }, icon: const Icon(Icons.logout, color: Colors.white), label: const Text("Çıkış Yap", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.9), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: Colors.white), title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)), onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5));
  }

  Widget _buildCustomHeader(BuildContext context, String title, String subtitle) {
    return Container(padding: const EdgeInsets.fromLTRB(20, 50, 20, 25), decoration: BoxDecoration(gradient: LinearGradient(colors: [darkBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)), boxShadow: [BoxShadow(color: darkBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1)), Text(subtitle, style: GoogleFonts.poppins(color: Colors.blue[100], fontSize: 14))]), Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () { _scaffoldKey.currentState?.openEndDrawer(); }))]));
  }

  Widget _buildFilterButton(String label, IconData icon, Color color, {bool isSpecial = false, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(30), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: isSpecial ? color : Colors.white, borderRadius: BorderRadius.circular(30), border: isSpecial ? null : Border.all(color: color.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]), child: Row(children: [Icon(icon, size: 18, color: isSpecial ? Colors.white : color), const SizedBox(width: 8), Text(label, style: GoogleFonts.poppins(color: isSpecial ? Colors.white : color, fontWeight: FontWeight.w600))])));
  }

  Widget _buildPlaceCard(BuildContext context, dynamic item) {
    Place place = item as Place;
    return Card(margin: const EdgeInsets.only(bottom: 15), elevation: 4, shadowColor: Colors.blue.withOpacity(0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () async { if (place.latitude != 0.0 && place.longitude != 0.0) { await Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceDetailsScreen(place: place))); if(isShowingFavorites) loadFavorites(); if(isShowingVisited) loadVisited(); } }, child: Padding(padding: const EdgeInsets.all(12.0), child: Row(children: [Container(height: 60, width: 60, decoration: BoxDecoration(color: lightBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.location_on_rounded, color: accentBlue, size: 32)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(place.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)), const SizedBox(height: 4), Row(children: [Icon(Icons.directions_walk, size: 14, color: accentBlue), const SizedBox(width: 4), Text("${(place.distance ?? 0).toStringAsFixed(1)} km uzakta", style: GoogleFonts.poppins(color: accentBlue, fontWeight: FontWeight.bold, fontSize: 12))])])), Icon(Icons.arrow_forward_ios_rounded, color: lightBlue, size: 18)]))));
  }
}

// --- PROFİL EKRANI (İLERLEME ÇUBUĞU İLE) ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "Gezgin";
  int visitedCount = 0;
  String badge = "Acemi Gezgin 🎒";
  int nextTarget = 5;
  double progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('currentUserId');
    if (userId != null) {
      final db = await DatabaseHelper.instance.database;
      final userMaps = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (userMaps.isNotEmpty) userName = (userMaps.first['name'] as String?) ?? "Gezgin";

      final visitedPlaces = await DatabaseHelper.instance.getVisitedPlaces();
      visitedCount = visitedPlaces.length;

      if (visitedCount >= 20) { badge = "Rota Ustası 👑"; nextTarget = 100; }
      else if (visitedCount >= 5) { badge = "Kaşif 🧭"; nextTarget = 20; }
      else { badge = "Acemi Gezgin 🎒"; nextTarget = 5; }

      progress = visitedCount / nextTarget;
      if (progress > 1.0) progress = 1.0;

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(title: const Text("Profilim"), backgroundColor: Colors.blue[50], foregroundColor: const Color(0xFF1A237E)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 60, backgroundColor: Color(0xFF1A237E), child: Icon(Icons.person, size: 80, color: Colors.white)),
            const SizedBox(height: 20),
            Text(userName, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E))),
            const SizedBox(height: 5),
            Text("Gezgin", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),
            
            // --- İLERLEME KARTI ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: Column(
                children: [
                  Text("Seviyen", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 5),
                  Text(badge, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  const SizedBox(height: 15),
                  Text("$visitedCount / $nextTarget Mekan", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress, color: Colors.green, backgroundColor: Colors.green.shade100, minHeight: 10, borderRadius: BorderRadius.circular(5)),
                  const SizedBox(height: 5),
                  Text("Sonraki rütbeye ${nextTarget - visitedCount} mekan kaldı!", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Geri Dön"))
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(title: const Text("Ayarlar"), backgroundColor: Colors.blue[50], foregroundColor: const Color(0xFF1A237E)),
      body: Center(child: Text("Ayarlar yakında eklenecek...", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey))),
    );
  }
}