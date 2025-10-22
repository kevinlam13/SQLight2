class Folder {
  final int? id;
  final String name;
  final String createdAt;

  Folder({this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt,
  };

  static Folder fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'] as int?,
    name: json['name'] as String,
    createdAt: json['createdAt'] as String,
  );
}
