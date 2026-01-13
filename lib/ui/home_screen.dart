import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_live_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    // Add post-frame callback if needed, or rely on listener in build?
    // Better to use a listener on the provider to show dialog.
    // However, context in initState is limited.
    // Easiest is to check error in build and show, but that rebuilds.
    // Let's use a PostFrameCallback or addListener in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<GeminiLiveService>();
      service.addListener(() {
        if (service.errorMessage != null && mounted) {
          _showErrorDialog(context, service.errorMessage!);
          service.clearError(); // Clear after showing
        }
      });
    });
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset('assets/images/logo.png'),
        ),
        title: Text(
          'SyncTalk',
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.black12,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Display Area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Consumer<GeminiLiveService>(
                  builder: (context, service, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Target Language (Japanese) - Main Focus
                        if (service.japaneseContent.isNotEmpty)
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Text(
                                  service.japaneseContent,
                                  style: GoogleFonts.notoSansJp(
                                    color: const Color(0xFF2962FF), // Electric Blue
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        else
                         Expanded(
                            child: Center(
                              child: Text(
                                service.isConnected ? "Listening..." : "Ready to Sync",
                                style: GoogleFonts.outfit(
                                  color: Colors.black26,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 32),

                        // Source/Reference Language (Chinese) - Subtitle
                        // Only show if available or if it's the latest input
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            service.chineseContent.isEmpty && service.japaneseContent.isEmpty 
                                ? "按下麥克風開始對話\n日本話 -> 自動播放\n中文 -> 顯示日文"
                                : service.chineseContent.isEmpty ? "..." : service.chineseContent,
                            style: GoogleFonts.notoSans(
                              color: Colors.black54,
                              fontSize: 16,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Bottom Control Bar
            Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Consumer<GeminiLiveService>(
                builder: (context, service, child) {
                  return Center(
                    child: GestureDetector(
                      onTap: () {
                         if (service.isConnected) {
                           service.disconnect();
                         } else {
                           service.connect();
                         }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: 80 + (service.volume * 50),
                        height: 80 + (service.volume * 50),
                        decoration: BoxDecoration(
                          color: service.isConnected ? const Color(0xFFFF453A) : const Color(0xFF2962FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (service.isConnected ? const Color(0xFFFF453A) : const Color(0xFF2962FF)).withValues(alpha: 0.3 + (service.volume * 0.5)),
                              blurRadius: 15 + (service.volume * 20),
                              spreadRadius: 2 + (service.volume * 10),
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: service.isConnecting
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                service.isConnected ? Icons.stop_rounded : Icons.mic_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
