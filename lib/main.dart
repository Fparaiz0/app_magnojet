import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:magnojet/pages/auth/login_page.dart';
import 'package:magnojet/pages/home/home_page.dart';
import 'package:magnojet/services/notification_permission_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationPermissionService().initialize();

  await initializeDateFormatting('pt_BR');

  await dotenv.load();

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception(
        'Faltam SUPABASE_URL ou SUPABASE_ANON_KEY no arquivo .env.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MagnoJet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const MainApp(),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final Connectivity _connectivity = Connectivity();
  bool _hasInternet = false;
  bool _initialized = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);

      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
      );
    } catch (_) {}
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final bool isConnected = result.isNotEmpty &&
        result.any((element) => element != ConnectivityResult.none);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _hasInternet = isConnected;
          _initialized = true;
        });
      }
    });
  }

  Future<void> _checkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
    } catch (_) {}
  }

  Widget _buildNoInternetScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              const Text(
                'Sem conexão com a internet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Este aplicativo requer conexão com a internet para funcionar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Verificando conexão...'),
            ],
          ),
        ),
      );
    }

    if (!_hasInternet) {
      return _buildNoInternetScreen();
    }

    return const AuthGate();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Session? _session;
  bool _locationRequested = false;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    final currentSession = supabase.auth.currentSession;

    setState(() {
      _session = currentSession;
      _isLoading = false;
    });

    if (currentSession != null) {
      await _saveUserLocationOnLogin();
    }

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      setState(() {
        _session = session;
      });

      if (session != null && !_locationRequested) {
        await _saveUserLocationOnLogin();
      }
    });
  }

  Future<void> _saveUserLocationOnLogin() async {
    try {
      setState(() {
        _locationRequested = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userData = await supabase
          .from('users')
          .select('location')
          .eq('id', user.id)
          .maybeSingle();

      if (userData != null && userData['location'] != null) {
        return;
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDisabledAlert();
        await _saveDefaultLocation(user.id);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          await _saveDefaultLocation(user.id);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await _saveDefaultLocation(user.id);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final String location = await _getLocationFromCoordinates(
        position.latitude,
        position.longitude,
      );

      await supabase
          .from('users')
          .update({'location': location}).eq('id', user.id);
    } catch (e) {
      final user = supabase.auth.currentUser;
      if (user != null) {
        await _saveDefaultLocation(user.id);
      }
    }
  }

  Future<String> _getLocationFromCoordinates(double lat, double lng) async {
    try {
      await setLocaleIdentifier('pt_BR');

      final List<Placemark> placemarks = await placemarkFromCoordinates(
        lat,
        lng,
      );

      if (placemarks.isEmpty) {
        return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }

      final Placemark place = placemarks.first;
      String location = '';

      if (place.subAdministrativeArea != null &&
          place.subAdministrativeArea!.isNotEmpty) {
        location = place.subAdministrativeArea!;
      } else if (place.locality != null && place.locality!.isNotEmpty) {
        location = place.locality!;
      } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        location = place.subLocality!;
      }

      if (place.administrativeArea != null &&
          place.administrativeArea!.isNotEmpty) {
        if (location.isNotEmpty) {
          location += ' - ${place.administrativeArea!}';
        } else {
          location = place.administrativeArea!;
        }
      }

      if (location.isEmpty) {
        if (place.country != null && place.country!.isNotEmpty) {
          location = place.country!;
        } else {
          location = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        }
      }

      return location;
    } catch (e) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }

  Future<void> _saveDefaultLocation(String userId) async {
    try {
      await supabase
          .from('users')
          .update({'location': 'Localização não disponível'}).eq('id', userId);
    } catch (_) {}
  }

  void _showLocationServiceDisabledAlert() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Localização Desabilitada'),
          content: const Text(
            'O serviço de localização está desabilitado. '
            'Você pode habilitá-lo nas configurações do dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.pop(context);
              },
              child: const Text('Abrir Configurações'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _session != null ? const HomePage() : const LoginPage();
  }
}
