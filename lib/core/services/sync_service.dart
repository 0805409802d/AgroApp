import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';

class SyncService {
  static final _supabase = Supabase.instance.client;
  static final _connectivity = Connectivity();

  static void initialize() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If we have internet (wifi, mobile, ethernet, etc.), attempt sync
      if (!results.contains(ConnectivityResult.none)) {
        syncNow();
      }
    });
  }

  static Future<void> syncNow() async {
    final mutations = await LocalDbService.getPendingMutations();
    if (mutations.isEmpty) return;

    for (var m in mutations) {
      try {
        final payload = jsonDecode(m.payload);
        
        if (m.action == 'insert') {
          await _supabase.from(m.collectionName).insert(payload);
        } else if (m.action == 'update') {
          await _supabase.from(m.collectionName).update(payload).eq('id', payload['id']);
        } else if (m.action == 'delete') {
          await _supabase.from(m.collectionName).delete().eq('id', payload['id']);
        } else if (m.action == 'rpc') {
          await _supabase.rpc(m.collectionName, params: payload);
        }
        
        // Remove from local queue if successful
        await LocalDbService.removeMutation(m.id);
      } catch (e) {
        // If it fails (e.g. network drops again), keep it in the queue for the next sync.
        print('Error syncing mutation ${m.id}: $e');
      }
    }
  }
}
