import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_live_service.dart';

class PresentationScreen extends StatelessWidget {
  const PresentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Elements (Subtle Gradient or Animation placeholder)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, Color(0xFF1a1a1a)],
                ),
              ),
            ),
            
            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Indicator & Waveform
                  Consumer<GeminiLiveService>(
                    builder: (context, service, child) {
                      return Column(
                        children: [
                          if (service.isConnected)
                             const SizedBox(
                               height: 60,
                               child: AudioWaveform(), // Custom Animated Widget
                             )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.mic_off, color: Colors.grey, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  "Paused",
                                  style: GoogleFonts.notoSans(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  
                  // Big Translated Text
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Consumer<GeminiLiveService>(
                        builder: (context, service, child) {
                          return SingleChildScrollView(
                            reverse: true,
                            child: Text(
                              service.japaneseContent.isEmpty ? "..." : service.japaneseContent,
                              style: GoogleFonts.notoSansJp(
                                color: Colors.white,
                                fontSize: 48, // Very Large Font
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Hint for User
                  Text(
                    "全螢幕展示中",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            // Close Button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white12,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioWaveform extends StatefulWidget {
  const AudioWaveform({super.key});

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: WaveformPainter(_controller.value),
          size: const Size(double.infinity, 50),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final Paint _paint = Paint()
    ..color = const Color(0xFF4BFF88)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  WaveformPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    // Simple simulated waveform
    for (int i = 0; i < 5; i++) {
        final x = size.width / 2 + (i - 2) * 20;
        // Random-ish height based on animation
        final h = 10 + 15 * ((animationValue + i * 0.2) % 1.0); // Simple periodic wave
        canvas.drawLine(Offset(x, centerY - h), Offset(x, centerY + h), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
