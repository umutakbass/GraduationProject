class Place {
  final int? id;
  final String title;
  final String description;
  final String location;
  final String imageName;
  final double latitude;  // Harita için
  final double longitude; // Harita için
  int isLiked; // 0: Hayır, 1: Evet

  Place({
    this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.imageName,
    required this.latitude,
    required this.longitude,
    this.isLiked = 0,
  });

  // Veritabanından okumak için
  factory Place.fromMap(Map<String, dynamic> json) => Place(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        location: json['location'],
        imageName: json['imageName'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        isLiked: json['isLiked'],
      );

  // Veritabanına yazmak için
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'imageName': imageName,
      'latitude': latitude,
      'longitude': longitude,
      'isLiked': isLiked,
    };
  }
}