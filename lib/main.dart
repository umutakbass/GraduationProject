import 'package:flutter/material.dart';
import 'place_service.dart'; // Servis dosyan
import 'screens/place_details_screen.dart'; // <-- EĞER HATA VERİRSE DOSYA YOLUNU KONTROL ET
import 'models/place.dart'; // <-- EĞER HATA VERİRSE DOSYA YOLUNU KONTROL ET

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
      ),
      home: const PlacesScreen(),
    );
  }
}

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  // Servis dosyamızı çağırıyoruz
  final PlaceService _placeService = PlaceService();
  
  List<dynamic> places = []; 
  bool isLoading = false;    
  String statusMessage = "Kategori seçerek aramaya başla..."; 

  // Arama Fonksiyonu
  void searchPlaces(String category) async {
    setState(() {
      isLoading = true; 
      places = [];      
      statusMessage = "Konum alınıyor ve mekanlar aranıyor...";
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
      debugPrint("Hata: $e"); // print yerine debugPrint daha iyidir
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
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          
          // --- BUTONLARIN OLDUĞU KISIM ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
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

          // --- LİSTELEME KISMI ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator()) 
                : places.isEmpty
                    ? Center(child: Text(statusMessage, textAlign: TextAlign.center))
                    : ListView.builder(
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          var place = places[index];
                          
                          // İsim ve koordinat verilerini güvenli şekilde alıyoruz
                          var tags = place['tags'] ?? {};
                          var name = tags['name'] ?? "İsimsiz Mekan";
                          
                          var lat = place['lat'] ?? place['center']?['lat'] ?? 0.0;
                          var lon = place['lon'] ?? place['center']?['lon'] ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            elevation: 3,
                            child: ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.red),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Detaylar için tıkla"), // Kullanıcıyı yönlendiriyoruz
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              isThreeLine: false, 

                              // --- TIKLAMA ÖZELLİĞİ EKLENDİ ---
                              onTap: () {
                                if (lat != 0.0 && lon != 0.0) {
                                  
                                  // 1. API Verisini Place Modeline Çeviriyoruz
                                  Place apiPlace = Place(
                                    id: int.tryParse(place['id'].toString()) ?? 0,
                                    title: name,
                                    description: "Bu mekan OpenStreetMap verileri kullanılarak bulunmuştur.",
                                    imageName: "", // RESİM YOK, ARTIK SORUN DEĞİL
                                    location: "Lat: $lat, Lon: $lon",
                                    latitude: lat,
                                    longitude: lon,
                                    isLiked: 0,
                                  );

                                  // 2. Detay Sayfasına Yönlendiriyoruz
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlaceDetailsScreen(place: apiPlace),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Bu mekanın konum verisi eksik!")),
                                  );
                                }
                              },
                              // ---------------------------------
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI BUTON FONKSİYONU ---
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