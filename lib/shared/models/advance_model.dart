class AdvanceModel {
  final String id;
  final String businessId;
  final String farmerId;
  final double amount;
  final double remaining;
  final String status;
  final String? notes;
  final DateTime createdAt;

  AdvanceModel({
    required this.id,
    required this.businessId,
    required this.farmerId,
    required this.amount,
    required this.remaining,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory AdvanceModel.fromMap(Map<String, dynamic> map) {
    return AdvanceModel(
      id: map['id'],
      businessId: map['business_id'],
      farmerId: map['farmer_id'],
      amount: (map['amount'] as num).toDouble(),
      remaining: (map['remaining'] as num).toDouble(),
      status: map['status'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  bool get isPending => status == 'active' && remaining > 0;
}