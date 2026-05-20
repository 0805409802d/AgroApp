// excel_helper.dart
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/models/purchase_model.dart';
import '../../shared/models/business_model.dart';

class ExcelHelper {
  static Future<void> exportPurchases({
    required List<PurchaseModel> purchases,
    required BusinessModel business,
    required String periodLabel,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Compras'];

    // ── Estilos ───────────────────────────────────────────────
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1B5E20'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    final cancelledStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
      italic: true,
    );

    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
    );

    // ── Encabezado del negocio ────────────────────────────────
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('J1'),
    );
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'Reporte de Compras - ${business.businessName}',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );

    sheet.merge(
      CellIndex.indexByString('A2'),
      CellIndex.indexByString('J2'),
    );
    final periodCell = sheet.cell(CellIndex.indexByString('A2'));
    periodCell.value = TextCellValue('Período: $periodLabel');
    periodCell.cellStyle = CellStyle(
      italic: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Cabeceras de columnas ─────────────────────────────────
    final headers = [
      'Fecha',
      'Hora',
      'Agricultor',
      'WhatsApp',
      'Peso Bruto',
      'Descuento',
      'Peso Neto',
      'Precio/Unidad',
      'Adelanto',
      'Total Pagado',
      'Estado',
      'WhatsApp Enviado',
    ];

    final unit =
        business.weightUnit == 'quintales' ? 'QQ' : 'Lbs';

    // Reemplazar cabeceras con unidad correcta
    final dynamicHeaders = headers.map((h) {
      if (h == 'Peso Bruto' || h == 'Peso Neto') return '$h ($unit)';
      return h;
    }).toList();

    for (var i = 0; i < dynamicHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
      );
      cell.value = TextCellValue(dynamicHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    // ── Filas de datos ────────────────────────────────────────
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    for (var i = 0; i < purchases.length; i++) {
      final p = purchases[i];
      final rowIndex = i + 4;
      final isCancelled = p.status == 'cancelled';

      final rowData = [
        dateFormat.format(p.createdAt.toLocal()),
        timeFormat.format(p.createdAt.toLocal()),
        p.farmerName,
        p.farmerWhatsapp ?? '',
        p.grossWeight,
        p.discountType == 'porcentaje'
            ? '${p.discountValue.toStringAsFixed(1)}%'
            : p.discountValue,
        p.netWeight,
        p.pricePerUnit,
        p.advanceDeducted,
        p.totalPaid,
        isCancelled ? 'ANULADA' : 'Activa',
        p.whatsappSent ? 'Sí' : 'No',
      ];

      for (var j = 0; j < rowData.length; j++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
              columnIndex: j, rowIndex: rowIndex),
        );
        final val = rowData[j];
        if (val is double) {
          cell.value = DoubleCellValue(val);
        } else {
          cell.value = TextCellValue(val.toString());
        }
        if (isCancelled) cell.cellStyle = cancelledStyle;
      }
    }

    // ── Fila de totales ───────────────────────────────────────
    final activePurchases =
        purchases.where((p) => p.status == 'active').toList();
    final totalRow = purchases.length + 4;

    final totalsData = {
      0: 'TOTALES',
      4: activePurchases.fold<double>(
          0, (s, p) => s + p.grossWeight),
      6: activePurchases.fold<double>(
          0, (s, p) => s + p.netWeight),
      8: activePurchases.fold<double>(
          0, (s, p) => s + p.advanceDeducted),
      9: activePurchases.fold<double>(
          0, (s, p) => s + p.totalPaid),
    };

    totalsData.forEach((col, val) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
            columnIndex: col, rowIndex: totalRow),
      );
      if (val is double) {
        cell.value = DoubleCellValue(val);
      } else {
        cell.value = TextCellValue(val.toString());
      }
      cell.cellStyle = totalStyle;
    });

    // ── Ancho de columnas ─────────────────────────────────────
    sheet.setColumnWidth(0, 14); // Fecha
    sheet.setColumnWidth(1, 8);  // Hora
    sheet.setColumnWidth(2, 24); // Agricultor
    sheet.setColumnWidth(3, 16); // WhatsApp
    sheet.setColumnWidth(4, 14); // Peso Bruto
    sheet.setColumnWidth(5, 12); // Descuento
    sheet.setColumnWidth(6, 14); // Peso Neto
    sheet.setColumnWidth(7, 14); // Precio
    sheet.setColumnWidth(8, 12); // Adelanto
    sheet.setColumnWidth(9, 14); // Total
    sheet.setColumnWidth(10, 10); // Estado
    sheet.setColumnWidth(11, 16); // WA Enviado

    // Eliminar hoja default
    excel.delete('Sheet1');

    // ── Guardar y compartir ───────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final fileName =
        'AgroApp_${business.businessName.replaceAll(' ', '_')}_$periodLabel.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Reporte AgroApp - ${business.businessName}',
      text: 'Reporte de compras del período $periodLabel',
    );
  }
}