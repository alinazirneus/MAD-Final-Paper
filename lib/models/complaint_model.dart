class Complaint {
  final int? id;
  final int citizenId;
  final String title;
  final String description;
  final String category;
  final String location;
  final String? imagePath;
  final String status; // e.g., 'Pending', 'In Progress', 'Resolved'
  final String createdAt;

  Complaint({
    this.id,
    required this.citizenId,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    this.imagePath,
    this.status = 'Pending',
    required this.createdAt,
  });

  // Convert a Complaint object into a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'citizenId': citizenId,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'imagePath': imagePath,
      'status': status,
      'createdAt': createdAt,
    };
  }

  // Extract a Complaint object from a Map.
  factory Complaint.fromMap(Map<String, dynamic> map) {
    return Complaint(
      id: map['id'] as int?,
      citizenId: map['citizenId'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      location: map['location'] as String,
      imagePath: map['imagePath'] as String?,
      status: map['status'] as String? ?? 'Pending',
      createdAt: map['createdAt'] as String,
    );
  }
}
