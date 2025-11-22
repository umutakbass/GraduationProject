import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PlaceService {
  
  // 1. KONUM ALMA
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Konum servisleri kapalı.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('İzin reddedildi.');
    }
    
    return await Geolocator.getCurrentPosition();
  }

  // 2. API SORGUSU VE FİLTRELEME
  // 'category' parametresi hangi butona bastığını belirleyecek.
  Future<List<dynamic>> fetchPlaces(String category) async {
    // Önce konumu al
    Position position = await _getCurrentLocation();
    double lat = position.latitude;
    double lon = position.longitude;

    // Kategoriye göre Overpass etiketini (Tag) seçiyoruz
    String tagFilter = "";
    
    if (category == 'restaurant') {
      tagFilter = 'node["amenity"="restaurant"](around:1000, $lat, $lon);';
    } else if (category == 'cafe') {
      tagFilter = 'node["amenity"="cafe"](around:1000, $lat, $lon);';
    } else if (category == 'history') {
      tagFilter = 'node["historic"](around:1500, $lat, $lon); way["historic"](around:1500, $lat, $lon);';
    } else if (category == 'tourism') {
      tagFilter = 'node["tourism"](around:1500, $lat, $lon); way["tourism"](around:1500, $lat, $lon);';
    }

    // Sorguyu oluştur
    String query = """
      [out:json];
      (
        $tagFilter
      );
      out center;
    """;

    // İsteği gönder
    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
    );

    if (response.statusCode == 200) {
      var jsonData = json.decode(utf8.decode(response.bodyBytes));
      return jsonData['elements']; // Listeyi döndür
    } else {
      throw Exception("API Hatası");
    }
  }
}