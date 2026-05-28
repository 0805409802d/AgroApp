import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/local_db_service.dart';

class OfflineStatusWidget extends StatefulWidget {
  const OfflineStatusWidget({super.key});

  @override
  State<OfflineStatusWidget> createState() => _OfflineStatusWidgetState();
}

class _OfflineStatusWidgetState extends State<OfflineStatusWidget> {
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingCount = 0;
  late StreamSubscription _subscription;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = !results.contains(ConnectivityResult.none);
        });
      }
    });
    
    // Revisar la cola periódicamente
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkQueue();
    });
    _checkQueue();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = !results.contains(ConnectivityResult.none);
      });
    }
  }

  Future<void> _checkQueue() async {
    final pending = await LocalDbService.getPendingMutations();
    if (mounted) {
      setState(() {
        _pendingCount = pending.length;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _manualSync() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conexión a internet para sincronizar.')),
      );
      return;
    }
    
    setState(() => _isSyncing = true);
    await SyncService.syncNow();
    await _checkQueue();
    setState(() => _isSyncing = false);
    
    if (mounted && _pendingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronización completada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSyncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: _isOnline ? (_pendingCount > 0 ? Colors.blue : Colors.green) : Colors.orange,
          ),
          if (_pendingCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  '$_pendingCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: _pendingCount > 0 ? _manualSync : () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isOnline ? 'Conectado a la nube. Todo está sincronizado.' : 'Modo offline. Tus datos se están guardando localmente.')),
        );
      },
    );
  }
}
