import 'package:flutter/material.dart';
import 'package:android_app/services/sensor_state_controller.dart';
import 'package:android_app/services/sensor_api_client.dart';
import 'package:android_app/repositories/host_config_repository.dart';
import 'package:android_app/repositories/user_preferences_repository.dart';
import 'package:android_app/presentation/screens/host_setup_screen.dart';
import 'package:android_app/presentation/screens/sensor_dashboard_screen.dart';
import 'package:android_app/models/models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SensorStateController _controller;
  late final HostConfigRepository _hostConfigRepository;
  late final UserPreferencesRepository _userPrefs;
  HostConfig? _currentHostConfig;
  bool _isLoadingInitialConfig = true;

  @override
  void initState() {
    super.initState();
    _hostConfigRepository = HostConfigRepository();
    _userPrefs = UserPreferencesRepository();

    _controller = SensorStateController(
      apiClient: SensorApiClient(),
      pollingIntervalMs: SensorApiClient.defaultPollingIntervalMs,
    );

    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    final config = await _hostConfigRepository.loadConfig();
    setState(() {
      _currentHostConfig = config;
      _isLoadingInitialConfig = false;
    });

    if (config != null) {
      // Start polling if host is configured
      _controller.setHostConfig(config.ipAddress);
    } else {
      _controller.resetToSetup();
    }
  }

  Future<void> _handleHostSaved(HostConfig config) async {
    setState(() {
      _currentHostConfig = config;
    });

    // Start polling immediately after saving config
    _controller.setHostConfig(config.ipAddress);
  }

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
    } catch (e) {
      // Error is handled by the controller
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Refresh failed')));
      }
    }
  }

  Future<void> _handleRetry() async {
    if (_currentHostConfig != null) {
      await _controller.setHostConfig(_currentHostConfig!.ipAddress);
    }
  }

  Future<void> _handleUnitChanged(TemperatureUnit newUnit) async {
    await _userPrefs.setTemperatureUnit(newUnit);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cockpit Sensors',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: _buildHomePage(),
    );
  }

  Widget _buildHomePage() {
    if (_isLoadingInitialConfig) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no host configured, show setup screen
    if (_currentHostConfig == null) {
      return HostSetupScreen(
        repository: _hostConfigRepository,
        onHostSaved: _handleHostSaved,
      );
    }

    // Otherwise show dashboard with unit preference
    return _buildDashboard();
  }

  Widget _buildDashboard() {
    return FutureBuilder<TemperatureUnit>(
      future: _userPrefs.getTemperatureUnit(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return SensorDashboardScreen(
          controller: _controller,
          onRefresh: _handleRefresh,
          onRetry: _handleRetry,
          currentUnit: snapshot.data!,
          onUnitChanged: _handleUnitChanged,
        );
      },
    );
  }
}
