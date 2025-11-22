import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'place_service.dart'; 
import 'screens/place_details_screen.dart'; 
import 'models/place.dart'; 
import 'data/db_helper.dart'; 
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); 
  runApp(const RoadToApp());
}

class RoadToApp extends StatelessWidget {
  const RoadToApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadTo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      // BURASI BİRLEŞTİRİLDİ:
      // Uygulama Login ile başlayacak, giriş yapılınca '/home' yani senin sayfana gidecek.
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const PlacesScreen(),
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
  final PlaceService _placeService = PlaceService();
  
  List<dynamic> places = []; 
  bool isLoading = false;    
  String statusMessage = "Yükleniyor..."; 

  @override
  void initState() {
    super.initState();
    // Uygulama açılır açılmaz favorileri getir
    loadFavorites();
  }

  // FAVORİLERİ ÇEKME FONKSİYONU
  void loadFavorites() async {
    setState(() {
      isLoading = true;
      places = [];
      statusMessage = "Favoriler yükleniyor...";
    });

    try {
      List<Place> favs = await DatabaseHelper.instance.getPlaces();
      
      setState(() {
        // Veritabanı objelerini Map'e çevirip listeye atıyoruz
        places = favs.map((p) => p.toMap()).toList();
        isLoading = false;
        if (places.isEmpty) {
          statusMessage = "Henüz hiç favori mekanınız yok.";
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = "Hata: $e";
      });
    }
  }

  // API ARAMA FONKSİYONU
  void searchPlaces(String category) async {
    setState(() {
      isLoading = true; 
      places = [];      
      statusMessage = "$category aranıyor...";
    });

    try {
      var result = await _placeService.fetchPlaces(category);
      
      setState(() {
        places = result;
        isLoading = false;
        if (places.isEmpty) {
          statusMessage = "Yakınlarda bu kategoride mekan bulunamadı.";
        }
      });
    } catch (e) {
      debugPrint("Hata: $e");
      setState(() {
        isLoading = false;
        statusMessage = "Hata oluştu: Konum iznini kontrol et.\n$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RoadTo Keşfet"),
        backgroundColor: Colors.deepPurple.shade100,
        // BURASI BİRLEŞTİRİLDİ: Arkadaşının logout butonu eklendi.
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          
          // --- BUTONLAR ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                // FAVORİLER BUTONU
                ElevatedButton.icon(
                  onPressed: loadFavorites, 
                  icon: const Icon(Icons.favorite, size: 18, color: Colors.white),
                  label: const Text("Favorilerim", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 10),
                
                _buildFilterButton("Restoran", "restaurant", Icons.restaurant, Colors.orange),
                const SizedBox(width: 10),
                _buildFilterButton("Kafe", "cafe", Icons.coffee, Colors.brown),
                const SizedBox(width: 10),
                _buildFilterButton("Tarihi", "history", Icons.museum, Colors.purple),
                const SizedBox(width: 10),
                _buildFilterButton("Turistik", "tourism", Icons.camera_alt, Colors.blue),
              ],
            ),
          ),
          
          const Divider(),

          // --- LİSTELEME ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator()) 
                : places.isEmpty
                    ? Center(child: Text(statusMessage, textAlign: TextAlign.center))
                    : ListView.builder(
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          var item = places[index];
                          
                          // VERİ AYRIŞTIRMA (API vs DB Farkı)
                          String name = "İsimsiz";
                          double lat = 0.0;
                          double lon = 0.0;
                          int? id;

                          if (item.containsKey('tags')) { 
                            // API VERİSİ (tags içinde gelir)
                            name = item['tags']['name'] ?? "İsimsiz Mekan";
                            lat = item['lat'] ?? item['center']?['lat'] ?? 0.0;
                            lon = item['lon'] ?? item['center']?['lon'] ?? 0.0;
                            id = item['id'];
                          } else {
                            // DB VERİSİ (direkt gelir)
                            name = item['title'];
                            lat = item['latitude'];
                            lon = item['longitude'];
                            id = item['id'];
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            elevation: 3,
                            child: ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.red),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Lat: $lat\nLon: $lon"), // Koordinatı gösterir (Debug için iyi)
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              
                              onTap: () async {
                                if (lat != 0.0 && lon != 0.0) {
                                  Place p = Place(
                                    id: id ?? 0, 
                                    title: name,
                                    description: "Mekan detayları...", 
                                    imageName: "", 
                                    location: "Lat: $lat, Lon: $lon",
                                    latitude: lat,
                                    longitude: lon,
                                    isLiked: 0, 
                                  );

                                  // Detay sayfasına git
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlaceDetailsScreen(place: p),
                                    ),
                                  );
                                  
                                  // Eğer şu an favoriler ekranındaysak, geri dönünce listeyi yenile
                                  if(statusMessage.contains("Favoriler") || statusMessage.contains("yok")) {
                                      loadFavorites(); 
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String categoryKey, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () => searchPlaces(categoryKey),
      icon: Icon(icon, size: 18, color: Colors.white), 
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}