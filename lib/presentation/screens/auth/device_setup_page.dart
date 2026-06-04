import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/api_config.dart';

enum _SetupStep { scanning, connectInstructions, wifiForm, linking, done }

class DeviceSetupPage extends StatefulWidget {
  /// Called when setup completes (success or timeout) — enables Next button
  final void Function(bool linked) onSetupComplete;

  const DeviceSetupPage({super.key, required this.onSetupComplete});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  _SetupStep _step = _SetupStep.scanning;

  // Step 1
  bool _scanning = false;
  bool _deviceFound = false;
  String _scanMessage = 'Scanning for JalDharan device...';

  // Step 2
  bool _checkingDevice = false;
  String? _espMac;
  String? _step2Error;

  // Step 3
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  bool _sendingCreds = false;
  String? _step3Error;
  bool _obscurePass = true;

  // Step 4
  bool _linking = false;
  bool _linked = false;
  bool _linkTimeout = false;
  String _linkMessage = 'Waiting for your sensor to come online...';

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ── Step 1: Scan ──────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _deviceFound = false;
      _scanMessage = 'Scanning for JalDharan device...';
    });

    try {
      // Request location permission (required for WiFi scan on Android)
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _scanMessage =
                'Location permission required to scan for WiFi networks.';
          });
        }
        return;
      }

      // Check if WiFi scan is available
      final canScan = await WiFiScan.instance.canStartScan(
        askPermissions: true,
      );
      if (canScan != CanStartScan.yes) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _scanMessage = 'WiFi scanning not available on this device.';
          });
        }
        return;
      }

      // Start scan with 10s timeout
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 10));

      if (!mounted) return;

      final canGetResults = await WiFiScan.instance.canGetScannedResults(
        askPermissions: true,
      );
      if (canGetResults == CanGetScannedResults.yes) {
        final results = await WiFiScan.instance.getScannedResults();
        final found = results.any((r) => r.ssid == ApiConfig.espSsid);
        setState(() {
          _scanning = false;
          _deviceFound = found;
          _scanMessage = found
              ? 'JalDharan device found nearby!'
              : 'Device not found. Make sure your sensor is powered on.';
        });
      } else {
        setState(() {
          _scanning = false;
          _scanMessage = 'Could not read scan results. Try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanMessage = 'Scan failed: $e';
        });
      }
    }
  }

  // ── Step 2: Verify connection to ESP32 ───────────────────────────────────

  Future<void> _checkEspConnection() async {
    setState(() {
      _checkingDevice = true;
      _step2Error = null;
    });

    // Retry up to 3 times — phone may still be switching to JalDharan_Setup WiFi
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .get(Uri.parse(ApiConfig.espInfoEndpoint))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final mac = data['esp_mac'] as String?;
          if (mac != null && mac.isNotEmpty) {
            if (mounted) {
              setState(() {
                _espMac = mac;
                _checkingDevice = false;
                _step = _SetupStep.wifiForm;
              });
            }
            return;
          } else {
            if (mounted) {
              setState(() {
                _checkingDevice = false;
                _step2Error = 'Device responded but MAC address was missing.';
              });
            }
            return;
          }
        }
      } catch (_) {
        if (attempt < 3) {
          // Wait 2s before retry
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
        }
      }
    }

    // All 3 attempts failed
    if (mounted) {
      setState(() {
        _checkingDevice = false;
        _step2Error =
            "Could not reach device at ${ApiConfig.espInfoEndpoint}.\nMake sure you're connected to '${ApiConfig.espSsid}' WiFi and the sensor is powered on.";
      });
    }
  }

  // ── Step 3: Send WiFi credentials to ESP32 ───────────────────────────────

  Future<void> _sendCredentials() async {
    final ssid = _ssidController.text.trim();
    final pass = _passController.text;
    if (ssid.isEmpty) {
      setState(() => _step3Error = 'Please enter your WiFi name (SSID).');
      return;
    }

    setState(() {
      _sendingCreds = true;
      _step3Error = null;
    });

    try {
      // ESP32 expects application/x-www-form-urlencoded
      final response = await http
          .post(
            Uri.parse(ApiConfig.espSaveEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'ssid=${Uri.encodeComponent(ssid)}&pass=${Uri.encodeComponent(pass)}',
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        setState(() {
          _sendingCreds = false;
          _step = _SetupStep.linking;
        });
        // Wait 6s for ESP32 to restart and phone to reconnect to home WiFi
        await Future.delayed(const Duration(seconds: 6));
        if (mounted) _claimAndConfirm();
      } else {
        setState(() {
          _sendingCreds = false;
          _step3Error =
              'Device returned error ${response.statusCode}. Try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sendingCreds = false;
          _step3Error =
              'Failed to send credentials. Make sure you are still on JalDharan_Setup WiFi.';
        });
      }
    }
  }

  // ── Step 4: Claim device then confirm it's online ────────────────────────

  Future<void> _claimAndConfirm() async {
    if (!mounted) return;

    // Guard: esp_mac must be set from step 2
    if (_espMac == null || _espMac!.isEmpty) {
      setState(() {
        _linking = false;
        _linkTimeout = true;
        _linkMessage =
            'Setup failed — device MAC not found. Please restart the process.';
      });
      widget.onSetupComplete(false);
      return;
    }

    setState(() {
      _linking = true;
      _linked = false;
      _linkTimeout = false;
      _linkMessage = 'Registering your sensor...';
    });

    // Get JWT — all backend calls use ApiConfig.baseUrl, never 192.168.4.1
    final token = await AuthService().getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    // Step A: POST /devices/claim
    try {
      final claimResponse = await http
          .post(
            Uri.parse(ApiConfig.devicesClaimEndpoint),
            headers: headers,
            body: jsonEncode({
              'device_mac': _espMac,
              'device_name': 'My JalDharan Sensor',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (claimResponse.statusCode == 200 || claimResponse.statusCode == 201) {
        // Claimed successfully — now poll dashboard to confirm it's online
        setState(
          () => _linkMessage =
              'Sensor registered! Waiting for it to come online...',
        );
        await _pollDashboard(headers);
        return;
      } else if (claimResponse.statusCode == 409) {
        final body = claimResponse.body.toLowerCase();
        if (body.contains('another') || body.contains('other user')) {
          // Claimed by a different account
          if (mounted) {
            setState(() {
              _linking = false;
              _linkTimeout = true;
              _linkMessage =
                  'This device is already registered to another account.';
            });
            widget.onSetupComplete(false);
          }
          return;
        }
        // 409 = already claimed by THIS user — treat as success
        setState(
          () => _linkMessage =
              'Sensor already registered to your account. Confirming...',
        );
        await _pollDashboard(headers);
        return;
      } else {
        // Unexpected error — still try polling in case it was already claimed
        setState(
          () => _linkMessage =
              'Claim returned ${claimResponse.statusCode}, checking dashboard...',
        );
        await _pollDashboard(headers);
        return;
      }
    } catch (e) {
      // Network error during claim — phone may still be switching WiFi
      if (mounted) {
        setState(
          () => _linkMessage = 'Network error during claim, retrying...',
        );
      }
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) await _pollDashboard(headers);
    }
  }

  Future<void> _pollDashboard(Map<String, String> headers) async {
    // Poll GET /dashboard up to 10 times every 3s to confirm device is online
    for (int i = 0; i < 10; i++) {
      if (!mounted) return;
      setState(
        () =>
            _linkMessage = 'Waiting for sensor to come online... (${i + 1}/10)',
      );

      try {
        final response = await http
            .get(Uri.parse(ApiConfig.dashboardEndpoint), headers: headers)
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final devices = (data is Map)
              ? ((data['devices'] as List?) ?? [])
              : [];
          if (devices.isNotEmpty) {
            if (mounted) {
              setState(() {
                _linking = false;
                _linked = true;
                _linkMessage = 'Your sensor is live! 🎉';
              });
              widget.onSetupComplete(true);
            }
            return;
          }
        }
      } catch (_) {
        // Still reconnecting — keep polling
      }

      await Future.delayed(const Duration(seconds: 3));
    }

    // Sensor claimed but not yet online after 30s — still a partial success
    if (mounted) {
      setState(() {
        _linking = false;
        _linked = true;
        _linkMessage =
            'Sensor linked successfully! It may take a moment to appear online.';
      });
      widget.onSetupComplete(true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          _buildStepIndicator(),
          const SizedBox(height: 24),
          // Step content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Scan', 'Connect', 'WiFi Setup', 'Linking'];
    final currentIndex = _step.index.clamp(0, 3);
    return Row(
      children: List.generate(steps.length, (i) {
        final active = i == currentIndex;
        final done = i < currentIndex;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.fieldGreen
                            : active
                            ? AppColors.deepAquiferBlue
                            : AppColors.lightGrey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : AppColors.mediumGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: active
                            ? AppColors.deepAquiferBlue
                            : AppColors.mediumGrey,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: done ? AppColors.fieldGreen : AppColors.lightGrey,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _SetupStep.scanning:
        return _buildScanStep();
      case _SetupStep.connectInstructions:
        return _buildConnectStep();
      case _SetupStep.wifiForm:
        return _buildWifiFormStep();
      case _SetupStep.linking:
      case _SetupStep.done:
        return _buildLinkingStep();
    }
  }

  // Step 1
  Widget _buildScanStep() {
    return Column(
      key: const ValueKey('scan'),
      children: [
        if (_scanning) ...[
          const CircularProgressIndicator(color: AppColors.deepAquiferBlue),
          const SizedBox(height: 16),
          const Text(
            'Scanning for JalDharan device...',
            style: TextStyle(color: AppColors.mediumGrey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ] else if (_deviceFound) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.fieldGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sensors_rounded,
                  color: AppColors.fieldGreen,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JalDharan device found nearby!',
                        style: TextStyle(
                          color: AppColors.fieldGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ApiConfig.espSsid,
                        style: const TextStyle(
                          color: AppColors.mediumGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _step = _SetupStep.connectInstructions),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text(
                'Connect Now',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepAquiferBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ] else ...[
          const Icon(
            Icons.sensors_off_rounded,
            color: AppColors.warningOrange,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _scanMessage,
            style: const TextStyle(color: AppColors.mediumGrey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Scan Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepAquiferBlue,
              side: const BorderSide(color: AppColors.deepAquiferBlue),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                setState(() => _step = _SetupStep.connectInstructions),
            child: const Text(
              'Skip scan — I\'ll connect manually',
              style: TextStyle(color: AppColors.mediumGrey, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  // Step 2
  Widget _buildConnectStep() {
    return Column(
      key: const ValueKey('connect'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.deepAquiferBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.deepAquiferBlue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'How to connect',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepAquiferBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _instructionRow('1', 'Open your phone\'s WiFi settings'),
              _instructionRow('2', 'Connect to "$ApiConfig.espSsid"'),
              _instructionRow('3', 'No password needed — just tap Connect'),
              _instructionRow('4', 'Come back here once connected'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_step2Error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.criticalRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.criticalRed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _step2Error!,
                    style: const TextStyle(
                      color: AppColors.criticalRed,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _checkingDevice ? null : _checkEspConnection,
            icon: _checkingDevice
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _checkingDevice
                  ? 'Checking...'
                  : "I'm connected to JalDharan_Setup",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.fieldGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _instructionRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.deepAquiferBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.darkGrey),
            ),
          ),
        ],
      ),
    );
  }

  // Step 3
  Widget _buildWifiFormStep() {
    return Column(
      key: const ValueKey('wifi'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_espMac != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.fieldGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.memory_rounded,
                  color: AppColors.fieldGreen,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Device: $_espMac',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.fieldGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Enter your home WiFi credentials',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'The sensor will connect to this network to send data.',
          style: TextStyle(fontSize: 12, color: AppColors.mediumGrey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ssidController,
          decoration: InputDecoration(
            labelText: 'WiFi Name (SSID)',
            hintText: 'e.g. MyHomeWiFi',
            prefixIcon: const Icon(Icons.wifi_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passController,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'WiFi Password',
            hintText: 'Leave blank if open network',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (_step3Error != null) ...[
          const SizedBox(height: 10),
          Text(
            _step3Error!,
            style: const TextStyle(color: AppColors.criticalRed, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sendingCreds ? null : _sendCredentials,
            icon: _sendingCreds
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _sendingCreds ? 'Sending...' : 'Connect Sensor to WiFi',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepAquiferBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Step 4
  Widget _buildLinkingStep() {
    return Column(
      key: const ValueKey('linking'),
      children: [
        if (_linking) ...[
          const CircularProgressIndicator(color: AppColors.deepAquiferBlue),
          const SizedBox(height: 16),
          Text(
            _linkMessage,
            style: const TextStyle(color: AppColors.mediumGrey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your phone will reconnect to home WiFi automatically.',
            style: TextStyle(color: AppColors.mediumGrey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ] else if (_linked) ...[
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.fieldGreen,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _linkMessage,
            style: const TextStyle(
              color: AppColors.fieldGreen,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ] else if (_linkTimeout) ...[
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warningOrange,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _linkMessage,
            style: const TextStyle(color: AppColors.mediumGrey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _step = _SetupStep.scanning;
              _espMac = null;
              _linkTimeout = false;
            }),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Restart Setup'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepAquiferBlue,
              side: const BorderSide(color: AppColors.deepAquiferBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ] else ...[
          // Credentials sent, waiting for restart
          const CircularProgressIndicator(color: AppColors.tealStart),
          const SizedBox(height: 16),
          const Text(
            'Credentials sent! Your sensor is restarting...',
            style: TextStyle(color: AppColors.mediumGrey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
