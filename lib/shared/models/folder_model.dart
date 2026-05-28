class FolderModel {
  final String id;
  final String businessId;
  final String? parentId;
  final String name;
  final String contentType;
  final DateTime createdAt;

  FolderModel({
    required this.id,
    required this.businessId,
    this.parentId,
    required this.name,
    required this.contentType,
    required this.createdAt,
  });

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'],
      businessId: map['business_id'],
      parentId: map['parent_id'],
      name: map['name'],
      contentType: map['content_type'] ?? 'none',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'parent_id': parentId,
      'name': name,
      'content_type': contentType,
      // created_at usually set by Supabase default
    };
  }
}
