import 'package:flutter/services.dart';

class NativeService {
  static const MethodChannel _channel = MethodChannel('com.sih.voice_clone_shield/native');

  Future<void> startBackgroundService() async {
    try {
      await _channel.invokeMethod('startBackgroundService');
    } on PlatformException catch (e) {
      print("Failed to start background service: '${e.message}'.");
    }
  }

  Future<bool> checkOverlayPermission() async {
    try {
      final bool result = await _channel.invokeMethod('checkOverlayPermission');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check overlay permission: '${e.message}'.");
      return false;
    }
  }

  Future<String> getTelephonyState() async {
    try {
      final String result = await _channel.invokeMethod('getTelephonyState');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get telephony state: '${e.message}'.");
      return "UNKNOWN";
    }
  }
}
