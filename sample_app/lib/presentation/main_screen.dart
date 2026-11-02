import 'package:flutter/material.dart';

import 'attestation_tab.dart';
import 'pinning_tab.dart';

export 'shared_widgets.dart' show trustPinGreen;

/// The sample's two tabs, as in the native samples: **Pinning** and
/// **Attestation**. Both stay alive while the other is shown, so a running
/// call and each tab's log survive switching.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  static const _titles = ['Pinning', 'Attestation'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [PinningTab(), AttestationTab()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Pinning',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Attestation',
          ),
        ],
      ),
    );
  }
}
