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
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final db = DatabaseHelper.instance;
    final exists = await db.isFavorite(currentPlace.id ?? -1);

    setState(() {
      isLocalFavorite = exists;
    });
  }

  Future<void> _toggleFavorite() async {
    final db = DatabaseHelper.instance;

    try {
      if (isLocalFavorite) {
        await db.deletePlace(currentPlace.id ?? -1);
      } else {
        await db.insertPlace(currentPlace.copyWith(isLiked: 1));
      }

      setState(() {
        isLocalFavorite = !isLocalFavorite;
        currentPlace = currentPlace.copyWith(isLiked: isLocalFavorite ? 1 : 0);
      });
    } catch (e) {
      debugPrint("Favori hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Favori işlemi başarısız: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double lat = currentPlace.latitude;
    final double lon = currentPlace.longitude;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      appBar: AppBar(
        title: Text(
          currentPlace.title,
          style: GoogleFonts.poppins(
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isLocalFavorite ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              currentPlace.imageName,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            currentPlace.title,
            style: GoogleFonts.poppins(
              textStyle: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            currentPlace.description,
            style: GoogleFonts.poppins(
              textStyle: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black54,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Map preview
          SizedBox(
            height: 230,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lon),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: LatLng(lat, lon),
                        child: const Icon(
                          Icons.location_pin,
                          size: 36,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Google Maps Route Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.directions, color: Colors.white),
                label: const Text(
                  "Yol Tarifi Al",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // GOOGLE MAPS’A ROTA AÇAN FONKSİYON (FINAL)
  // ---------------------------------------------------
  Future<void> _openMap() async {
    final double lat = currentPlace.latitude;
    final double lon = currentPlace.longitude;

    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    try {
      if (!await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      )) {
        await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      debugPrint('Harita açma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google Haritalar açılamadı: $e")),
        );
      }
    }
  }
}
