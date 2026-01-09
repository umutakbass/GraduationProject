import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint için
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/place.dart';

class ApiService {
  // ⚠️ Emülatör: 10.0.2.2 | Gerçek Telefon: Bilgisayarın yerel IP'si
  final String baseUrl = "http://10.0.2.2:5000"; 

  Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  // ===================== 1. CHAT =====================
  Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: _headers,
        body: jsonEncode({"text": message, "category": message}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final decoded = utf8.decode(res.bodyBytes);
        final data = jsonDecode(decoded);

        List<Place> places = [];
        if (data['places'] != null) {
          places = (data['places'] as List)
              .map((e) => Place.fromJson(e))
              .toList();
        }

        return {
          "success": true,
          "response": data['response'],
          "places": places,
          "status": data['status']
        };
      }
      return {"success": false, "response": "Sunucu hatası", "places": []};
    } catch (e) {
      return {"success": false, "response": "Hata: $e", "places": []};
    }
  }

  // ===================== 2. MEKAN DETAY =====================
  Future<Map<String, dynamic>> getPlaceDetails(String placeId, int userId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/get_place_details'),
        headers: _headers,
        body: jsonEncode({"place_id": placeId, "user_id": userId}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Hata: $e"};
    }
  }

  // ===================== 3. ETKİLEŞİM =====================
  Future<Map<String, dynamic>> toggleInteraction({
    required int userId,
    required String type,
    required bool status,
    required Place place,
    double rating = 0.0,
  }) async {
    try {
      final body = {
        "user_id": userId,
        "type": type,
        "status": status ? 1 : 0,
        "place": {
          "title": place.title,
          "google_place_id": place.googlePlaceId,
          "imagePath": place.imagePath,
          "rating": rating,
          "location": place.location,
          "latitude": place.latitude,
          "longitude": place.longitude,
          "category": place.category,
        }
      };

      final res = await http.post(
        Uri.parse('$baseUrl/add_interaction'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Hata: $e"};
    }
  }

  // ===================== 4. AUTH =====================
  Future<Map<String, dynamic>> register(String name, String email, String pass) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: _headers,
      body: jsonEncode({"name": name, "email": email, "password": pass}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> login(String email, String pass) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers,
      body: jsonEncode({"email": email, "password": pass}),
    );

    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('currentUserId', data['user']['id']);
      prefs.setString('currentUserName', data['user']['name']);
    }
    return data;
  }

  // ===================== 5. USER PLACES =====================
  Future<List<Place>> getUserPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('currentUserId');
    if (userId == null) return [];

    final res = await http.post(
      Uri.parse('$baseUrl/get_user_places'),
      headers: _headers,
      body: jsonEncode({"user_id": userId}),
    );

    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      return (data['places'] as List)
          .map((e) => Place.fromJson(e))
          .toList();
    }
    return [];
  }

  // ===================== 🔥 PROFİL (LEVEL / OYUN) =====================
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('currentUserId') ?? 1;

      final res = await http.post(
        Uri.parse('$baseUrl/get_user_profile'),
        headers: _headers,
        body: jsonEncode({"user_id": userId}),
      );

      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "profile": {}};
    }
  }

  // ===================== 6. BİLDİRİMLER =====================
  Future<List<dynamic>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('currentUserId');
    if (userId == null) return [];

    final res = await http.post(
      Uri.parse('$baseUrl/get_notifications'),
      headers: _headers,
      body: jsonEncode({"user_id": userId}),
    );

    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      return data['notifications'] ?? [];
    }
    return [];
  }

  // ===================== 7. PROFİL GÜNCELLE =====================
  Future<Map<String, dynamic>> updateProfileSettings(
      int userId, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/update_profile_settings'),
      headers: _headers,
      body: jsonEncode({
        "user_id": userId,
        "email": email,
        "password": password
      }),
    );
    return jsonDecode(res.body);
  }
}
