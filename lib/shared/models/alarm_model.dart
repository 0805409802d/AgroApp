class AlarmModel {
  final String id;
  final String businessId;
  final String eventName;
  final String description;
  final DateTime eventTime;
  final bool isActive;
  final DateTime createdAt;

  AlarmModel({
    required this.id,
    required this.businessId,
    required this.eventName,
    required this.description,
    required this.eventTime,
    required this.isActive,
    required this.createdAt,
  });

  factory AlarmModel.fromMap(Map<String, dynamic> map) {
    return AlarmModel(
      id: map['id'],
      businessId: map['business_id'],
      eventName: map['event_name'] ?? '',
      description: map['description'] ?? '',
      eventTime: DateTime.parse(map['event_time']).toLocal(),
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'event_name': eventName,
      'description': description,
      'event_time': eventTime.toUtc().toIso8601String(),
      'is_active': isActive,
    };
  }
}
