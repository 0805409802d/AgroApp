// farmer_model.dart
class FarmerModel {
  final String id;
  final String businessId;
  final String name;
  final String? whatsappNumber;

  FarmerModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.whatsappNumber,
  });

  factory FarmerModel.fromMap(Map<String, dynamic> map) {
    return FarmerModel(
      id: map['id'],
      businessId: map['business_id'],
      name: map['name'],
      whatsappNumber: map['whatsapp_number'],
    );
  }
}