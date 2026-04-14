import 'package:flutter/material.dart';
import 'package:android_app/repositories/host_config_repository.dart';
import 'package:android_app/models/host_config.dart';

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
        _hostUrlController.text = config.ipAddress;
      });
    }
  }

  bool _isValidHostUrl(String url) {
    // Basic URL validation - must start with http:// or https://
    final regex = RegExp(r'^https?://');
    return regex.hasMatch(url) && url.length > 7;
  }

  Future<void> _saveHostConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hostUrl = _hostUrlController.text.trim();

    if (!_isValidHostUrl(hostUrl)) {
      setState(() {
        _errorMessage =
            'Please enter a valid host URL (e.g., http://localhost:5000/api/v1/sensors)';
      });
      return;
    }

    try {
      final config = HostConfig(
        hostId: 'single-host',
        hostname: 'Host',
        ipAddress: hostUrl,
        displayName: 'My Host',
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
                  'Enter the URL of your host sensor API endpoint',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _hostUrlController,
                  decoration: InputDecoration(
                    labelText: 'Host API URL',
                    hintText: 'http://localhost:5000/api/v1/sensors',
                    helperText: 'Include the full path to /api/v1/sensors',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                    errorText: _errorMessage,
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _saveHostConfig(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a host URL';
                    }
                    if (!_isValidHostUrl(value.trim())) {
                      return 'Please enter a valid URL (http:// or https://)';
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
