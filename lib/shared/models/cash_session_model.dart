class CashSessionModel {
  final String id;
  final String businessId;
  final double openingBalance;
  final double? closingBalance;
  final double totalPurchases;
  final double totalAdvancesGiven;
  final double totalAdvancesDeducted;
  final String? notes;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status; // 'open' | 'closed'

  CashSessionModel({
    required this.id,
    required this.businessId,
    required this.openingBalance,
    this.closingBalance,
    required this.totalPurchases,
    required this.totalAdvancesGiven,
    required this.totalAdvancesDeducted,
    this.notes,
    required this.openedAt,
    this.closedAt,
    required this.status,
  });

  factory CashSessionModel.fromMap(Map<String, dynamic> map) {
    return CashSessionModel(
      id: map['id'],
      businessId: map['business_id'],
      openingBalance: (map['opening_balance'] as num).toDouble(),
      closingBalance: map['closing_balance'] != null
          ? (map['closing_balance'] as num).toDouble()
          : null,
      totalPurchases: (map['total_purchases'] as num?)?.toDouble() ?? 0,
      totalAdvancesGiven:
          (map['total_advances_given'] as num?)?.toDouble() ?? 0,
      totalAdvancesDeducted:
          (map['total_advances_deducted'] as num?)?.toDouble() ?? 0,
      notes: map['notes'],
      openedAt: DateTime.parse(map['opened_at']),
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'])
          : null,
      status: map['status'],
    );
  }

  // Saldo esperado = apertura - compras - adelantos dados + adelantos descontados
  double get expectedBalance =>
      openingBalance - totalPurchases - totalAdvancesGiven + totalAdvancesDeducted;
}