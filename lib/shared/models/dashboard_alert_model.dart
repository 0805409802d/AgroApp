class DashboardAlertModel {
  final String type;
  final String message;
  final String icon;
  final String color; // en formato '#RRGGBB'
  final String? action; // ruta opcional

  DashboardAlertModel({
    required this.type,
    required this.message,
    required this.icon,
    required this.color,
    this.action,
  });

  factory DashboardAlertModel.fromMap(Map<String, dynamic> map) {
    return DashboardAlertModel(
      type: map['type'] as String,
      message: map['message'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      action: map['action'] as String?,
    );
  }
}