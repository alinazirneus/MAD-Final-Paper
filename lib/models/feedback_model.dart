class FeedbackModel {
  final int? id;
  final int citizenId;
  final String feedback;
  final String createdAt;

  FeedbackModel({
    this.id,
    required this.citizenId,
    required this.feedback,
    required this.createdAt,
  });

  // Convert a FeedbackModel object into a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'citizenId': citizenId,
      'feedback': feedback,
      'createdAt': createdAt,
    };
  }

  // Extract a FeedbackModel object from a Map.
  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      id: map['id'] as int?,
      citizenId: map['citizenId'] as int,
      feedback: map['feedback'] as String,
      createdAt: map['createdAt'] as String,
    );
  }
}
