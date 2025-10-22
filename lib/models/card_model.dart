class CardModel {
  final int? id;
  final String name;     // e.g. A, 2..10, J, Q, K
  final String suit;     // Hearts, Spades, Diamonds, Clubs
  final String? imageUrl;
  final int folderId;

  CardModel({
    this.id,
    required this.name,
    required this.suit,
    required this.folderId,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'suit': suit,
    'imageUrl': imageUrl,
    'folderId': folderId,
  };

  static CardModel fromJson(Map<String, dynamic> json) => CardModel(
    id: json['id'] as int?,
    name: json['name'] as String,
    suit: json['suit'] as String,
    imageUrl: json['imageUrl'] as String?,
    folderId: json['folderId'] as int,
  );
}
