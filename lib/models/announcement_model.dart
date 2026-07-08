class Announcement {
  final int? id;
  final String title;
  final String description;
  final String createdAt;

  Announcement({
    this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  // Convert an Announcement object into a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt,
    };
  }

  // Extract an Announcement object from a Map.
  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      createdAt: map['createdAt'] as String,
    );
  }
}
