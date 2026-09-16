import 'dart:async';
import 'analysis_service.dart';

/// Mock analysis service that simulates a realistic call analysis experience.
///
/// Used for demo mode — emits timed events that mimic the real pipeline:
/// risk progression 18 → 30 → 51 → 73 → 86 → 93, with transcript updates,
/// scam detection, and liveness trigger.
///
/// All simulated results are clearly labeled as demo data.
class MockAnalysisService extends AnalysisService {
  final _riskController = StreamController<RiskUpdateEvent>.broadcast();
  final _statusController = StreamController<StatusEvent>.broadcast();
  final _finalController = StreamController<FinalResultEvent>.broadcast();

  Timer? _timer;
  int _sessionCounter = 0;

  @override
  Stream<RiskUpdateEvent> get riskUpdates => _riskController.stream;

  @override
  Stream<StatusEvent> get statusUpdates => _statusController.stream;

  @override
  Stream<FinalResultEvent> get finalResults => _finalController.stream;

  @override
  Future<String> startSession({required String lang}) async {
    _sessionCounter++;
    return 'demo-$_sessionCounter-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> sendAudio(String sessionId, List<int> bytes, String format) async {
    // In demo mode, audio is not actually processed.
    // We start the simulated analysis pipeline.
    _runSimulation(sessionId);
  }

  @override
  Future<void> endSession(String sessionId) async {
    // No-op for demo mode — simulation runs on its own timer.
  }

  void _runSimulation(String sessionId) {
    final stages = <_SimEvent>[
      _SimEvent(
        delay: const Duration(milliseconds: 800),
        status: StatusEvent(sessionId: sessionId, message: 'Listening to audio…', stage: 'listening'),
      ),
      _SimEvent(
        delay: const Duration(seconds: 2),
        risk: RiskUpdateEvent(sessionId: sessionId, riskScore: 18, level: 'LOW', second: 1),
        status: StatusEvent(sessionId: sessionId, message: 'Understanding conversation…', stage: 'understanding'),
      ),
      _SimEvent(
        delay: const Duration(seconds: 3),
        risk: RiskUpdateEvent(sessionId: sessionId, riskScore: 30, level: 'GUARDED', second: 2),
        status: StatusEvent(sessionId: sessionId, message: 'Checking voice patterns…', stage: 'checking_voice'),
      ),
      _SimEvent(
        delay: const Duration(seconds: 4),
        risk: RiskUpdateEvent(sessionId: sessionId, riskScore: 51, level: 'SUSPICIOUS', second: 3),
        status: StatusEvent(sessionId: sessionId, message: 'Checking intent…', stage: 'checking_intent'),
      ),
      _SimEvent(
        delay: const Duration(seconds: 5),
        risk: RiskUpdateEvent(sessionId: sessionId, riskScore: 73, level: 'HIGH', second: 4),
        status: StatusEvent(sessionId: sessionId, message: 'Suspicious patterns found', stage: 'checking_intent'),
      ),
      _SimEvent(
        delay: const Duration(seconds: 7),
        risk: RiskUpdateEvent(sessionId: sessionId, riskScore: 86, level: 'CRITICAL', second: 5),
        status: StatusEvent(sessionId: sessionId, message: 'Multiple threat signals detected', stage: 'calculating'),
      ),
      _SimEvent(
        delay: const Duration(seconds: 9),
        risk: RiskUpdateEvent(sessionId: sessionId, riskScore: 93, level: 'CRITICAL', second: 6),
      ),
    ];

    int i = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (i >= stages.length) {
        timer.cancel();
        // Emit final result.
        _finalController.add(FinalResultEvent(
          sessionId: sessionId,
          result: _buildDemoResult(sessionId),
        ));
        return;
      }

      final stage = stages[i];
      final elapsed = Duration(milliseconds: 500 * (i + 1));
      if (elapsed >= stage.delay) {
        if (stage.status != null) _statusController.add(stage.status!);
        if (stage.risk != null) _riskController.add(stage.risk!);
        i++;
      }
    });
  }

  Map<String, dynamic> _buildDemoResult(String sessionId) => {
        'session_id': sessionId,
        'fallback_used': true,
        'error': 'Demo mode — simulated analysis',
        'risk': {'score': 93, 'level': 'CRITICAL'},
        'voice_trust': {'spoof_risk': 0.84, 'status': 'SUSPICIOUS'},
        'asr': {
          'language': 'hi',
          'transcript': 'मुझे अभी पैसे चाहिए, तुम्हें अभी transfer करना होगा',
        },
        'scam_analysis': {
          'risk': 0.91,
          'category': 'Financial Impersonation',
          'indicators': [
            'Urgent money request',
            'Identity claim',
            'Emotional manipulation',
            'Financial pressure',
          ],
        },
        'attack_types': ['Family Impersonation', 'Financial Scam'],
        'risk_timeline': [
          {'second': 1, 'risk_score': 18, 'level': 'LOW'},
          {'second': 2, 'risk_score': 30, 'level': 'GUARDED'},
          {'second': 3, 'risk_score': 51, 'level': 'SUSPICIOUS'},
          {'second': 4, 'risk_score': 73, 'level': 'HIGH'},
          {'second': 5, 'risk_score': 86, 'level': 'CRITICAL'},
          {'second': 6, 'risk_score': 93, 'level': 'CRITICAL'},
        ],
        'liveness': {
          'required': true,
          'challenge': 'VANIRAKSHAK 27',
          'tier': 'T3',
        },
        'policy_action': 'BLOCK',
        'explanation': [
          '[voice] Spoof probability 0.84 — likely AI-generated',
          '[scam_rule] Urgent financial request detected',
          '[scam_rule] Identity claim without verification',
          '[fused] Combined risk exceeds critical threshold',
          '[policy] Blocking recommended',
        ],
        'recommendation':
            'Do not share OTPs, PINs or financial information. End the call immediately.',
        'weights_used': {
          'voice': 0.30,
          'identity': 0.20,
          'scam': 0.30,
          'context': 0.10,
          'liveness': 0.10,
        },
      };

  @override
  void dispose() {
    _timer?.cancel();
    _riskController.close();
    _statusController.close();
    _finalController.close();
  }
}

class _SimEvent {
  final Duration delay;
  final RiskUpdateEvent? risk;
  final StatusEvent? status;

  const _SimEvent({required this.delay, this.risk, this.status});
}
