import 'dart:convert';
import 'dart:math'; 
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'models/place.dart';

class PlaceService {
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  // Arama parametresi (searchQuery) eklendi
  Future<List<Place>> fetchPlaces(String category, {String? searchQuery}) async {
    final position = await _getCurrentLocation();
    if (position == null) throw Exception("Konum alınamadı");

    double lat = position.latitude;
    double lon = position.longitude;
    String queryCore = "";
    double radius = 1500; 

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // İSİMLE ARAMA (Büyük/küçük harf duyarsız arama için 'i' parametresi, 5km yarıçap)
      // Not: 'name'~'kelime' Overpass'te regex aramasıdır.
      queryCore = 'node["name"~"$searchQuery",i](around:5000,$lat,$lon);';
    } else {
      // KATEGORİ ARAMA
      if (category == "restaurant") queryCore = 'node["amenity"="restaurant"](around:$radius,$lat,$lon);';
      else if (category == "cafe") queryCore = 'node["amenity"="cafe"](around:$radius,$lat,$lon);';
      else if (category == "history") { queryCore = 'node["historic"](around:2000,$lat,$lon);'; radius = 2000; }
      else if (category == "tourism") { queryCore = 'node["tourism"](around:2000,$lat,$lon);'; radius = 2000; }
    }

    String query = '[out:json];$queryCore out;';
    final url = Uri.parse('https://overpass-api.de/api/interpreter');

    try {
      final response = await http.post(url, body: query);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List elements = data['elements'];

        List<Place> places = elements.map((e) {
          double placeLat = e['lat'];
          double placeLon = e['lon'];
          double distInMeters = Geolocator.distanceBetween(lat, lon, placeLat, placeLon);
          
          List<String> weathers = ["24°C Açık ☀️", "21°C Parçalı Bulutlu ⛅", "19°C Rüzgarlı 💨", "22°C Güneşli 🌞"];
          String randomWeather = weathers[Random().nextInt(weathers.length)];

          return Place(
            id: e['id'],
            title: e['tags']['name'] ?? "İsimsiz Mekan",
            description: "Konum: ${e['tags']['name'] ?? 'Bilinmiyor'}",
            location: "Lat: $placeLat, Lon: $placeLon",
            imageName: "", 
            latitude: placeLat,
            longitude: placeLon,
            distance: distInMeters / 1000, 
            weatherInfo: randomWeather,
          );
        }).where((element) => element.title != "İsimsiz Mekan").toList();

        places.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
        return places;
      } else {
        throw Exception("API Hatası: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Bağlantı hatası: $e");
    }
  }
}