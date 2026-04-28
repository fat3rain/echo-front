class RoomSummary {
  RoomSummary({required this.id, required this.name, required this.createdBy});

  final String id;
  final String name;
  final String createdBy;

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    return RoomSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['createdBy'] as String? ?? '',
    );
  }
}
