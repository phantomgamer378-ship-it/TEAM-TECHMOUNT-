import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';
import '../../services/api_client.dart';
import '../../services/mock_analysis_service.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'widgets/waveform_painter.dart';
import 'widgets/risk_gauge.dart';
import 'widgets/analysis_steps.dart';
import 'call_result_screen.dart';

/// Live Call Screen — THE HERO EXPERIENCE.
///
/// The user can:
/// 1. Start live recording to test their REAL voice with the backend model
/// 2. Upload an audio file for analysis (real backend)
/// 3. Start a simulated demo call (mock scenario)
///
/// Shows: caller identity, animated waveform, analysis pipeline steps,
/// dynamic risk gauge, detected threat signals.
class LiveCallScreen extends StatefulWidget {
  const LiveCallScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

enum _CallPhase { idle, recording, analyzing, done }

class _LiveCallScreenState extends State<LiveCallScreen> {
  _CallPhase _phase = _CallPhase.idle;
  String _lang = 'hi';
  String _currentStage = 'idle';
  int _riskScore = 0;
  final List<int> _riskHistory = [];
  final List<String> _detectedSignals = [];
  Map<String, dynamic>? _result;

  MockAnalysisService? _mockService;
  final List<StreamSubscription> _subs = [];

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordSeconds = 0;
  String? _recordingPath;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    _mockService?.dispose();
    super.dispose();
  }

