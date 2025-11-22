import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../models/place.dart';
import '../../data/db_helper.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailsScreen({super.key, required this.place});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  late Place currentPlace;

  @override
  void initState() {
    super.initState();
    currentPlace = widget.place;
  }

  // --- KESİN ÇALIŞAN HARİTA FONKSİYONU ---
  Future<void> _openMap() async {
    final double lat = currentPlace.latitude;
    final double lon = currentPlace.longitude;

    // Bu standart Google Maps linkidir. Hem iOS hem Android'de çalışır.
    // 'query' kısmına koordinatları virgülle ekliyoruz.
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon');

    try {
      // Önce harici uygulama (App) olarak açmayı dene
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
        // Olmazsa tarayıcıda aç
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Harita açma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Harita açılamadı: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. ARKA PLAN
          Positioned(
            top: 0, left: 0, right: 0, height: 350,
            child: Container(
              color: Colors.deepPurple, 
              child: const Center(
                child: Icon(Icons.location_city, size: 100, color: Colors.white30),
              ),
            ),
          ),
          
          // 2. GERİ BUTONU
          Positioned(
            top: 50, left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. İÇERİK KARTI
          Container(
            margin: const EdgeInsets.only(top: 300),
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            // Liste yapısı sayesinde buton aşağıda kalmaz, kaydırınca görünür
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Başlık
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentPlace.title,
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        currentPlace.isLiked == 1 ? Icons.favorite : Icons.favorite_border,
                        color: currentPlace.isLiked == 1 ? Colors.red : Colors.grey,
                      ),
                      onPressed: () async {
                         try {
                           if(currentPlace.id != null) {
                             await DatabaseHelper.instance.toggleFavorite(currentPlace.id!, currentPlace.isLiked);
                             setState(() {
                               currentPlace.isLiked = currentPlace.isLiked == 1 ? 0 : 1;
                             });
                           }
                         } catch (e) {
                           setState(() {
                             currentPlace.isLiked = currentPlace.isLiked == 1 ? 0 : 1;
                           });
                         }
                      },
                    )
                  ],
                ),
                
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_pin, color: Colors.deepPurple, size: 16),
                    const SizedBox(width: 5),
                    Expanded(child: Text(currentPlace.location, style: const TextStyle(color: Colors.grey))),
                  ],
                ),
                const SizedBox(height: 20),
                
                const Text("Hakkında", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(currentPlace.description.isNotEmpty ? currentPlace.description : "Açıklama yok."),
                
                const SizedBox(height: 20),
                const Text("Konum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // --- HARİTA KUTUSU ---
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(currentPlace.latitude, currentPlace.longitude),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.roadto.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(currentPlace.latitude, currentPlace.longitude),
                            width: 60, height: 60,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- YOL TARİFİ AL BUTONU ---
                // Bu buton ListView'in en altında olduğu için kaybolmaz.
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _openMap, // Yukarıdaki fonksiyonu çağırır
                    icon: const Icon(Icons.directions, color: Colors.white),
                    label: const Text(
                      "Yol Tarifi Al",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Mavi renk
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 4,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40), // En altta rahat boşluk
              ],
            ),
          )
        ],
      ),
    );
  }
}