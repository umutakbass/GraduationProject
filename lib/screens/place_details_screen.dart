import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:share_plus/share_plus.dart'; 
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
  bool isVisited = false; 
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentPlace = widget.place;
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (currentPlace.id != null) {
      final db = DatabaseHelper.instance;
      bool fav = await db.isFavorite(currentPlace.id!);
      bool visit = await db.isVisited(currentPlace.id!);
      String? savedNote = await db.getNote(currentPlace.id!);

      if(mounted) {
        setState(() {
          isLocalFavorite = fav;
          isVisited = visit;
          currentPlace.isLiked = fav ? 1 : 0;
          currentPlace.isVisited = visit ? 1 : 0;
          if(savedNote != null) _noteController.text = savedNote;
        });
      }
    }
  }

  Future<void> _saveNote() async {
    if (currentPlace.id == null) return;
    currentPlace.userNote = _noteController.text;
    await DatabaseHelper.instance.insertPlace(currentPlace);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not kaydedildi! 📝")));
  }

  Future<void> _toggleFavorite() async {
    if (currentPlace.id == null) return;
    if (isLocalFavorite) { 
        currentPlace.isLiked = 0;
        await DatabaseHelper.instance.insertPlace(currentPlace);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favorilerden çıkarıldı.")));
    } else { 
        currentPlace.isLiked = 1; 
        await DatabaseHelper.instance.insertPlace(currentPlace); 
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favorilere eklendi!")));
    }
    setState(() => isLocalFavorite = !isLocalFavorite);
  }

  // --- GÜNCELLENEN ZİYARET FONKSİYONU ---
  Future<void> _toggleVisited() async {
    if (currentPlace.id == null) return;
    
    // Durumu değiştir
    int newStatus = isVisited ? 0 : 1;
    currentPlace.isVisited = newStatus;
    await DatabaseHelper.instance.insertPlace(currentPlace);
    
    setState(() => isVisited = !isVisited);

    if(mounted) {
      if (isVisited) {
        // VERİTABANINDAN GÜNCEL SAYIYI ÇEK
        final visitedList = await DatabaseHelper.instance.getVisitedPlaces();
        int count = visitedList.length; // Şu anki toplam ziyaret sayısı
        
        String message = "";
        
        // MATEMATİK HESABI (İstediğin Mantık)
        if (count < 5) {
          // Kaşif olmaya gidiyor
          message = "Ziyaret Edildi! ($count/5) - Kaşif olmaya ${5 - count} yer kaldı! 🧭";
        } else if (count == 5) {
          // Tam seviye atlama anı
          _showRankUpDialog("Tebrikler! 🎖️", "5. mekanı ziyaret ettin ve 'Kaşif' rütbesini kazandın!");
          message = "Harika! Artık bir Kaşifsin! ($count/20) 🚀";
        } else if (count < 20) {
          // Rota Ustası olmaya gidiyor
          message = "Süper! ($count/20) - Rota Ustası olmaya ${20 - count} yer kaldı! 🏃‍♂️";
        } else if (count == 20) {
          // Büyük seviye atlama anı
          _showRankUpDialog("İnanılmaz! 👑", "20 mekana ulaştın ve 'Rota Ustası' oldun!");
          message = "Zirvedesin! Rota Ustası! ($count) 🏆";
        } else {
          // Zirveden sonrası
          message = "Ziyaret Edildi! Toplam: $count mekan! 🔥";
        }

        // Eğer seviye atlama dialogu açılmadıysa SnackBar göster
        if (count != 5 && count != 20) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating, // Yüzen snackbar daha şık durur
            ),
          );
        }

      } else {
        // Ziyareti Geri Alma Durumu
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ziyaret işareti kaldırıldı ❌"), backgroundColor: Colors.grey),
        );
      }
    }
  }

  // Rütbe atlayınca çıkan Havalı Pencere
  void _showRankUpDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.emoji_events, size: 60, color: Colors.orangeAccent),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          ],
        ),
        content: Text(body, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Harika!", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  void _sharePlace() {
    Share.share('Harika bir yer buldum! 📍 ${currentPlace.title}\nKonum: https://www.google.com/maps/search/?api=1&query=${currentPlace.latitude},${currentPlace.longitude}\n\nGezintoo Uygulaması ile keşfedildi.');
  }

  Future<void> _openMap() async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${currentPlace.latitude},${currentPlace.longitude}');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) { await launchUrl(url, mode: LaunchMode.platformDefault); }
    } catch (e) { debugPrint("Harita hatası: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: 300, child: Container(color: Colors.deepPurple, child: currentPlace.imageName.isNotEmpty ? Image.asset(currentPlace.imageName, fit: BoxFit.cover) : const Center(child: Icon(Icons.location_city, size: 100, color: Colors.white30)))),
        Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)))),
        Positioned(top: 50, right: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.share, color: Colors.blue), onPressed: _sharePlace))),
        Positioned(top: 260, left: 0, right: 0, bottom: 0, child: Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: Column(children: [Expanded(child: ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [Expanded(child: Text(currentPlace.title, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold))), Container(margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(border: Border.all(color: isVisited ? Colors.green : Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(8), color: isVisited ? Colors.green.withOpacity(0.1) : Colors.transparent), child: IconButton(icon: Icon(Icons.check_circle, color: isVisited ? Colors.green : Colors.grey.shade400, size: 28), onPressed: _toggleVisited)), Container(decoration: BoxDecoration(border: Border.all(color: Colors.orangeAccent, width: 2), borderRadius: BorderRadius.circular(8)), child: IconButton(icon: Icon(isLocalFavorite ? Icons.favorite : Icons.favorite_border, color: isLocalFavorite ? Colors.red : Colors.black54, size: 28), onPressed: _toggleFavorite))]),
          Container(margin: const EdgeInsets.symmetric(vertical: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.cloud, color: Colors.blue), const SizedBox(width: 10), Text(currentPlace.weatherInfo ?? "Hava durumu yükleniyor...", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue.shade900))])),
          Text(currentPlace.location), const SizedBox(height: 20), const Text("Hakkında", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(currentPlace.description.isNotEmpty ? currentPlace.description : "Açıklama yok."), const SizedBox(height: 20),
          const Text("Kişisel Notum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 5),
          TextField(controller: _noteController, maxLines: 3, decoration: InputDecoration(hintText: "Bu yer hakkında ne düşünüyorsun?", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: const Icon(Icons.save, color: Colors.blue), onPressed: _saveNote))),
          const SizedBox(height: 20), Container(height: 200, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey)), child: FlutterMap(options: MapOptions(initialCenter: LatLng(currentPlace.latitude, currentPlace.longitude), initialZoom: 15), children: [TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'), MarkerLayer(markers: [Marker(point: LatLng(currentPlace.latitude, currentPlace.longitude), child: const Icon(Icons.location_on, color: Colors.red, size: 40))])]))])), Container(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: _openMap, icon: const Icon(Icons.directions, color: Colors.white), label: const Text("Yol Tarifi Al", style: TextStyle(color: Colors.white, fontSize: 18)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))))]))),
      ]),
    );
  }
}