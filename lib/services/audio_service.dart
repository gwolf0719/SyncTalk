import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sound_stream/sound_stream.dart'; // Keep for Player
import 'package:flutter_sound/flutter_sound.dart'; // Robust recorder
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
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

    debugPrint("📢 Opening Recorder...");
    await _recorder.openRecorder();
    debugPrint("📢 Recorder Opened.");

    debugPrint("📢 Initializing Player...");
    await _player.initialize(sampleRate: 24000);
    debugPrint("📢 Player Initialized.");
    
    _isInit = true;
  }

  bool _isRecording = false;

  /// Start recording and return a stream of PCM bytes (Uint8List)
  Future<Stream<Uint8List>> startRecordingStream() async {
    if (!_isInit) throw Exception('AudioService not initialized');
    if (_isRecording) {
      debugPrint("⚠️ Recorder already running. Returning current controller stream.");
      // In a real app we might return the existing stream, but for now we reset
      await stopRecording();
    }
    
    debugPrint("📢 Starting flutter_sound Recorder (VOICE_RECOGNITION, 16k, Mono)...");
    
    try {
      final streamController = StreamController<Uint8List>();
      
      await _recorder.startRecorder(
        toStream: streamController.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        audioSource: AudioSource.voice_recognition,
      );
      
      _isRecording = true;
      
      int chunkCount = 0;
      return streamController.stream.map((data) {
        if (++chunkCount % 50 == 0) {
          debugPrint("🎤 [Hardware Mic] Stream active: received 50 chunks. Length: ${data.length}");
        }
        return data;
      });
    } catch (e) {
      debugPrint("❌ Hardware Recorder Start Failed: $e");
      _isRecording = false;
      rethrow;
    }
  }
  
  Future<void> stopRecording() async {
    if (_isRecording) {
      await _recorder.stopRecorder();
      _isRecording = false;
      debugPrint("🛑 Recorder stopped.");
    }
  }
  
  /// Play PCM audio chunk
  Future<void> playChunk(Uint8List chunk) async {
    if (!_isInit) return;
    await _player.writeChunk(chunk);
  }
  
  Future<void> dispose() async {
    await _recorder.closeRecorder();
    await _player.stop();
  }
}
