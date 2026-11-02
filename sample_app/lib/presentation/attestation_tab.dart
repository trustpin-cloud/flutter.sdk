import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'attestation_view_model.dart';
import 'main_view_model.dart';
import 'shared_widgets.dart';

/// The Attestation tab, as in the native samples: the SDK state, the last
/// protected call, the four actions and the attestation log.
class AttestationTab extends StatelessWidget {
  const AttestationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pinning = context.watch<MainViewModel>().state;
    final viewModel = context.watch<AttestationViewModel>();
    final state = viewModel.state;
    final caption = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]);
    final canAct = state.isConfigured && !state.isBusy;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          StatusHeader(status: pinning.status),
          const SizedBox(height: 16),
          SectionCard(
            title: 'App Attestation',
            children: [
              Row(
                children: [
                  StatusDot(
                    color: state.status.isReady ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.status.label)),
                ],
              ),
              if (state.lastOutcome case final outcome?) ...[
                const SizedBox(height: 12),
                Text(
                  outcome.headline,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (outcome.attestationSummary case final summary?)
                  Text('API attestation: $summary', style: caption),
                if (outcome.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Reply:', style: caption),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        outcome.body,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              WideButton(
                label: 'Set Up Attestation',
                onPressed:
                    pinning.isConfigured && !state.isConfigured && !state.isBusy
                    ? viewModel.setUp
                    : null,
              ),
              const SizedBox(height: 8),
              WideButton(
                label: 'Call Protected Endpoint',
                busy: state.isBusy && state.isConfigured,
                onPressed: canAct ? viewModel.callProtectedEndpoint : null,
              ),
              const SizedBox(height: 8),
              WideButton(
                label: 'Sensitive Call (Token + Assertion)',
                onPressed: canAct ? viewModel.callSensitiveEndpoint : null,
              ),
              const SizedBox(height: 8),
              WideButton(
                label: 'Sign Out (New Session)',
                color: trustPinGreen.withValues(alpha: 0.75),
                onPressed: canAct ? viewModel.signOut : null,
              ),
              const SizedBox(height: 8),
              WideButton(
                label: 'Reset Attestation',
                color: Colors.red.withValues(alpha: 0.85),
                onPressed: canAct ? viewModel.reset : null,
              ),
              const SizedBox(height: 12),
              Text(
                pinning.isConfigured
                    ? 'Requires the App Attest entitlement (iOS, macOS) and '
                          'the sample verifier policy; on simulators and '
                          'emulators run with '
                          '--dart-define=TRUSTPIN_DEBUG_TOKEN=<token>.'
                    : 'Configure pinning first: verifier calls are pinned by '
                          'the TrustPin instance.',
                style: caption,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LogPanel(
            title: 'Attestation Log',
            entries: state.logEntries,
            onClear: viewModel.clearLog,
          ),
        ],
      ),
    );
  }
}
