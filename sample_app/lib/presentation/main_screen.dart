import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'log_entry.dart';
import 'main_view_model.dart';
import 'ui_action.dart';
import 'ui_state.dart';

const int _primaryValue = 0xFF429488;
const MaterialColor trustPinGreen = MaterialColor(_primaryValue, <int, Color>{
  50: Color(0xFFE2F2EF),
  100: Color(0xFFB6DED7),
  200: Color(0xFF86C9BC),
  300: Color(0xFF56B3A1),
  400: Color(0xFF359F8C),
  500: Color(_primaryValue),
  600: Color(0xFF3C867B),
  700: Color(0xFF35766B),
  800: Color(0xFF2E655B),
  900: Color(0xFF204739),
});

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _organizationIdController = TextEditingController();
  final _projectIdController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _testUrlController = TextEditingController(
    text: 'https://api.trustpin.cloud/health',
  );
  final _logScrollController = ScrollController();

  late final MainViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<MainViewModel>();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    final state = _viewModel.state;

    final message = state.transientMessage;
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

    // Auto-scroll the log feed when new entries arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _organizationIdController.dispose();
    _projectIdController.dispose();
    _publicKeyController.dispose();
    _testUrlController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MainViewModel>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrustPin Sample'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _ConfigurationCard(
                  state: state,
                  organizationIdController: _organizationIdController,
                  projectIdController: _projectIdController,
                  publicKeyController: _publicKeyController,
                ),
                const SizedBox(height: 16),
                _ConnectionCard(
                  state: state,
                  testUrlController: _testUrlController,
                ),
                const SizedBox(height: 16),
                _LogCard(state: state, scrollController: _logScrollController),
              ],
            ),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MainViewModel>();
    final canEditCredentials = !state.isConfigured && !state.isWorking;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TrustPin Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const _DashboardBanner(),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Organization ID',
              controller: organizationIdController,
              hint: 'Enter your organization ID',
              enabled: canEditCredentials,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Project ID',
              controller: projectIdController,
              hint: 'Enter your project ID',
              enabled: canEditCredentials,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Public Key',
              controller: publicKeyController,
              hint: 'Enter your base64 public key',
              enabled: canEditCredentials,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canEditCredentials
                    ? () => viewModel.dispatch(
                        ConfigureAction(
                          organizationId: organizationIdController.text,
                          projectId: projectIdController.text,
                          publicKey: publicKeyController.text,
                        ),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: trustPinGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  state.isConfigured ? 'TrustPin Configured' : 'Setup TrustPin',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: canEditCredentials
                    ? () =>
                          viewModel.dispatch(const ConfigureFromBundleAction())
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: trustPinGreen,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: trustPinGreen),
                ),
                child: const Text('Load from native bundle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBanner extends StatelessWidget {
  const _DashboardBanner();

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
            'Need credentials?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sign in to the TrustPin dashboard to fetch your organization id, '
            'project id, and public key.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
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

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final int maxLines;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.enabled,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
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
    final canRun = state.isConfigured && !state.isWorking;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Testing',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Test URL',
              controller: testUrlController,
              hint: 'https://api.example.com',
              enabled: !state.isWorking,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canRun
                    ? () => viewModel.dispatch(
                        TestConnectionAction(testUrlController.text),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: state.isWorking && state.status == Status.testing
                    ? const _ButtonSpinner()
                    : const Text('Test Connection'),
              ),
            ),
            const SizedBox(height: 16),
            _StatusBanner(state: state),
          ],
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final UiState state;

  const _StatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state.status) {
      Status.notConfigured => (Colors.red, 'TrustPin not configured'),
      Status.configured => (Colors.green, 'TrustPin configured'),
      Status.testing => (Colors.orange, 'Testing connection...'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Status: $label',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final UiState state;
  final ScrollController scrollController;

  const _LogCard({required this.state, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MainViewModel>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Log Output',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => viewModel.dispatch(const ClearLogAction()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: state.logEntries.isEmpty
                  ? const Center(
                      child: Text(
                        'Welcome to TrustPin Flutter Sample\n'
                        'Configure TrustPin and test connections...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: state.logEntries.length,
                      itemBuilder: (context, index) =>
                          _LogLine(entry: state.logEntries[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry entry;

  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '[${entry.timestamp}] ${entry.level.icon} ${entry.message}',
        style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
      ),
    );
  }
}
