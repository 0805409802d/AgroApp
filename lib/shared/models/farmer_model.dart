// farmer_model.dart
class FarmerModel {
  final String id;
  final String businessId;
  final String name;
  final String? whatsappNumber;
  final String? folderId;
  final String? lastName;
  final String? email;
  final String? description;

  FarmerModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.whatsappNumber,
    this.folderId,
    this.lastName,
    this.email,
    this.description,
  });

  factory FarmerModel.fromMap(Map<String, dynamic> map) {
    return FarmerModel(
      id: map['id'],
      businessId: map['business_id'],
      name: map['name'],
      whatsappNumber: map['whatsapp_number'],
      folderId: map['folder_id'],
      lastName: map['last_name'],
      email: map['email'],
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'whatsapp_number': whatsappNumber,
      'folder_id': folderId,
      'last_name': lastName,
      'email': email,
      'description': description,
    };
  }
}