class Place {
  final int id;
  final String title;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final String category;
  final String imagePath;
  final int isLiked;
  final int isVisited;
  final double distance;
  final double rating;
  final String userNote;
  final int stepOrder;
  final String? googlePlaceId; // 🔴 YENİ EKLENEN KRİTİK ALAN

  Place({
    this.id = 0,
    required this.title,
    this.description = '',
    this.location = '',
    required this.latitude,
    required this.longitude,
    required this.category,
    this.imagePath = '',
    this.isLiked = 0,
    this.isVisited = 0,
    this.distance = 0.0,
    this.rating = 0.0,
    this.userNote = '',
    this.stepOrder = 0,
    this.googlePlaceId, // Constructor'a eklendi
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    // 🛡️ Yardımcı: Sayıları güvenli çevir (String gelse bile Double yap)
    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // 🛡️ Yardımcı: Tam sayıları güvenli çevir (String gelse bile Int yap)
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Place(
      id: toInt(json['id']),
      title: json['title']?.toString() ?? 'İsimsiz Mekan',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      category: json['category']?.toString() ?? 'genel',
      
      // 🛡️ Resim yolu kontrolü
      imagePath: json['image_path']?.toString() ?? json['imagePath']?.toString() ?? '',
      
      isLiked: toInt(json['is_liked']),
      isVisited: toInt(json['is_visited']),
      distance: toDouble(json['distance']),
      rating: toDouble(json['rating']),
      userNote: json['user_note']?.toString() ?? '',
      stepOrder: toInt(json['step_order']),
      
      // 🔴 Python'dan gelen "google_place_id"yi buraya alıyoruz
      googlePlaceId: json['google_place_id']?.toString(), 
    );
  }

  @override
  String toString() {
    return 'Place(title: $title, step: $stepOrder, lat: $latitude, googleId: $googlePlaceId)';
  }
}