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
  bool isLocalFavorite = false; 

  @override
  void initState() {
    super.initState();
    currentPlace = widget.place;
    _checkIfFavorite(); // Sayfa açılınca kontrol et
  }

  // Veritabanında var mı diye kontrol eder
  Future<void> _checkIfFavorite() async {
    if (currentPlace.id != null) {
      bool exists = await DatabaseHelper.instance.isFavorite(currentPlace.id!);
      setState(() {
        isLocalFavorite = exists;
        currentPlace.isLiked = exists ? 1 : 0;
      });
    }
  }

  // FAVORİ EKLEME / ÇIKARMA İŞLEMİ
  Future<void> _toggleFavorite() async {
    if (currentPlace.id == null) return;

    try {
      if (isLocalFavorite) {
        // Zaten favoriyse -> SİL
        await DatabaseHelper.instance.deletePlace(currentPlace.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favorilerden çıkarıldı.")));
        }
      } else {
        // Favori değilse -> EKLE
        currentPlace.isLiked = 1; 
        await DatabaseHelper.instance.insertPlace(currentPlace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favorilere eklendi!")));
        }
      }

      // Ekranı güncelle
      setState(() {
        isLocalFavorite = !isLocalFavorite;
        currentPlace.isLiked = isLocalFavorite ? 1 : 0;
      });
    } catch (e) {
      debugPrint('Favori hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
      }
    }
  }

  // GOOGLE MAPS YÖNLENDİRME (Senin Özelliğin)
  Future<void> _openMap() async {
    final double lat = currentPlace.latitude;
    final double lon = currentPlace.longitude;

    // Google Maps Linki (Doğru format)
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon');

    try {
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Harita hatası: $e');
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
          // 1. ARKA PLAN (Mor Tasarım)
          Positioned(
            top: 0, left: 0, right: 0, height: 350,
            child: Container(
              color: Colors.deepPurple, 
              child: currentPlace.imageName.isNotEmpty 
                  ? Image.asset(currentPlace.imageName, fit: BoxFit.cover) // Varsa resim
                  : const Center(child: Icon(Icons.location_city, size: 100, color: Colors.white30)),
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

          // 3. İÇERİK KARTI (Slide efektli yapı)
          Positioned(
            top: 300, left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      children: [
                        // BAŞLIK VE KALP BUTONU
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentPlace.title,
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orangeAccent, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isLocalFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isLocalFavorite ? Colors.red : Colors.black54,
                                  size: 30,
                                ),
                                onPressed: _toggleFavorite,
                              ),
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
                        const Text("Konum Önizleme", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        // MİNİ HARİTA (Senin kodun buraya gömüldü)
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
                      ],
                    ),
                  ),

                  // YOL TARİFİ BUTONU (En altta sabit)
                  Container(
                    padding: const EdgeInsets.all(0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)]
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _openMap, // Google Maps'i açar
                            icon: const Icon(Icons.directions, color: Colors.white),
                            label: const Text(
                              "Yol Tarifi Al (Google Maps)",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}