// On-device check of the attestation bridge: every TrustPinAttest call
// crosses the platform channel and the native SDK answers. Needs the sample's
// native configuration files and assets/api-test.json.
//
//   flutter test integration_test/attestation_bridge_test.dart -d <device>
//
// A simulator or emulator without a debug token can't attest; the test then
// checks that the failure surfaces as a state, not a crash. With a token
// (--dart-define=TRUSTPIN_DEBUG_TOKEN=…) and a policy and verifier that allow
// debug tokens, it reaches a ready token.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trustpin_attest/trustpin_attest.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

const _debugToken = String.fromEnvironment('TRUSTPIN_DEBUG_TOKEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TrustPinAttest bridge', (tester) async {
    final api = jsonDecode(await rootBundle.loadString('assets/api-test.json'))
        as Map<String, dynamic>;
    final home = Uri.parse('${api['base_url']}/home');
    final attest = TrustPinAttest.shared;

    // Before setup: reset is a no-op, headers are empty.
    await attest.reset();
    expect(await TrustPin.shared.attestationHeaders(home), isEmpty);

    await TrustPin.shared.setupWithNativeBundle();
    await attest.setLogLevel(TrustPinAttestLogLevel.debug);
    final logs = <String>[];
    final logSubscription = TrustPinAttest.logs.listen(
      (event) => logs.add('${event.level.value}: ${event.message}'),
    );

    await attest.setupWithNativeBundle(
      debugToken: _debugToken.isEmpty ? null : _debugToken,
    );
    await expectLater(
      attest.setupWithNativeBundle(),
      throwsA(isA<TrustPinAttestException>()
          .having((e) => e.isAlreadyInitialized, 'isAlreadyInitialized', true)),
    );

    final states = <TrustPinAttestState>[];
    final stateSubscription = attest.stateChanges.listen(states.add);
    await attest.bindToHeader('Authorization');
    await attest.prefetch();

    // The pinning SDK's provider hook answers through the attestation module.
    final headers = await TrustPin.shared.attestationHeaders(
      home,
      headers: {'Authorization': 'Bearer integration-test'},
    );

    // Let the first attempt settle.
    for (var i = 0; i < 30; i++) {
      final state = await attest.state;
      if (state is TrustPinAttestReady || state is TrustPinAttestFailed) break;
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    }
    final finalState = await attest.state;

    // ignore: avoid_print
    print('headers: ${headers.keys.toList()}');
    // ignore: avoid_print
    print('states: $states');
    // ignore: avoid_print
    print('final state: $finalState');
    // ignore: avoid_print
    print('logs:\n${logs.join('\n')}');

    expect(states, isNotEmpty);
    expect(
      finalState,
      anyOf(isA<TrustPinAttestReady>(), isA<TrustPinAttestFailed>()),
    );
    if (finalState is TrustPinAttestReady) {
      expect(headers.keys, contains(TrustPinAttest.headerName));
      expect(await attest.getToken(), isNotEmpty);
    }

    await attest.reset();
    await stateSubscription.cancel();
    await logSubscription.cancel();
  });
}
