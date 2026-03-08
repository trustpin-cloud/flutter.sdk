import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

void main() {
  runApp(const TrustPinSampleApp());
}

const int _primaryValue = 0xFF429488;

const MaterialColor trustPinGreen = MaterialColor(
  _primaryValue,
  <int, Color>{
    50: Color(0xFFE2F2EF),
    100: Color(0xFFB6DED7),
    200: Color(0xFF86C9BC),
    300: Color(0xFF56B3A1),
    400: Color(0xFF359F8C),
    500: Color(_primaryValue),       // Base color
    600: Color(0xFF3C867B),
    700: Color(0xFF35766B),
    800: Color(0xFF2E655B),
    900: Color(0xFF204739),
  },
);

class TrustPinSampleApp extends StatelessWidget {
  const TrustPinSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustPin Sample',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: trustPinGreen),
      ),
      home: const ContentView(),
    );
  }
}

class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  // Configuration fields
  final _organizationIdController = TextEditingController(text: "fb52418e-b5ae-4bff-b973-6da9ae07ba00");
  final _projectIdController = TextEditingController(text: "c14cf5c1-9a37-4204-b48e-0bf4c95b28f3");
  final _publicKeyController = TextEditingController(
    text: "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEvYfRJiY51wo1p2fyDt2CqOW6jGxoyZCNJXAEMPw3ZqVcjAZkSBARxWBQlFJ+si8FCReuVplDHFWwXt7nfpFNLw=="
  );
  
  // Test URL field
  final _testUrlController = TextEditingController(text: "https://api.trustpin.cloud/health");
  
  // App state
  String _logOutput = "Welcome to TrustPin Flutter Sample\nConfigure TrustPin and test connections...\n";
  String _statusMessage = "TrustPin not configured";
  bool _isConfigured = false;
  bool _isTesting = false;
  
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _logMessage("📱 TrustPin Flutter Sample started");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrustPin Sample'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // TrustPin Configuration Section
              _buildConfigurationSection(),
              const SizedBox(height: 16),
              
              // Connection Testing Section  
              _buildConnectionTestingSection(),
              const SizedBox(height: 16),
              
              // Log Output Section
              _buildLogOutputSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'TrustPin Configuration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            
            // Organization ID
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Organization ID',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _organizationIdController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your organization ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Project ID
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project ID',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _projectIdController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your project ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Public Key
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Public Key',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _publicKeyController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your base64 public key',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _setupTrustPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: trustPinGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Setup TrustPin'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTestingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Connection Testing',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            
            // Test URL
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test URL',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _testUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://api.example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isConfigured && !_isTesting) ? _testConnection : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConfigured ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isTesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Test Connection'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_isTesting ? _fetchCertificate : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Fetch Certificate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _clearLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: trustPinGreen,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Clear Log'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Status indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isConfigured ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Status: $_statusMessage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogOutputSection() {
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                controller: _logScrollController,
                child: Text(
                  _logOutput,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setupTrustPin() async {
    final organizationId = _organizationIdController.text.trim();
    final projectId = _projectIdController.text.trim();
    final publicKey = _publicKeyController.text.trim();

    if (organizationId.isEmpty || projectId.isEmpty || publicKey.isEmpty) {
      _logMessage("❌ Configuration failed: Missing required fields");
      return;
    }

    try {
      _logMessage("⚙️ Configuring TrustPin...");
      _logMessage("   Organization ID: $organizationId");
      _logMessage("   Project ID: $projectId");
      _logMessage("   Public Key: ${publicKey.length > 20 ? '${publicKey.substring(0, 20)}...' : publicKey}");

      await TrustPin.shared.setLogLevel(TrustPinLogLevel.debug);
      await TrustPin.shared.setup(TrustPinConfiguration(
        organizationId: organizationId,
        projectId: projectId,
        publicKey: publicKey,
        mode: TrustPinMode.strict,
      ));

      setState(() {
        _isConfigured = true;
        _statusMessage = "TrustPin configured";
      });
      _logMessage("✅ TrustPin configuration successful");
    } catch (e) {
      setState(() {
        _isConfigured = false;
        _statusMessage = "TrustPin not configured";
      });
      _logMessage("❌ TrustPin configuration failed: $e");
    }
  }

  Future<void> _fetchCertificate() async {
    final testUrl = _testUrlController.text.trim();
    if (testUrl.isEmpty) {
      _logMessage("Warning: No URL provided");
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = "Fetching certificate...";
    });

    try {
      final uri = Uri.parse(testUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : 443;

      _logMessage("Fetching certificate for $host:$port ...");
      final pem = await TrustPin.shared.fetchCertificate(host, port: port);

      final derBytes = _pemToBytes(pem);
      final hash = sha256.convert(derBytes);

      _logMessage("Certificate fetched (${pem.length} chars)");
      _logMessage("SHA-256: $hash");
      _logMessage(pem.trim());

      setState(() {
        _isTesting = false;
        _statusMessage = _isConfigured ? "TrustPin configured" : "TrustPin not configured";
      });
    } on TrustPinException catch (e) {
      setState(() {
        _isTesting = false;
        _statusMessage = _isConfigured ? "TrustPin configured" : "TrustPin not configured";
      });
      _logMessage("Fetch failed: $e");
    } catch (e) {
      setState(() {
        _isTesting = false;
        _statusMessage = _isConfigured ? "TrustPin configured" : "TrustPin not configured";
      });
      _logMessage("Error: $e");
    }
  }

  List<int> _pemToBytes(String pem) {
    final lines = pem.split('\n')
        .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
        .join();
    return base64Decode(lines);
  }

  Future<void> _testConnection() async {
    if (!_isConfigured) {
      _logMessage("⚠️ Test connection failed: TrustPin not configured");
      return;
    }

    final testUrl = _testUrlController.text.trim();
    if (testUrl.isEmpty) {
      _logMessage("⚠️ Test connection failed: No URL provided");
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = "Testing connection...";
    });

    try {
      _logMessage("🌐 Testing connection to: $testUrl");
      
      final result = await _performNetworkRequest(testUrl);
      
      setState(() {
        _isTesting = false;
        _statusMessage = "TrustPin configured";
      });
      _logMessage("✅ Connection test successful!");
      final preview = result.length > 200 ? '${result.substring(0, 200)}...' : result;
      _logMessage("   Response: $preview");
    } catch (e) {
      setState(() {
        _isTesting = false;
        _statusMessage = "TrustPin configured";
      });
      _logMessage("🌐 Connection failed: $e");
    }
  }

  Future<String> _performNetworkRequest(String url) async {
    final uri = Uri.parse(url);
    
    _logMessage("📡 Making HTTP request...");
    _logMessage("   Method: GET");
    _logMessage("   URL: $uri");
    _logMessage("   User-Agent: flutter.sdk-Sample/1.0");

    // Create TrustPinHttpClient for automatic certificate pinning
    final httpClient = TrustPinHttpClient.create();

    _logMessage("🔒 Using TrustPinHttpClient with automatic SSL certificate validation");

    try {
      final response = await httpClient.get(
        uri,
        headers: {
          'User-Agent': 'flutter.sdk-Sample/1.0',
        },
      );
      
      _logMessage("📨 Response received:");
      _logMessage("   Status: ${response.statusCode}");
      _logMessage("   Content-Length: ${response.body.length} bytes");

      httpClient.close();
      return response.body;
    } catch (e) {
      httpClient.close();
      rethrow;
    }
  }

  void _logMessage(String message) {
    final now = DateTime.now();
    final timestamp = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final logEntry = "[$timestamp] $message\n";
    
    setState(() {
      _logOutput += logEntry;
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearLog() {
    setState(() {
      _logOutput = "Welcome to TrustPin Flutter Sample\nConfigure TrustPin and test connections...\n";
    });
    _logMessage("🧹 Log cleared");
  }

  @override
  void dispose() {
    _organizationIdController.dispose();
    _projectIdController.dispose();
    _publicKeyController.dispose();
    _testUrlController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }
}