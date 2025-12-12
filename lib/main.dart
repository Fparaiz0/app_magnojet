import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'pages/auth/login_page.dart';
import 'pages/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception(
        "Faltam SUPABASE_URL ou SUPABASE_ANON_KEY no arquivo .env.");
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
      home: const InternetCheckWrapper(),
    );
  }
}

class InternetCheckWrapper extends StatefulWidget {
  const InternetCheckWrapper({super.key});

  @override
  State<InternetCheckWrapper> createState() => _InternetCheckWrapperState();
}

class _InternetCheckWrapperState extends State<InternetCheckWrapper> {
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _setupConnectivityListener();
  }

  Future<void> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasInternet = connectivityResult.isNotEmpty &&
        connectivityResult.any((result) => result != ConnectivityResult.none);

    if (mounted) {
      setState(() {
        _hasInternet = hasInternet;
      });
    }
  }

  void _setupConnectivityListener() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasInternet = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (mounted) {
        setState(() {
          _hasInternet = hasInternet;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasInternet) {
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
                  onPressed: _checkInternetConnection,
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
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasInternet = connectivityResult.isNotEmpty &&
        connectivityResult.any((result) => result != ConnectivityResult.none);

    if (!hasInternet && mounted) {
      _showSnackBar('Verifique sua conexão com a internet');
      setState(() => _isLoading = false);
      return;
    }

    final currentSession = supabase.auth.currentSession;
    if (currentSession != null) {
      if (mounted) {
        setState(() {
          _session = currentSession;
          _isLoading = false;
        });
      }
      await _saveUserLocationOnLogin();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }

      if (session != null && !_locationRequested && mounted) {
        await _saveUserLocationOnLogin();
      }
    });
  }

  Future<void> _saveUserLocationOnLogin() async {
    try {
      if (mounted) {
        setState(() {
          _locationRequested = true;
        });
      }

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

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationServiceDisabledAlert();
        }
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      String location = await _getLocationFromCoordinates(
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
      List<Placemark> placemarks = await placemarkFromCoordinates(
        lat,
        lng,
        localeIdentifier: 'pt_BR',
      );

      if (placemarks.isEmpty) {
        return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }

      Placemark place = placemarks.first;
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
      if (mounted) {
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
      }
    });
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session != null) {
      return StreamBuilder<List<ConnectivityResult>>(
        stream: Connectivity().onConnectivityChanged,
        builder: (context, snapshot) {
          final results = snapshot.data ?? [];
          final hasConnection = results.isNotEmpty &&
              results.any((result) => result != ConnectivityResult.none);

          if (!hasConnection) {
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
                        'Conexão perdida',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'O aplicativo requer conexão com a internet para continuar funcionando.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AuthGate(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Recarregar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const HomePage();
        },
      );
    }

    return const LoginPage();
  }
}
