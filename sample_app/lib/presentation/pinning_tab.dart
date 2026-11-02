import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'main_view_model.dart';
import 'shared_widgets.dart';
import 'ui_action.dart';
import 'ui_state.dart';

/// The Pinning tab: configuration, connection testing and the pinning log,
/// as in the native samples.
class PinningTab extends StatefulWidget {
  const PinningTab({super.key});

  @override
  State<PinningTab> createState() => _PinningTabState();
}

class _PinningTabState extends State<PinningTab> {
  final _organizationIdController = TextEditingController();
  final _projectIdController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _testUrlController = TextEditingController(
    text: 'https://cdn.trustpin.cloud/health.json',
  );

  late final MainViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<MainViewModel>();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    final message = _viewModel.state.transientMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      _viewModel.dispatch(const ConsumeTransientMessageAction());
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _organizationIdController.dispose();
    _projectIdController.dispose();
    _publicKeyController.dispose();
    _testUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MainViewModel>().state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          StatusHeader(status: state.status),
          const SizedBox(height: 16),
          _ConfigurationCard(
            state: state,
            organizationIdController: _organizationIdController,
            projectIdController: _projectIdController,
            publicKeyController: _publicKeyController,
          ),
          const SizedBox(height: 16),
          _ConnectionCard(state: state, testUrlController: _testUrlController),
          const SizedBox(height: 16),
          LogPanel(
            title: 'Pinning Log',
            entries: state.logEntries,
            onClear: () => _viewModel.dispatch(const ClearLogAction()),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationCard extends StatelessWidget {
  final UiState state;
  final TextEditingController organizationIdController;
  final TextEditingController projectIdController;
  final TextEditingController publicKeyController;

  const _ConfigurationCard({
    required this.state,
    required this.organizationIdController,
    required this.projectIdController,
    required this.publicKeyController,
  });

  /// The native configuration file this platform reads.
  static String get _bundleFileName =>
      defaultTargetPlatform == TargetPlatform.android
      ? 'trustpin.json'
      : 'TrustPin-Info.plist';

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MainViewModel>();
    final canEditCredentials = !state.isConfigured && !state.isWorking;

    return SectionCard(
      title: 'TrustPin Configuration',
      children: [
        const _CredentialsBanner(),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Organization ID',
          controller: organizationIdController,
          hint: 'Enter your organization ID',
          enabled: canEditCredentials,
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Project ID',
          controller: projectIdController,
          hint: 'Enter your project ID',
          enabled: canEditCredentials,
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Public Key',
          controller: publicKeyController,
          hint: 'Enter your base64 public key',
          enabled: canEditCredentials,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        WideButton(
          label: state.isConfigured
              ? '✓ TrustPin Configured'
              : 'Setup TrustPin',
          color: state.isConfigured ? Colors.green : trustPinGreen,
          onPressed: canEditCredentials
              ? () => viewModel.dispatch(
                  ConfigureAction(
                    organizationId: organizationIdController.text,
                    projectId: projectIdController.text,
                    publicKey: publicKeyController.text,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: canEditCredentials
                ? () => viewModel.dispatch(const ConfigureFromBundleAction())
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: trustPinGreen,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: trustPinGreen),
            ),
            child: Text('Setup from $_bundleFileName'),
          ),
        ),
        const SizedBox(height: 16),
        const _PinningModeRow(),
      ],
    );
  }
}

class _CredentialsBanner extends StatelessWidget {
  const _CredentialsBanner();

  Future<void> _copyUrl(BuildContext context) async {
    const url = 'https://app.trustpin.cloud';
    await Clipboard.setData(const ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Dashboard URL copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: trustPinGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bring your own credentials',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            "This sample doesn't ship with a working project. Create one for "
            'free at:',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _copyUrl(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'app.trustpin.cloud (tap to copy)',
                style: TextStyle(
                  color: trustPinGreen,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sample always pins in strict mode; the row explains how to change it.
class _PinningModeRow extends StatelessWidget {
  const _PinningModeRow();

  void _explain(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Pinning Mode'),
        content: const Text(
          "To change the pinning mode, set 'Mode' in TrustPin-Info.plist, "
          "'mode' in trustpin.json, or the mode in ConfigureAction:\n\n"
          '• strict for production (blocks unregistered domains)\n'
          '• permissive for development (allows unregistered domains)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]);
    return InkWell(
      onTap: () => _explain(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pinning Mode', style: caption),
          const Row(
            children: [
              Text('Strict Mode'),
              Spacer(),
              Switch(value: true, onChanged: null),
            ],
          ),
          Text('Blocks connections to unregistered domains', style: caption),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final UiState state;
  final TextEditingController testUrlController;

  const _ConnectionCard({required this.state, required this.testUrlController});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MainViewModel>();
    final caption = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]);

    return SectionCard(
      title: 'Connection Testing',
      children: [
        LabeledField(
          label: 'Test URL (GET)',
          controller: testUrlController,
          hint: 'https://api.example.com',
          enabled: !state.isWorking,
        ),
        const SizedBox(height: 6),
        Text(
          'Use a URL covered by the pinning configuration you set up above.',
          style: caption,
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: testUrlController,
          builder: (context, _) => WideButton(
            label: 'Test Connection',
            busy: state.isWorking && state.status == Status.testing,
            onPressed:
                state.isConfigured &&
                    !state.isWorking &&
                    testUrlController.text.trim().isNotEmpty
                ? () => viewModel.dispatch(
                    TestConnectionAction(testUrlController.text),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        WideButton(
          label: 'Fetch Certificate',
          busy: state.isWorking && state.status == Status.fetching,
          onPressed: state.isWorking
              ? null
              : () => viewModel.dispatch(
                  FetchCertificateAction(testUrlController.text),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => viewModel.dispatch(const ClearLogAction()),
            style: OutlinedButton.styleFrom(
              foregroundColor: trustPinGreen,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear Log'),
          ),
        ),
      ],
    );
  }
}
