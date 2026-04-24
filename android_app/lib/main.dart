import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sensors/services/sensor_state_controller.dart';
import 'package:sensors/services/sensor_api_client.dart';
import 'package:sensors/repositories/host_config_repository.dart';
import 'package:sensors/repositories/user_preferences_repository.dart';
import 'package:sensors/presentation/screens/host_setup_screen.dart';
import 'package:sensors/presentation/screens/sensor_dashboard_screen.dart';
import 'package:sensors/models/models.dart';
import 'package:sensors/ad_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AdConfig.adsEnabled) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      // AdMob init failure should not block app startup.
      debugPrint('AdMob initialization failed: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final SensorStateController _controller;
  late final HostConfigRepository _hostConfigRepository;
  late final UserPreferencesRepository _userPrefs;
  HostConfig? _currentHostConfig;
  bool _isLoadingInitialConfig = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _hostConfigRepository = HostConfigRepository();
    _userPrefs = UserPreferencesRepository();

    _controller = SensorStateController(
      apiClient: SensorApiClient(),
      pollingIntervalMs: SensorApiClient.defaultPollingIntervalMs,
    );

    _loadInitialConfig();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state != AppLifecycleState.resumed ||
        _isLoadingInitialConfig ||
        _currentHostConfig == null) {
      return;
    }

    unawaited(_controller.onAppResumed());
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

  Future<void> _handleClearHostConfig() async {
    await _hostConfigRepository.clearConfig();
    _controller.resetToSetup();

    if (mounted) {
      setState(() {
        _currentHostConfig = null;
      });
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sensors',
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
          onClearHostConfig: _handleClearHostConfig,
          currentUnit: snapshot.data!,
          onUnitChanged: _handleUnitChanged,
        );
      },
    );
  }
}
