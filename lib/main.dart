import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

// --- DOSYA YOLLARI ---
import 'place_service.dart'; 
import 'models/place.dart';  
import 'data/db_helper.dart'; 
import 'screens/place_details_screen.dart'; 
import 'screens/login_screen.dart'; 
import 'screens/register_screen.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GezintooApp());
}

class GezintooApp extends StatelessWidget {
  const GezintooApp({super.key});

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
      initialRoute: '/login', 
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const PlacesScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PlaceService _placeService = PlaceService();
  
  List<dynamic> places = [];
  bool isLoading = false;
  String statusMessage = "Yükleniyor...";
  String currentUserName = "Misafir"; 

  // RENKLER
  final Color darkBlue = const Color(0xFF1A237E);
  final Color lightBlue = const Color(0xFF42A5F5);
  final Color accentBlue = const Color(0xFF2962FF);

  @override
  void initState() {
    super.initState();
    loadFavorites();
    _loadUserName(); 
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('currentUserId');
    if (userId != null) {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        setState(() { currentUserName = maps.first['name'] ?? "Gezgin"; });
      }
    }
  }

  void loadFavorites() async {
    setState(() { isLoading = true; places = []; statusMessage = "Favoriler yükleniyor..."; });
    try {
      List<Place> favs = await DatabaseHelper.instance.getPlaces();
      setState(() {
        places = favs.map((p) => p.toMap()).toList();
        isLoading = false;
        if (places.isEmpty) statusMessage = "Henüz hiç favori mekanınız yok.";
      });
    } catch (e) {
      setState(() { isLoading = false; statusMessage = "Hata: $e"; });
    }
  }

  void searchPlaces(String category) async {
    setState(() { isLoading = true; places = []; statusMessage = "$category aranıyor..."; });
    try {
      var result = await _placeService.fetchPlaces(category);
      setState(() {
        places = result;
        isLoading = false;
        if (places.isEmpty) statusMessage = "Yakınlarda bu kategoride mekan bulunamadı.";
      });
    } catch (e) {
      setState(() { isLoading = false; statusMessage = "Hata: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.blue[50],
      endDrawer: _buildGlassDrawer(context),
      body: Column(
        children: [
          _buildCustomHeader(context),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  _buildFilterButton("Restoran", Icons.restaurant, accentBlue, onTap: () => searchPlaces("restaurant")),
                  const SizedBox(width: 10),
                  _buildFilterButton("Kafe", Icons.coffee, accentBlue, onTap: () => searchPlaces("cafe")),
                  const SizedBox(width: 10),
                  _buildFilterButton("Tarihi", Icons.museum, accentBlue, onTap: () => searchPlaces("history")),
                  const SizedBox(width: 10),
                  _buildFilterButton("Turistik", Icons.camera_alt, accentBlue, onTap: () => searchPlaces("tourism")),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: accentBlue))
                : places.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(statusMessage, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: darkBlue, fontSize: 16))))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        itemCount: places.length,
                        itemBuilder: (context, index) => _buildPlaceCard(context, places[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassDrawer(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)], // Login ile aynı mavi gradyan
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),
            border: Border(left: BorderSide(color: Colors.white.withOpacity(0.3), width: 1)),
          ),
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2)))),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const CircleAvatar(radius: 35, backgroundColor: Colors.white, child: Icon(Icons.person, size: 45, color: Color(0xFF0D47A1))),
                      ),
                      const SizedBox(height: 10),
                      Text(currentUserName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Hoşgeldiniz", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildDrawerItem(Icons.person_outline, "Profilim", () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); }),
              _buildDrawerItem(Icons.favorite_border, "Favorilerim", () { Navigator.pop(context); loadFavorites(); }),
              _buildDrawerItem(Icons.settings_outlined, "Ayarlar", () {}),
              const Spacer(),
              
              // --- ÇIKIŞ BUTONU (KIRMIZI OLDU) ---
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); 
                    if(context.mounted) Navigator.pushReplacementNamed(context, '/login');
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text("Çıkış Yap", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.9), // Kırmızı Renk
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [darkBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: darkBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Gezintoo", style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text("Rotanı Keşfet!", style: GoogleFonts.poppins(color: Colors.blue[100], fontSize: 14)),
            ],
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () { _scaffoldKey.currentState?.openEndDrawer(); }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, IconData icon, Color color, {bool isSpecial = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSpecial ? color : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isSpecial ? null : Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Row(children: [Icon(icon, size: 18, color: isSpecial ? Colors.white : color), const SizedBox(width: 8), Text(label, style: GoogleFonts.poppins(color: isSpecial ? Colors.white : color, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, dynamic item) {
    String name = "İsimsiz"; double lat = 0.0; double lon = 0.0; int? id;
    if (item.containsKey('tags')) { name = item['tags']['name'] ?? "İsimsiz Mekan"; lat = item['lat'] ?? item['center']?['lat'] ?? 0.0; lon = item['lon'] ?? item['center']?['lon'] ?? 0.0; id = item['id']; } 
    else { name = item['title']; lat = item['latitude']; lon = item['longitude']; id = item['id']; }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 4, shadowColor: Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
             if (lat != 0.0 && lon != 0.0) {
                Place p = Place(id: id ?? 0, title: name, description: "Mekan detayları...", imageName: "", location: "Lat: $lat, Lon: $lon", latitude: lat, longitude: lon, isLiked: 0);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceDetailsScreen(place: p)));
                if(statusMessage.contains("Favoriler")) { loadFavorites(); }
              }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(height: 60, width: 60, decoration: BoxDecoration(color: lightBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.location_on_rounded, color: accentBlue, size: 32)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)), const SizedBox(height: 4), Text("Koordinatlar: ${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12))])),
              Icon(Icons.arrow_forward_ios_rounded, color: lightBlue, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            Text("Kullanıcı Profili", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E))),
            const SizedBox(height: 10),
            Text("Hoşgeldiniz", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Geri Dön"),
            )
          ],
        ),
      ),
    );
  }
}