import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  ConnectivityService() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      // Mapeia o resultado para um booleano simples: está conectado ou não?
      final isConnected = result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi);
      _connectionStatusController.add(isConnected);
    });
  }

  // Função para verificar o status inicial da conexão
  Future<bool> isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
