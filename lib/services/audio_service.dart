import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sound_stream/sound_stream.dart'; // Keep for Player
import 'package:mic_stream/mic_stream.dart'; // New stable recorder
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';

class AudioService {
  final PlayerStream _player = PlayerStream();
  
  bool _isInit = false;
  bool get isInit => _isInit;

  Future<void> init() async {
    if (_isInit) {
      debugPrint("📢 AudioService already initialized");
      return;
    }
    
    debugPrint("📢 Requesting mic permission...");
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint("📢 Mic permission denied!");
      throw Exception('Microphone permission not granted');
    }
    debugPrint("📢 Mic permission granted.");

    // Configure AudioSession
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
    ));
    debugPrint("📢 AudioSession configured.");

    debugPrint("📢 Initializing Player...");
    await _player.initialize(sampleRate: 24000);
    debugPrint("📢 Player Initialized.");
    
    _isInit = true;
  }

  /// Start recording and return a stream of PCM bytes (Uint8List)
  Future<Stream<Uint8List>> startRecordingStream() async {
    if (!_isInit) throw Exception('AudioService not initialized');
    
    debugPrint("📢 Starting MicStream (PCM16, 16k, Mono)...");
    
    final stream = await MicStream.microphone(
        audioSource: AudioSource.DEFAULT,
        sampleRate: 16000,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT,
    );
    
    if (stream == null) {
       debugPrint("❌ Failed to initialize MicStream");
       throw Exception("Failed to initialize MicStream");
    }
    
    return stream;
  }
  
  Future<void> startRecording() async {
     // No-op for compatibility
  }

  Future<void> stopRecording() async {
     // MicStream stops by cancelling subscription
  }
  
  /// Play PCM audio chunk
  Future<void> playChunk(Uint8List chunk) async {
    if (!_isInit) return;
    await _player.writeChunk(chunk);
  }
  
  Future<void> dispose() async {
    await _player.stop();
  }
}
