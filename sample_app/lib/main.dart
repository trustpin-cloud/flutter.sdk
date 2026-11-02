import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

import 'presentation/attestation_view_model.dart';
import 'presentation/main_screen.dart';
import 'presentation/main_view_model.dart';
import 'service_locator.dart';

void main() {
  // Bind the framework before invoking any method-channel call. `setLogLevel`
  // crosses the platform channel, which requires `ServicesBinding` to be
  // initialized first.
  WidgetsFlutterBinding.ensureInitialized();

  // Set the SDK log level once at process start. This controls how much the
  // SDK logs; the ViewModel routes that output into the in-app feed via
  // `TrustPin.logs`, alongside its own narrative.
  TrustPin.shared.setLogLevel(TrustPinLogLevel.info);

  runApp(const TrustPinSampleApp());
}

class TrustPinSampleApp extends StatefulWidget {
  const TrustPinSampleApp({super.key});

  @override
  State<TrustPinSampleApp> createState() => _TrustPinSampleAppState();
}

class _TrustPinSampleAppState extends State<TrustPinSampleApp> {
  late final ServiceLocator _locator = ServiceLocator();

  @override
  void dispose() {
    _locator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MainViewModel>(
          create: (_) => MainViewModel(
            configurationRepository: _locator.configurationRepository,
            configure: _locator.configurePinningUseCase,
            configureFromBundle: _locator.configurePinningFromBundleUseCase,
            testConnection: _locator.testPinnedConnectionUseCase,
            fetchCertificate: _locator.fetchCertificateUseCase,
          ),
        ),
        ChangeNotifierProvider<AttestationViewModel>(
          create: (_) => AttestationViewModel(
            repository: _locator.attestationRepository,
            setUp: _locator.setUpAttestationUseCase,
            callProtectedEndpoint: _locator.callProtectedEndpointUseCase,
            callSensitiveEndpoint: _locator.callSensitiveEndpointUseCase,
            signOut: _locator.signOutSessionUseCase,
            reset: _locator.resetAttestationUseCase,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'TrustPin Sample',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: trustPinGreen),
        ),
        home: const MainScreen(),
      ),
    );
  }
}
