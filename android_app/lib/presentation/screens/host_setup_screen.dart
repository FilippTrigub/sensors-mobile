import 'package:flutter/material.dart';
import 'package:sensors/repositories/host_config_repository.dart';
import 'package:sensors/models/host_config.dart';

/// Host Setup Screen - allows user to enter and save a single host URL.
///
/// This is a stateless screen that delegates persistence to the provided
/// [HostConfigRepository]. On save, it creates a [HostConfig] with the
/// entered URL and navigates away (typically to the dashboard).
class HostSetupScreen extends StatefulWidget {
  /// Repository for persisting host configuration
  final HostConfigRepository repository;

  /// Callback when host is successfully saved (optional)
  final void Function(HostConfig config)? onHostSaved;

  const HostSetupScreen({
    super.key,
    required this.repository,
    this.onHostSaved,
  });

  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostUrlController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hostUrlController = TextEditingController();
    _loadExistingConfig();
  }

  @override
  void dispose() {
    _hostUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    final config = await widget.repository.loadConfig();
    if (config != null) {
      setState(() {
        _hostUrlController.text = _extractHostInput(config.ipAddress);
      });
    }
  }

  String _extractHostInput(String storedValue) {
    final trimmed = storedValue.trim();
    final uri = Uri.tryParse(trimmed);

    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    }

    return trimmed;
  }

  bool _isValidHostInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (trimmed.contains('://') ||
        trimmed.contains('/') ||
        trimmed.contains('?') ||
        trimmed.contains('#') ||
        RegExp(r'\s').hasMatch(trimmed)) {
      return false;
    }

    final uri = Uri.tryParse('http://$trimmed');
    return uri != null && uri.host.isNotEmpty;
  }

  Future<void> _saveHostConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hostInput = _hostUrlController.text.trim();

    if (!_isValidHostInput(hostInput)) {
      setState(() {
        _errorMessage =
            'Enter only the host or host:port (for example 100.64.0.2 or 100.64.0.2:5000).';
      });
      return;
    }

    try {
      final config = HostConfig(
        hostId: hostInput,
        hostname: hostInput,
        ipAddress: hostInput,
        displayName: hostInput,
      );

      await widget.repository.saveConfig(config);

      if (mounted) {
        widget.onHostSaved?.call(config);
        // Navigate away - typically to dashboard
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(config);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save host configuration: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.cloud_outlined, size: 64.0, color: Colors.blue[700]),
                const SizedBox(height: 24),
                Text(
                  'Connect to Your Host',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the host IP or hostname. The app will try HTTPS and HTTP automatically.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _hostUrlController,
                  decoration: InputDecoration(
                    labelText: 'Host IP or hostname',
                    hintText: '100.64.0.2 or 100.64.0.2:5000',
                    helperText:
                        'Only enter the host. The app adds port 5000 and /api/v1/sensors.',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.dns),
                    errorText: _errorMessage,
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                  onFieldSubmitted: (_) => _saveHostConfig(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a host IP or hostname';
                    }
                    if (!_isValidHostInput(value.trim())) {
                      return 'Enter only the host or host:port';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_outlined,
                          size: 64,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saveHostConfig,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save & Continue',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
