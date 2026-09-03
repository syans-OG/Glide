import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/connection_service.dart';
import '../theme/app_theme.dart';
import 'controller_screen.dart';
import 'widgets/glide_logo_widget.dart';

class PairingScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const PairingScreen({
    super.key,
    required this.onToggleTheme,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> with SingleTickerProviderStateMixin {
  final ConnectionService _connection = ConnectionService();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final TextEditingController _ipController = TextEditingController(text: '192.168.1.');
  final TextEditingController _portController = TextEditingController(text: '8765');
  final TextEditingController _manualTokenController = TextEditingController();

  int _selectedTabIndex = 0;
  bool _isConnecting = false;
  bool _isTorchOn = false;
  String? _errorMessage;
  bool _hasScanned = false;
  String _authToken = '';

  // Bluetooth tab state
  final TextEditingController _btCodeController = TextEditingController();
  List<Map<String, String>> _btBonded = [];
  List<Map<String, String>> _btFound = [];
  Map<String, String>? _btLast;
  bool _btReady = false;
  bool _scanning = false;
  String? _btBusyAddress;
  String? _btError;

  late AnimationController _scanlineController;
  late Animation<double> _scanlineAnimation;

  @override
  void initState() {
    super.initState();
    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanlineAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _scanlineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanlineController.dispose();
    _scannerController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _manualTokenController.dispose();
    _btCodeController.dispose();
    super.dispose();
  }

  void _onDetectBarcode(BarcodeCapture capture) {
    if (_hasScanned || _isConnecting) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _hasScanned = true;
        _parseAndConnect(raw);
        break;
      }
    }
  }

  Future<void> _parseAndConnect(String raw) async {
    String ip = '127.0.0.1';
    int port = 8765;
    String token = '';

    try {
      final data = jsonDecode(raw);
      if (data is Map && data.containsKey('ip')) {
        ip = data['ip'].toString();
        port = int.tryParse(data['port']?.toString() ?? '8765') ?? 8765;
        token = data['token']?.toString() ?? '';
      }
    } catch (_) {
      if (raw.contains(':')) {
        final parts = raw.split(':');
        ip = parts[0].replaceAll('ws://', '').replaceAll('http://', '').replaceAll('/', '');
        port = int.tryParse(parts[1]) ?? 8765;
      } else {
        ip = raw.trim();
      }
    }

    await _connectToHost(ip, port, token: token);
  }

  Future<void> _connectToHost(String ip, int port, {String token = ''}) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      if (token.isNotEmpty) _authToken = token;
    });

    final success = await _connection.connect(ip, port, token: token.isNotEmpty ? token : _authToken);

    if (!mounted) return;
    setState(() => _isConnecting = false);

    if (success) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ControllerScreen(onToggleTheme: widget.onToggleTheme),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      final reason = _connection.lastError;
      final detail = _connection.lastErrorDetail;
      final suffix = detail.isNotEmpty ? '\n($detail)' : '';
      setState(() {
        _hasScanned = false;
        _errorMessage = reason == 'auth'
            ? 'Token salah. Pindai ulang QR di laptop untuk token terbaru.'
            : reason == 'timeout'
                ? 'Laptop tidak merespons. Pastikan aplikasi Glide terbuka di laptop.$suffix'
                : 'Gagal terhubung ke $ip:$port. Pastikan Laptop & HP berada di Wi-Fi yang sama.$suffix';
      });
    }
  }

  void _showManualIpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Masukkan IP Host Manual',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gunakan jika kamera tidak dapat memindai QR Code laptop',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // IP Field
                TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'IP Address Laptop',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Port Field
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Port (Default: 8765)',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Token Field (lihat di layar laptop, bawah QR)
                TextField(
                  controller: _manualTokenController,
                  decoration: InputDecoration(
                    labelText: 'Token (lihat di layar laptop)',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final ip = _ipController.text.trim();
                      final port = int.tryParse(_portController.text.trim()) ?? 8765;
                      final token = _manualTokenController.text.trim();
                      _connectToHost(ip, port, token: token);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Sambungkan'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Header Bar
              _buildHeader(isDark),
              const SizedBox(height: 14),

              // Segmented Tabs: Wi-Fi / QR vs Bluetooth
              _buildSegmentedTabs(isDark),
              const SizedBox(height: 14),

              // Main Card Container (Wi-Fi/QR or Bluetooth) with animated switch
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _selectedTabIndex == 1
                      ? _buildBluetoothTab(isDark)
                      : _buildWifiQrTab(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const GlideLogoWidget(size: 32),
            const SizedBox(width: 10),
            Text(
              'Glide',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: widget.onToggleTheme,
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 20,
          ),
          tooltip: 'Toggle Theme',
        ),
      ],
    );
  }

  Widget _buildSegmentedTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Wi-Fi / QR Tab
          Expanded(
            child: _buildTabButton(
              index: 0,
              icon: Icons.qr_code_scanner_rounded,
              label: 'Wi-Fi / QR',
              isDark: isDark,
            ),
          ),
          // Bluetooth Tab
          Expanded(
            child: _buildTabButton(
              index: 1,
              icon: Icons.bluetooth_rounded,
              label: 'Bluetooth',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedTabIndex = index;
            _errorMessage = null;
          });
          if (index == 1) {
            if (!_btReady && _btBusyAddress == null) {
              _initBtTab();
            }
          }
        },
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? AppColors.accentBlue
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWifiQrTab(bool isDark) {
    return Container(
      key: const ValueKey('tab-wifi'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Subtitle
          Text(
            'Pindai QR Code di Layar Laptop',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Arahkan kamera ke jendela remote laptop Anda',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Camera Scanner Box with Cyber HUD Reticle
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Scanner View
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetectBarcode,
                  ),

                  // Cyber Reticle Corner Brackets
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CyberReticlePainter(
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ),

                  // Animated Cyber Scanline
                  AnimatedBuilder(
                    animation: _scanlineAnimation,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment(0, (_scanlineAnimation.value * 2) - 1),
                        child: Container(
                          height: 3.0,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF00F2FE),
                                AppColors.accentBlue,
                                Color(0xFF00F2FE),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentBlue.withValues(alpha: 0.8),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Torch Toggle Button at Top-Right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      onPressed: () {
                        setState(() => _isTorchOn = !_isTorchOn);
                        _scannerController.toggleTorch();
                      },
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ),

                  // Loading Indicator if connecting
                  if (_isConnecting)
                    Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.accentRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Manual IP Fallback Action Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showManualIpDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ketik IP Secara Manual',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab(bool isDark) {
    return Container(
      key: const ValueKey('tab-bluetooth'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bluetooth header
          Column(
            children: [
              const SizedBox(height: 6),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.lightSurfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.bluetooth_rounded,
                    size: 30,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Koneksi Bluetooth',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sambungkan langsung tanpa Wi-Fi',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary action: scan for laptops
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _scanning ? null : _scanBt,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.radar_rounded, size: 18),
              label: Text(
                _scanning ? 'Memindai...' : 'Pindai Laptop',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (_btError != null) ...[
            const SizedBox(height: 10),
            Text(
              _btError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.accentRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Divider + label separating the action from the result list
          Row(
            children: [
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PERANGKAT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Unified device list: all laptops, deduplicated
          Expanded(
            child: _buildBtDeviceList(isDark),
          ),
        ],
      ),
    );
  }

  /// Named devices first, unnamed last.
  List<Map<String, String>> _btSorted(Iterable<Map<String, String>> devices) {
    final list = devices.toList();
    list.sort((a, b) {
      final an = (a['name'] ?? '').isNotEmpty ? 0 : 1;
      final bn = (b['name'] ?? '').isNotEmpty ? 0 : 1;
      if (an != bn) return an - bn;
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });
    return list;
  }

  Widget _buildBtDeviceTile(Map<String, String> d, bool isDark) {
    final addr = d['address'] ?? '';
    final name = (d['name'] ?? '').isNotEmpty ? d['name']! : 'Perangkat Bluetooth';
    final busy = _btBusyAddress == addr;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : () => _openBtConnectSheet(d, isDark),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.laptop_rounded, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        addr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBtDeviceList(bool isDark) {
    // Only laptops show — headset/watch/etc. hide.
    final bonded = _btSorted(_btBonded.where((d) => _btIsKnownLaptop(d)));
    // Merge bonded + scan results into one deduplicated list.
    final seen = <String>{};
    for (final d in bonded) {
      final a = d['address'];
      if (a != null) seen.add(a);
    }
    final found = _btSorted(_btFound.where((d) {
      final a = d['address'];
      return a == null || !seen.contains(a);
    }));
    final devices = [...bonded, ...found];

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.laptop_mac_rounded,
              size: 40,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              _btReady
                  ? 'Belum ada perangkat.\nKetuk Pindai untuk mencari laptop.'
                  : 'Menyiapkan Bluetooth...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final d in devices) _buildBtDeviceTile(d, isDark),
      ],
    );
  }

  Future<void> _initBtTab() async {
    final last = await _connection.bluetooth.lastDevice();
    if (!mounted) return;
    setState(() => _btLast = last);
    final ok = await _connection.bluetooth.ensurePermissions();
    if (!mounted) return;
    setState(() => _btReady = ok);
    if (ok) {
      await _loadBonded();
    } else {
      setState(() => _btError = 'Izin Bluetooth ditolak. Aktifkan manual di Pengaturan HP.');
    }
  }

  Future<void> _loadBonded() async {
    final devices = await _connection.bluetooth.bondedDevices();
    if (!mounted) return;
    setState(() {
      _btBonded = devices;
      if (devices.isNotEmpty || _btFound.isNotEmpty) {
        _btError = null;
      } else {
        _btError = 'Belum ada laptop terpasang. Ketuk Pindai untuk mencari.';
      }
    });
  }

  // Desktop hostname to recognise as "this laptop" during discovery.
  // Scanned devices that don't match it (by name) OR aren't a known MAC
  // are hidden, so the list only shows our laptop, not every nearby device.
  static const String _laptopName = 'LAPTOP-2T0FUDBU';

  bool _btIsKnownLaptop(Map<String, String> d) {
    final name = (d['name'] ?? '').toUpperCase();
    if (name.contains(_laptopName)) return true;
    // Fall back to any MAC we've connected to before.
    final addr = d['address'] ?? '';
    if (addr.isEmpty) return false;
    final lastAddr = _btLast?['address'] ?? '';
    if (addr == lastAddr) return true;
    // Bonded laptops sharing the same hostname pattern count too.
    for (final b in _btBonded) {
      if (b['address'] == addr &&
          (b['name'] ?? '').toUpperCase().contains(_laptopName)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _scanBt() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _btError = null;
    });
    final found = await _connection.bluetooth.scanDevices();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      // Fresh scan results (drop empties); bonded stays in its own section.
      // Only keep devices that look like our own laptop, so unrelated
      // Bluetooth devices (headphones, phones, speakers) don't show up.
      _btFound = found
          .where((d) => (d['address'] ?? '').isNotEmpty && _btIsKnownLaptop(d))
          .toList();
      if (_btBonded.isEmpty && _btFound.isEmpty) {
        _btError = 'Tidak ada perangkat ditemukan. Dekatkan HP ke laptop.';
      } else {
        _btError = null;
      }
    });
  }

  /// Tap a device → pick it first, then a sheet asks for the pairing code.
  Future<void> _openBtConnectSheet(Map<String, String> device, bool isDark) async {
    if (_btBusyAddress != null) return;
    final name = (device['name'] ?? '').isNotEmpty
        ? device['name']!
        : 'Perangkat Bluetooth';
    final addr = device['address'] ?? '';
    _btCodeController.clear();
    final entered = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sambungkan ke $name',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              addr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ketik 4 digit kode dari layar laptop.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _btCodeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Kode pairing',
                hintText: '0000',
                filled: true,
                fillColor:
                    isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                counterText: '',
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetCtx, _btCodeController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sambungkan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
    if (entered == null || !mounted) return;
    final code = entered.trim();
    if (code.isEmpty) {
      setState(() {
        _btError = 'Ketik 4 digit kode pairing dari layar laptop.';
      });
      return;
    }
    await _connectBt(device, code);
  }

  Future<void> _connectBt(Map<String, String> device, String code) async {
    final addr = device['address'] ?? '';
    if (addr.isEmpty || _btBusyAddress != null) return;
    setState(() {
      _btBusyAddress = addr;
      _btError = null;
    });
    HapticFeedback.mediumImpact();

    final success = await _connection.connectBluetooth(addr, token: code);

    if (!mounted) return;
    setState(() => _btBusyAddress = null);

    if (success) {
      HapticFeedback.heavyImpact();
      await _connection.bluetooth.saveLastDevice(device['name'] ?? '', addr);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ControllerScreen(onToggleTheme: widget.onToggleTheme),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      final reason = _connection.lastError;
      final detail = _connection.lastErrorDetail;
      final suffix = detail.isNotEmpty ? '\n($detail)' : '';
      setState(() {
        _btError = reason == 'bt-auth'
            ? 'Kode pairing ditolak. Periksa 4 digit di layar laptop.$suffix'
            : 'Gagal membuka link Bluetooth. Pastikan laptop ter-pair & Bluetooth aktif.$suffix';
      });
    }
  }
}

class _CyberReticlePainter extends CustomPainter {
  final Color color;

  _CyberReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    const pad = 12.0;

    final left = pad;
    final top = pad;
    final right = size.width - pad;
    final bottom = size.height - pad;

    // Top-Left
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);

    // Top-Right
    canvas.drawLine(Offset(right - cornerLength, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), paint);

    // Bottom-Right
    canvas.drawLine(Offset(right - cornerLength, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
