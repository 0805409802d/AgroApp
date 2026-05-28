import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/offline_models.dart';

class LocalDbService {
  static late Isar isar;

  static Future<void> initialize() async {
    if (kIsWeb) return; // En la web no usamos base de datos local

    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      isar = await Isar.open(
        [
          OfflineMutationSchema,
          LocalFarmerSchema,
          LocalBusinessConfigSchema,
          LocalFolderSchema,
          LocalDocumentSchema,
        ],
        directory: dir.path,
      );
    } else {
      isar = Isar.getInstance()!;
    }
  }

  // --- Farmers ---
  static Future<void> cacheFarmers(List<LocalFarmer> farmers) async {
    if (kIsWeb) return;
    await isar.writeTxn(() async {
      await isar.localFarmers.putAll(farmers);
    });
  }

  static Future<List<LocalFarmer>> getFarmers(String businessId) async {
    if (kIsWeb) return [];
    return await isar.localFarmers.filter().businessIdEqualTo(businessId).findAll();
  }

  // --- Offline Queue ---
  static Future<void> enqueueMutation(OfflineMutation mutation) async {
    if (kIsWeb) return;
    await isar.writeTxn(() async {
      await isar.offlineMutations.put(mutation);
    });
  }

  static Future<List<OfflineMutation>> getPendingMutations() async {
    if (kIsWeb) return [];
    return await isar.offlineMutations.where().sortByCreatedAt().findAll();
  }

  static Future<void> removeMutation(int id) async {
    if (kIsWeb) return;
    await isar.writeTxn(() async {
      await isar.offlineMutations.delete(id);
    });
  }
  
  // --- Config ---
  static Future<void> saveConfig(LocalBusinessConfig config) async {
    if (kIsWeb) return;
    await isar.writeTxn(() async {
      await isar.localBusinessConfigs.put(config);
    });
  }
  
  static Future<LocalBusinessConfig?> getConfig(String businessId) async {
    if (kIsWeb) return null;
    return await isar.localBusinessConfigs.filter().businessIdEqualTo(businessId).findFirst();
  }
}
