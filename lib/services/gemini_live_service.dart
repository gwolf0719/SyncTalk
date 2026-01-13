import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'audio_service.dart';

class GeminiLiveService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _japaneseContent = "";
  String _chineseContent = "";
  String? _errorMessage;
  
  final AudioService _audioService = AudioService();
  StreamSubscription? _rawMicSubscription;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get japaneseContent => _japaneseContent;
  String get chineseContent => _chineseContent;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Simple language detection
  bool _isJapanese(String text) {
    // Check for Hiragana or Katakana range
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text);
  }

  Future<void> connect() async {
    await _audioService.init();
    
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("Error: GEMINI_API_KEY not found in .env");
      return;
    }

    try {
      _errorMessage = null;
      _isConnecting = true;
      notifyListeners();

      // Initialize Audio
      await _audioService.init();

      // connect to WebSocket - Using v1beta (stable version)
      final uri = Uri.parse('wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey');
      debugPrint("Connecting to Gemini (v1beta): $uri");
      
      _channel = WebSocketChannel.connect(uri);
      
      // Listen to Server BEFORE sending setup
      _channel!.stream.listen(
        (message) {
          debugPrint("📥 Received message: $message");
          _handleServerMessage(message);
        },
        onError: (error) {
          debugPrint("❌ WebSocket Error: $error");
          _errorMessage = "Connection Error: $error";
          disconnect();
        },
        onDone: () {
          debugPrint("🔌 WebSocket Closed (onDone called)");
          if (_isConnected) {
             _errorMessage = "Connection Closed by Server";
          }
          disconnect();
        },
      );

      debugPrint("📤 About to send setup message...");
      // Send Setup Message
      _sendSetupMessage();

      // Wait a bit for setup to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // If we're still here, connection is good
      _isConnected = true;
      _isConnecting = false;
      notifyListeners();

      // Start Microphone and Stream to WS
      _startAudioStreaming();

    } catch (e) {
       debugPrint("Connection failed: $e");
       _errorMessage = "Failed to connect: $e";
       disconnect();
    }
  }

  void _sendSetupMessage() {
    final setupMsg = {
      "setup": {
        "model": "models/gemini-2.0-flash-exp",
        "generation_config": {
          "response_modalities": ["AUDIO"],
        },
        "system_instruction": {
          "parts": [
            {
              "text": "You are a professional bi-directional translator between Chinese (Traditional) and Japanese. When you hear Chinese, translate it to Japanese. When you hear Japanese, translate it to Chinese (Traditional). Only provide the translation, nothing else."
            }
          ]
        },
      }
    };
    debugPrint("Sending Setup Message: ${jsonEncode(setupMsg)}");
    _channel?.sink.add(jsonEncode(setupMsg));
  }
  


  void _sendKickstartAudio() {
    // Send 1 second of silence to kickstart the session immediately
    // 16000Hz * 2 bytes/sample = 32000 bytes. Zero-filled.
    final silentBytes = List<int>.filled(32000, 0); 
    final base64Audio = base64Encode(silentBytes);
    
    final audioMsg = {
      "realtime_input": {
        "media_chunks": [
          {
            "mime_type": "audio/pcm",
            "data": base64Audio
          }
        ]
      }
    };
    debugPrint("🚀 Sending Kickstart Audio...");
    _channel?.sink.add(jsonEncode(audioMsg));
  }

  double _volume = 0.0;
  double get volume => _volume;

  Future<void> _startAudioStreaming() async {
     debugPrint("🎙️ Starting Audio Streaming...");
     debugPrint("🎙️ AudioService Initialized? ${_audioService.isInit}"); // Need to verify if isInit getter exists or check private
     
     // Ensure we cancel any previous subscription
     _rawMicSubscription?.cancel();
     
     final stream = await _audioService.startRecordingStream();
     debugPrint("🎙️ Stream obtained: $stream");

     _rawMicSubscription = stream.listen((Uint8List chunk) {
       // MicStream returns raw PCM, no need to strip headers
       
       // Calculate volume (RMS)
       double sumSquares = 0.0;
       // process 50 samples at a time to save cpu
       for (int i = 0; i < chunk.length; i += 2) { 
         if (i + 1 >= chunk.length) break;
         // Little endian 16-bit
         int sample = chunk[i] | (chunk[i+1] << 8);
         // Signed 16-bit conversion
         if (sample > 32767) sample -= 65536;
         // Normalize to 0.0 - 1.0
         double normalized = sample / 32768.0;
         sumSquares += normalized * normalized;
       }
       
       if (chunk.length > 0) {
         _volume = (sumSquares / (chunk.length / 2));
         // Amplify for visibility
         _volume = _volume * 5.0; 
         if (_volume > 1.0) _volume = 1.0;
       }
       
       if (_isConnected) notifyListeners();

       if (_channel == null) return;
       
       // Convert raw PCM to base64
       final base64Audio = base64Encode(chunk);
       
       final msg = {
         "realtime_input": {
           "media_chunks": [
             {
               "mime_type": "audio/pcm",
               "data": base64Audio
             }
           ]
         }
       };
       // Print only periodically or if volume > threshold to reduce spam, but for now every chunk to debug
       if (_volume > 0.01) {
          debugPrint("🎤 Mic Data: ${chunk.length} bytes, Vol: ${_volume.toStringAsFixed(4)} sent."); 
       }
       _channel!.sink.add(jsonEncode(msg));
     }, onError: (e) {
       debugPrint("❌ Mic Stream Error: $e");
     }, onDone: () {
       debugPrint("⚠️ Mic Stream Done/Closed");
     });
     
     // No need to call startRecording() separatey as startStream does it
     debugPrint("🎙️ Recorder started via startStream.");
  }

  void _handleServerMessage(dynamic message) {
    try {
      // Message can be String or Uint8List
      String jsonString;
      if (message is Uint8List) {
        jsonString = String.fromCharCodes(message);
      } else if (message is String) {
        jsonString = message;
      } else {
        debugPrint("Unknown message type: ${message.runtimeType}");
        return;
      }
      
      final jsonMap = jsonDecode(jsonString);
      
      // Handle ServerContent
      if (jsonMap.containsKey('serverContent')) {
        final content = jsonMap['serverContent'];
        
        // Handle Model Turn (Text & Audio)
        if (content.containsKey('modelTurn')) {
          final parts = content['modelTurn']['parts'] as List;
          for (var part in parts) {
            if (part.containsKey('text')) {
              final text = part['text'] as String;
              if (text.isNotEmpty) {
                 debugPrint("💬 Received Text: $text");
                 if (_isJapanese(text)) {
                   _japaneseContent = text;
                 } else {
                   _chineseContent = text;
                 }
                 notifyListeners();
              }
            }
            if (part.containsKey('inlineData')) {
              final mimeType = part['inlineData']['mimeType'];
              // Gemini usually sends "audio/pcm; rate=24000" back
              if (mimeType.startsWith('audio/pcm')) {
                final base64Data = part['inlineData']['data'];
                final bytes = base64Decode(base64Data);
                debugPrint("🔊 Playing Audio Chunk: ${bytes.length} bytes");
                _audioService.playChunk(bytes);
              }
            }
          }
        }
      }
      
      // Setup Complete
      if (jsonMap.containsKey('setupComplete')) {
        debugPrint("✅ Gemini Setup Complete!");
        _isConnected = true;
        _isConnecting = false;
        notifyListeners();
        
        // Send initial silence to convince server we are live
        _sendKickstartAudio();
        
        // Start streaming audio from microphone immediately
        _startAudioStreaming();
      }
      
    } catch (e) {
      debugPrint("Error parsing message: $e");
    }
  }

  Future<void> disconnect() async {
    _rawMicSubscription?.cancel();
    await _audioService.stopRecording();
    
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    
    _japaneseContent = "";
    _chineseContent = "";
    notifyListeners();
  }
  
  @override
  void dispose() {
    disconnect();
    _audioService.dispose();
    super.dispose();
  }
}
