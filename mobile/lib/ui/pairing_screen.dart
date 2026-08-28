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

  int _selectedTabIndex = 0; // 0: Wi-Fi / QR, 1: Bluetooth
  bool _isConnecting = false;
  bool _isTorchOn = false;
  String? _errorMessage;
  bool _hasScanned = false;

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

    try {
      final data = jsonDecode(raw);
      if (data is Map && data.containsKey('ip')) {
        ip = data['ip'].toString();
        port = int.tryParse(data['port']?.toString() ?? '8765') ?? 8765;
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

    await _connectToHost(ip, port);
  }

  Future<void> _connectToHost(String ip, int port) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final success = await _connection.connect(ip, port);

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
      setState(() {
        _hasScanned = false;
        _errorMessage = 'Gagal terhubung ke $ip:$port. Pastikan Laptop & HP berada di Wi-Fi yang sama.';
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
                      _connectToHost(ip, port);
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

              // Segmented Tabs: Wi-Fi / QR vs Bluetooth (Matches Desktop Exactly!)
              _buildSegmentedTabs(isDark),
              const SizedBox(height: 14),

              // Main Card Container (Tab Views)
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildWifiQrTab(isDark)
                    : _buildBluetoothTab(isDark),
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
          const SizedBox(width: 4),

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

          // Camera Scanner Box
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Scanner View
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetectBarcode,
                  ),

                  // Scanner Overlay Frame
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.accentBlue.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  // Animated Scanline
                  AnimatedBuilder(
                    animation: _scanlineAnimation,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment(0, (_scanlineAnimation.value * 2) - 1),
                        child: Container(
                          height: 2.5,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.accentBlue,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentBlue,
                                blurRadius: 8,
                                spreadRadius: 1,
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
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                  // Loading Indicator if connecting
                  if (_isConnecting)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
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

          // Manual IP Fallback Link
          TextButton.icon(
            onPressed: _showManualIpDialog,
            icon: const Icon(Icons.edit_rounded, size: 14),
            label: const Text('Ketik IP Secara Manual'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bluetooth Pulse Icon
          Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5E5CE6).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.bluetooth_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                'Pasangkan HP langsung ke laptop via Bluetooth',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),

          // Steps
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                _buildBluetoothStep(
                  num: '1',
                  text: 'Aktifkan Bluetooth di HP Anda',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildBluetoothStep(
                  num: '2',
                  text: 'Pilih nama laptop Anda di Pengaturan Bluetooth HP',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                // If on Android, direct user or attempt auto-connect
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Buka Pengaturan Bluetooth di HP Anda untuk menghubungkan.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.settings_bluetooth_rounded, size: 18),
              label: const Text('Buka Pengaturan Bluetooth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E5CE6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothStep({
    required String num,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF5E5CE6),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
