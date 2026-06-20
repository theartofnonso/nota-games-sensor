import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trainware/features/nota_games/core/session_join_code_parser.dart';

/// Full-screen QR scanner — reads session id from the controller display.
class ScanJoinScreen extends StatefulWidget {
  const ScanJoinScreen({super.key});

  @override
  State<ScanJoinScreen> createState() => _ScanJoinScreenState();
}

class _ScanJoinScreenState extends State<ScanJoinScreen> {
  MobileScannerController? _controller;
  bool _handled = false;
  String? _error;
  bool _permissionDenied = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      setState(() {
        _permissionDenied = true;
        _initializing = false;
      });
      return;
    }

    setState(() {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        formats: const [BarcodeFormat.qrCode],
      );
      _initializing = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue ?? barcode.displayValue;
      if (raw == null || raw.trim().isEmpty) continue;

      final sessionId = SessionJoinCodeParser.parse(raw);
      if (sessionId != null) {
        _handled = true;
        _controller?.stop();
        Navigator.of(context).pop(sessionId);
        return;
      }
    }

    if (_error == null && mounted) {
      setState(() {
        _error = 'Unrecognised code. Use the QR shown on the host screen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(theme),
    );
  }

  Widget _closeButton() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '×',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_initializing) {
      return Stack(
        children: [
          const Center(child: CircularProgressIndicator(color: Colors.white)),
          _closeButton(),
        ],
      );
    }

    if (_permissionDenied) {
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography_outlined, size: 64, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  'Camera access is required to scan the session QR code.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
          _closeButton(),
        ],
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return MobileScanner(
      controller: controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Camera error: ${error.errorCode.name}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
          ),
        );
      },
      overlayBuilder: (context, constraints) {
        const scanSize = 240.0;
        const borderRadius = 16.0;
        final cutoutRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: scanSize,
          height: scanSize,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                painter: _ScanOverlayPainter(
                  cutoutRect: cutoutRect,
                  overlayColor: Colors.black.withValues(alpha: 0.75),
                  borderRadius: borderRadius,
                ),
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: cutoutRect,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white70, width: 2),
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: constraints.maxHeight - cutoutRect.top + 16,
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _closeButton(),
          ],
        );
      },
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({
    required this.cutoutRect,
    required this.overlayColor,
    required this.borderRadius,
  });

  final Rect cutoutRect;
  final Color overlayColor;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)));
    final path = Path.combine(PathOperation.difference, overlayPath, cutoutPath);

    canvas.drawPath(path, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) {
    return oldDelegate.cutoutRect != cutoutRect ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}
