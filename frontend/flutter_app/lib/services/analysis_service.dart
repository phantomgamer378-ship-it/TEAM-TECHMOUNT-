import 'dart:async';

/// Abstract analysis service — decouples UI from backend/mock implementations.
///
/// Allows switching between [MockAnalysisService] (demo mode) and
/// [ApiAnalysisService] (real FastAPI backend) without changing UI code.
abstract class AnalysisService {
  /// Start a new analysis session.
  Future<String> startSession({required String lang});

  /// Send audio data for analysis.
  Future<void> sendAudio(String sessionId, List<int> bytes, String format);

  /// End audio streaming and trigger final analysis.
  Future<void> endSession(String sessionId);

  /// Stream of risk update events during analysis.
  Stream<RiskUpdateEvent> get riskUpdates;

  /// Stream of status messages during analysis.
  Stream<StatusEvent> get statusUpdates;

  /// Stream of the final analysis result.
  Stream<FinalResultEvent> get finalResults;

  /// Dispose resources.
  void dispose();
}

/// A risk score update during live analysis.
class RiskUpdateEvent {
  final String sessionId;
  final int riskScore;
  final String level;
  final int second;

  const RiskUpdateEvent({
    required this.sessionId,
    required this.riskScore,
    required this.level,
    required this.second,
  });
}

/// A status message from the analysis pipeline.
class StatusEvent {
  final String sessionId;
  final String message;
  final String stage; // 'listening', 'understanding', 'checking_voice', 'checking_intent', 'calculating'

  const StatusEvent({
    required this.sessionId,
    required this.message,
    required this.stage,
  });
}

/// The final analysis result.
class FinalResultEvent {
  final String sessionId;
  final Map<String, dynamic> result;

  const FinalResultEvent({
    required this.sessionId,
    required this.result,
  });
}
