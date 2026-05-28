class DocumentModel {
  final String id;
  final String businessId;
  final String folderId;
  final String name;
  final String fileUrl;
  final String? fileType;
  final int? sizeBytes;
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.businessId,
    required this.folderId,
    required this.name,
    required this.fileUrl,
    this.fileType,
    this.sizeBytes,
    required this.createdAt,
  });

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'],
      businessId: map['business_id'],
      folderId: map['folder_id'],
      name: map['name'],
      fileUrl: map['file_url'],
      fileType: map['file_type'],
      sizeBytes: map['size_bytes'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'folder_id': folderId,
      'name': name,
      'file_url': fileUrl,
      'file_type': fileType,
      'size_bytes': sizeBytes,
    };
  }
}
