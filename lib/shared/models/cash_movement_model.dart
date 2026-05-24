class CashMovementModel {
  final String id;
  final String cashSessionId;
  final String type; // 'purchase', 'advance', 'expense', 'deposit'
  final double amount;
  final String? description;
  final DateTime createdAt;

  CashMovementModel({
    required this.id,
    required this.cashSessionId,
    required this.type,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  factory CashMovementModel.fromMap(Map<String, dynamic> map) {
    return CashMovementModel(
      id: map['id'],
      cashSessionId: map['cash_session_id'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      description: map['description'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}