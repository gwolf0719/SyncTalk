import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;
import 'audio_service.dart';

class GeminiLiveService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _japaneseContent = "";
  String _chineseContent = "";
  String? _errorMessage;
  double _volume = 0.0;
  
  final AudioService _audioService = AudioService();
  StreamSubscription? _rawMicSubscription;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get japaneseContent => _japaneseContent;
  String get chineseContent => _chineseContent;
  String? get errorMessage => _errorMessage;
  double get volume => _volume;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isJapanese(String text) {
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text);
  }

  Future<void> connect() async {
    if (_isConnecting || _isConnected) return;
    await disconnect();

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _errorMessage = "缺少 API KEY";
      notifyListeners();
      return;
    }

    try {
      _errorMessage = null;
      _isConnecting = true;
      notifyListeners();

      await _audioService.init();
      final uri = Uri.parse('wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey');
      debugPrint("📢 Connecting Gemini (1.5 Flash): $uri");
      
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (message) => _handleServerMessage(message),
        onError: (e) {
          debugPrint("❌ WebSocket Error: $e");
          disconnect();
        },
        onDone: () {
          final code = _channel?.closeCode;
          debugPrint("🔌 WebSocket Closed. Code: $code");
          disconnect();
        },
      );

      _sendSetupMessage();
    } catch (e) {
       _errorMessage = "連線失敗";
       disconnect();
    }
  }

  void _sendSetupMessage() {
    final setupMsg = {
      "setup": {
        "model": "models/gemini-1.5-flash",
        "generation_config": {"response_modalities": ["AUDIO", "TEXT"]},
        "system_instruction": {
          "parts": [{"text": "You are a professional bi-directional translator between Chinese and Japanese. When you hear Chinese, translate to Japanese. When you hear Japanese, translate to Chinese."}]
        },
      }
    };
    _channel?.sink.add(jsonEncode(setupMsg));
  }
  
  void _sendKickstartAudio() {
    final silentBytes = List<int>.filled(3200, 0); 
    final msg = {
      "realtime_input": {
        "media_chunks": [{"mime_type": "audio/pcm;rate=16000", "data": base64Encode(silentBytes)}]
      }
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  Future<void> _startAudioStreaming() async {
     _rawMicSubscription?.cancel();
     final stream = await _audioService.startRecordingStream();
     final List<int> buffer = [];

     _rawMicSubscription = stream.listen((Uint8List chunk) {
        double sumSquares = 0.0;
        for (int i = 0; i < chunk.length; i += 2) { 
          if (i + 1 >= chunk.length) break;
          int sample = chunk[i] | (chunk[i+1] << 8);
          if (sample > 32767) sample -= 65536;
          double normalized = sample / 32768.0;
          sumSquares += normalized * normalized;
        }
        _volume = math.sqrt(sumSquares / (chunk.length / 2)) * 12.0;
        if (_volume > 1.0) _volume = 1.0;
        notifyListeners();

        if (_channel == null || !_isConnected) return;
        buffer.addAll(chunk);
        while (buffer.length >= 3200) {
          final chunkToSend = Uint8List.fromList(buffer.sublist(0, 3200));
          buffer.removeRange(0, 3200);
          _channel!.sink.add(jsonEncode({
            "realtime_input": {
              "media_chunks": [{"mime_type": "audio/pcm;rate=16000", "data": base64Encode(chunkToSend)}]
            }
          }));
        }
     });
  }

  void _handleServerMessage(dynamic message) {
    try {
      final jsonMap = jsonDecode(message is Uint8List ? String.fromCharCodes(message) : message);
      if (jsonMap.containsKey('setupComplete')) {
        _isConnected = true;
        _isConnecting = false;
        notifyListeners();
        _sendKickstartAudio();
        _startAudioStreaming();
      }
      _processJson(jsonMap);
    } catch (e) {}
  }

  void _processJson(Map<String, dynamic> json) {
    if (json.containsKey('serverContent')) _parseParts(json['serverContent']['modelTurn']?['parts']);
    if (json.containsKey('modelTurn')) _parseParts(json['modelTurn']['parts']);
  }

  void _parseParts(dynamic parts) {
    if (parts is! List) return;
    for (var part in parts) {
      if (part.containsKey('text')) {
        final text = part['text'];
        if (_isJapanese(text)) _japaneseContent = text; else _chineseContent = text;
        notifyListeners();
      }
      if (part.containsKey('inlineData')) {
        _audioService.playChunk(base64Decode(part['inlineData']['data']));
      }
    }
  }

  Future<void> disconnect() async {
    _rawMicSubscription?.cancel();
    _rawMicSubscription = null;
    await _audioService.stopRecording();
    _volume = 0.0;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _japaneseContent = "";
    _chineseContent = "";
    notifyListeners();
  }
  
  @override
  void dispose() { disconnect(); _audioService.dispose(); super.dispose(); }
}
