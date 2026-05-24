// excel_helper_mobile.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void downloadFileWeb(List<int> bytes, String fileName) {
  // No-op on mobile
}

Future<void> saveAndShareMobile(
  List<int> bytes,
  String fileName,
  String businessName,
  String periodLabel,
) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Reporte AgroApp - $businessName',
    text: 'Reporte de compras del período $periodLabel',
  );
}