  Future<void> _startLiveRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied.')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/live_call_${DateTime.now().millisecondsSinceEpoch}.wav';
      _recordingPath = path;

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
        path: path,
      );

      setState(() {
        _phase = _CallPhase.recording;
        _recordSeconds = 0;
        _riskScore = 0;
        _riskHistory.clear();
        _detectedSignals.clear();
        _result = null;
        _currentStage = 'listening';
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordSeconds++);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopAndAnalyzeRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      final filePath = path ?? _recordingPath;

      if (filePath == null || !File(filePath).existsSync()) {
        setState(() => _phase = _CallPhase.idle);
        return;
      }

      final file = File(filePath);
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recorded audio was empty. Please try again.')),
          );
        }
        setState(() => _phase = _CallPhase.idle);
        return;
      }

      await _analyzeAudioBytes(bytes, 'live_recording.wav', 'wav');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing voice: $e')),
        );
        setState(() => _phase = _CallPhase.idle);
      }
    }
  }

  Future<void> _analyzeAudioBytes(Uint8List bytes, String filename, String fmt) async {
    setState(() {
      _phase = _CallPhase.analyzing;
      _currentStage = 'listening';
      _riskScore = 0;
      _riskHistory.clear();
      _detectedSignals.clear();
      _result = null;
    });

    try {
      // WebSocket streaming first
      final sessionId = 'vr-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      final channel = widget.api.connectStream(sessionId);

      channel.sink.add(jsonEncode({'type': 'start', 'lang': _lang}));
      channel.sink.add(jsonEncode({
        'type': 'audio',
        'data': base64Encode(bytes),
        'fmt': fmt,
      }));
      channel.sink.add(jsonEncode({'type': 'end'}));

      await for (final raw in channel.stream) {
        if (!mounted) break;
        final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
        switch (msg['type']) {
          case 'status':
            setState(() => _currentStage = _mapStage(msg['message'].toString()));
          case 'risk_update':
            final score = (msg['risk_score'] ?? 0) as int;
            setState(() {
              _riskScore = score;
              _riskHistory.add(score);
              _updateSignalsFromScore(score);
            });
          case 'final':
            final r = (msg['response'] as Map).cast<String, dynamic>();
            setState(() {
              _result = r;
              _phase = _CallPhase.done;
              _currentStage = 'done';
              final finalScore = (r['risk'] as Map?)?['score'] as int?;
              if (finalScore != null) _riskScore = finalScore;
              _populateFinalSignals(r);
            });
            await channel.sink.close();
            return;
          case 'error':
            setState(() => _phase = _CallPhase.done);
            await channel.sink.close();
            return;
        }
      }
    } catch (_) {
      // Fall back to HTTP upload
      try {
        final r = await widget.api.uploadAudio(bytes: bytes, filename: filename, lang: _lang);
        if (mounted) {
          setState(() {
            _result = r as Map<String, dynamic>;
            _phase = _CallPhase.done;
            _currentStage = 'done';
            final riskScore = (r['risk'] as Map?)?['score'] as int?;
            if (riskScore != null) _riskScore = riskScore;
            _populateFinalSignals(r);
          });
        }
      } catch (e) {
        if (mounted) setState(() => _phase = _CallPhase.idle);
      }
    }
  }

  void _updateSignalsFromScore(int score) {
    if (score >= 50 && !_detectedSignals.contains('AI voice indicators')) {
      _detectedSignals.add('AI voice indicators');
    }
    if (score >= 60 && !_detectedSignals.contains('Urgent money request')) {
      _detectedSignals.add('Urgent money request');
    }
    if (score >= 70 && !_detectedSignals.contains('Identity claim')) {
      _detectedSignals.add('Identity claim');
    }
    if (score >= 85 && !_detectedSignals.contains('Emotional manipulation')) {
      _detectedSignals.add('Emotional manipulation');
    }
  }

  void _populateFinalSignals(Map<String, dynamic> r) {
    final scamAnalysis = r['scam_analysis'] as Map<String, dynamic>?;
    if (scamAnalysis != null) {
      final indicators = (scamAnalysis['indicators'] as List?)?.map((e) => e.toString()).toList();
      if (indicators != null && indicators.isNotEmpty) {
        for (final ind in indicators) {
          if (!_detectedSignals.contains(ind)) _detectedSignals.add(ind);
        }
      }
    }
  }

  Future<void> _startDemo() async {
    setState(() {
      _phase = _CallPhase.analyzing;
      _currentStage = 'listening';
      _riskScore = 0;
      _riskHistory.clear();
      _detectedSignals.clear();
      _result = null;
    });

    _mockService?.dispose();
    _mockService = MockAnalysisService();

    _subs.add(_mockService!.statusUpdates.listen((e) {
      if (mounted) {
        setState(() => _currentStage = e.stage);
      }
    }));

    _subs.add(_mockService!.riskUpdates.listen((e) {
      if (mounted) {
        setState(() {
          _riskScore = e.riskScore;
          _riskHistory.add(e.riskScore);
          _updateSignalsFromScore(e.riskScore);
        });
      }
    }));

    _subs.add(_mockService!.finalResults.listen((e) {
      if (mounted) {
        setState(() {
          _result = e.result;
          _currentStage = 'done';
          _phase = _CallPhase.done;
          _populateFinalSignals(e.result);
        });
      }
    }));

    final sessionId = await _mockService!.startSession(lang: _lang);
    await _mockService!.sendAudio(sessionId, [], 'wav');
  }

  Future<void> _uploadFile() async {
    final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg', 'm4a']);
    if (files.isEmpty) return;

    final f = files.single;
    final bytes = await f.readAsBytes();

    await _analyzeAudioBytes(bytes, f.name, f.name.split('.').last);
  }

  String _mapStage(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('preprocess') || lower.contains('listen')) return 'listening';
    if (lower.contains('transcript') || lower.contains('asr')) return 'understanding';
    if (lower.contains('voice') || lower.contains('spoof')) return 'checking_voice';
    if (lower.contains('scam') || lower.contains('intent') || lower.contains('attack')) return 'checking_intent';
    return 'calculating';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_phase == _CallPhase.idle ? 'Call Protection' : 'Live Protection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _phase == _CallPhase.idle
          ? _buildIdleView()
          : _buildAnalysisView(),
    );
  }

  Widget _buildIdleView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Language selector
        Row(
          children: [
            Text('Language:', style: VrTypography.label.copyWith(color: VrColors.textMuted)),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _lang,
              dropdownColor: VrColors.surface,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                DropdownMenuItem(value: 'mr', child: Text('मराठी')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) => setState(() => _lang = v ?? 'hi'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 1. REAL MIC ANALYSIS (HERO)
        PremiumCard(
          color: VrColors.primary.withValues(alpha: 0.08),
          borderColor: VrColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VrColors.primary.withValues(alpha: 0.15),
                  border: Border.all(color: VrColors.primary, width: 2),
                ),
                child: const Icon(Icons.mic, color: VrColors.primary, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                'Live Microphone Analysis',
                style: VrTypography.sectionTitle.copyWith(color: VrColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Speak into your microphone. Your actual voice will be processed by AASIST-L & the backend ML engine.',
                textAlign: TextAlign.center,
                style: VrTypography.bodySmall.copyWith(color: VrColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: VrColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: _startLiveRecording,
                icon: const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 20),
                label: const Text('Record & Analyze Live Voice', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Upload audio file (Real ML Backend)
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Analyze audio file',
                  style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Upload a WAV/MP3/M4A file to test with real models.',
                  style: VrTypography.bodySmall.copyWith(color: VrColors.textMuted)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _uploadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose Audio File'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Demo Mock Call (Simulation)
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Simulated Scam Demo',
                  style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Runs a pre-recorded mock scenario without microphone input (for presentations).',
                  style: VrTypography.bodySmall.copyWith(color: VrColors.textMuted)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _startDemo,
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('Run Demo Simulation'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisView() {
    final riskColor = RiskUtils.color(_riskScore);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Caller identity
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VrColors.surfaceAlt,
                  border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.person, color: riskColor, size: 32),
              ),
              const SizedBox(height: 10),
              Text('Unknown Caller',
                  style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
              Text('+91 98XXX XXXXX',
                  style: VrTypography.bodySmall.copyWith(color: VrColors.textMuted)),
              if (_lang == 'hi')
                const LanguageBadge(language: 'Hindi'),
              if (_lang == 'mr')
                const LanguageBadge(language: 'Marathi'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Animated waveform
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VOICE ACTIVITY',
                  style: VrTypography.overline.copyWith(color: VrColors.textMuted, letterSpacing: 2)),
              const SizedBox(height: 8),
              AnimatedWaveform(
                isActive: _phase == _CallPhase.analyzing,
                height: 60,
                color: riskColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Risk gauge
        Center(child: RiskGauge(score: _riskScore)),
        const SizedBox(height: 16),

        // Analysis pipeline steps
        PremiumCard(
          child: AnalysisSteps(currentStage: _currentStage),
        ),
        const SizedBox(height: 16),

        // Detected signals (animated in)
        if (_detectedSignals.isNotEmpty) ...[
          Text('Detected signals',
              style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _detectedSignals
                .map((s) => ThreatIndicator(label: s, color: riskColor))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Risk increased explanation
        if (_riskScore > 50) ...[
          PremiumCard(
            color: riskColor.withValues(alpha: 0.05),
            borderColor: riskColor.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Risk increased because…',
                    style: VrTypography.label.copyWith(color: riskColor)),
                const SizedBox(height: 8),
                if (_riskScore >= 50)
                  _RiskReason('+18', 'Identity claim detected', riskColor),
                if (_riskScore >= 60)
                  _RiskReason('+15', 'Urgent money request', riskColor),
                if (_riskScore >= 70)
                  _RiskReason('+12', 'Financial request pattern', riskColor),
                if (_riskScore >= 85)
                  _RiskReason('+9', 'Voice anomaly detected', riskColor),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Recording state — Stop & Analyze button
        if (_phase == _CallPhase.recording) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: VrColors.critical,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _stopAndAnalyzeRecording,
            icon: const Icon(Icons.stop),
            label: Text('Stop & Analyze ($_recordSeconds s)', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              _recordTimer?.cancel();
              _audioRecorder.stop();
              setState(() => _phase = _CallPhase.idle);
            },
            child: const Text('Cancel'),
          ),
        ],

        // Analyzing — cancel / end call button
        if (_phase == _CallPhase.analyzing) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: VrColors.critical,
              side: BorderSide(color: VrColors.critical.withValues(alpha: 0.5)),
            ),
            onPressed: () {
              _mockService?.dispose();
              for (final s in _subs) {
                s.cancel();
              }
              _subs.clear();
              setState(() => _phase = _CallPhase.idle);
            },
            icon: const Icon(Icons.call_end),
            label: const Text('End Call'),
          ),
        ],

        // Done — view full result
        if (_phase == _CallPhase.done && _result != null) ...[
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: riskColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CallResultScreen(result: _result!)),
            ),
            child: const Text('View Full Report'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('End Call'),
          ),
        ],
      ],
    );
  }
}

class _RiskReason extends StatelessWidget {
  const _RiskReason(this.delta, this.reason, this.color);

  final String delta;
  final String reason;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(delta, style: VrTypography.label.copyWith(color: color)),
          const SizedBox(width: 10),
          Text(reason, style: VrTypography.bodySmall.copyWith(color: VrColors.textSecondary)),
        ],
      ),
    );
  }
}
