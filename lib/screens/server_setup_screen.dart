import 'package:flutter/material.dart';

import '../config/app_config_controller.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key, required this.controller});

  final AppConfigController controller;

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  late final TextEditingController _urlController;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.controller.state.serverUrl ?? '',
    );
  }

  @override
  void didUpdateWidget(ServerSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        widget.controller.state.serverUrl != null) {
      _urlController.text = widget.controller.state.serverUrl!;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _localError = null;
    });

    try {
      await widget.controller.saveServerUrl(_urlController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localError = widget.controller.state.error ?? error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final isSaving =
        state.status == AppConfigStatus.loading && state.serverUrl != null;
    final errorText =
        _localError ??
        (state.status == AppConfigStatus.error ? state.error : null);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Connect to Mikudrome',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _urlController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.1.10:8080',
                      errorText: errorText,
                    ),
                    onSubmitted: isSaving ? null : (_) => _save(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving ? null : _save,
                    child: isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
