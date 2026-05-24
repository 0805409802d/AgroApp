import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/dashboard_alert_model.dart';

class DashboardAlerts extends StatelessWidget {
  final List<DashboardAlertModel> alerts;

  const DashboardAlerts({super.key, required this.alerts});

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
          child: Text(
            '🔔 Alertas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: alerts.map((alert) {
              final bgColor = _parseColor(alert.color).withValues(alpha: 0.1);
              final fgColor = _parseColor(alert.color);
              return GestureDetector(
                onTap: () {
                  if (alert.action != null) {
                    context.push(alert.action!);
                  }
                },
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fgColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getIcon(alert.icon),
                        color: fgColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert.message,
                          style: TextStyle(
                            color: fgColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'person_off':
        return Icons.person_off;
      case 'message':
        return Icons.message;
      case 'trending_down':
        return Icons.trending_down;
      case 'trending_up':
        return Icons.trending_up;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.notifications;
    }
  }
}