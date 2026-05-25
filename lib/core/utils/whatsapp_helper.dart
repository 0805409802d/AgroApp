// whatsapp_helper.dart
import 'package:url_launcher/url_launcher.dart';
import '../../shared/models/business_model.dart';
import '../../shared/models/purchase_model.dart';
import 'package:intl/intl.dart';

class WhatsAppHelper {
  static String buildReceiptMessage({
    required BusinessModel business,
    required PurchaseModel purchase,
  }) {
    final unit = purchase.weightUnit == 'quintales' ? 'QQ' : 'Lbs';
    final date = DateFormat('dd/MM/yyyy').format(purchase.createdAt);
    final discountLabel = purchase.discountType == 'porcentaje'
        ? '${purchase.discountValue.toStringAsFixed(1)}%'
        : '${purchase.discountValue.toStringAsFixed(2)} $unit';
    // Capitaliza la primera letra del tipo de producto
    final productName = business.productType[0].toUpperCase() +
        business.productType.substring(1);

    return '''
📄 *RECIBO DE COMPRA - ${business.businessName}*
👤 Cliente: ${purchase.farmerName}
📅 Fecha: $date

⚖️ Peso Bruto: ${purchase.grossWeight.toStringAsFixed(2)} $unit
💧 Merma/Descuento: - $discountLabel
✅ Peso Neto: ${purchase.netWeight.toStringAsFixed(2)} $unit — $productName
💵 Precio del día: \$${purchase.pricePerUnit.toStringAsFixed(2)}
${purchase.advanceDeducted > 0 ? '💳 Adelanto descontado: -\$${purchase.advanceDeducted.toStringAsFixed(2)}\n' : ''}
💰 *TOTAL PAGADO: \$${purchase.totalPaid.toStringAsFixed(2)}*

_¡Gracias por su confianza!_ 🌱''';
  }

  static Future<void> sendReceipt({
    required String phoneNumber,
    required String message,
  }) async {
    // Limpiamos el número: solo dígitos
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Si es un número de 10 dígitos que empieza con 0 (Ecuador), agregamos el código de país 593
    if (cleaned.length == 10 && cleaned.startsWith('0')) {
      cleaned = '593${cleaned.substring(1)}';
    }

    final encoded = Uri.encodeComponent(message);
    
    // Intentar abrir la app nativa primero
    final appUrl = 'whatsapp://send?phone=$cleaned&text=$encoded';
    final webUrl = 'https://wa.me/$cleaned?text=$encoded';

    try {
      final launched = await launchUrl(Uri.parse(appUrl));
      if (!launched) {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Si falla porque el SO bloquea el scheme, usamos el fallback de wa.me
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }
}