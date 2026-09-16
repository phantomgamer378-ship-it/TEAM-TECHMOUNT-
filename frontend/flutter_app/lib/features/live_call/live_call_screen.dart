import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';
import '../../services/api_client.dart';
import '../../services/mock_analysis_service.dart';
import '../../services/analysis_service.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'widgets/waveform_painter.dart';
import 'widgets/risk_gauge.dart';
import 'widgets/analysis_steps.dart';
import 'call_result_screen.dart';

/// Live Call Screen — THE HERO EXPERIENCE.
///
/// The user can either:
/// 1. Upload an audio file for analysis (real backend)
/// 2. Start a simulated demo call (mock service)
///
/// Shows: caller identity, animated waveform, analysis pipeline steps,
/// dynamic risk gauge, detected threat signals.
class LiveCallScreen extends StatefulWidget {
  const LiveCallScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

enum _CallPhase { idle, analyzing, done }

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
          // Add detected signals based on risk level
          if (e.riskScore >= 50 && !_detectedSignals.contains('AI voice indicators')) {
            _detectedSignals.add('AI voice indicators');
          }
          if (e.riskScore >= 60 && !_detectedSignals.contains('Urgent money request')) {
            _detectedSignals.add('Urgent money request');
          }
          if (e.riskScore >= 70 && !_detectedSignals.contains('Identity claim')) {
            _detectedSignals.add('Identity claim');
          }
          if (e.riskScore >= 85 && !_detectedSignals.contains('Emotional manipulation')) {
            _detectedSignals.add('Emotional manipulation');
          }
        });
      }
    }));

    _subs.add(_mockService!.finalResults.listen((e) {
      if (mounted) {
        setState(() {
          _result = e.result;
          _currentStage = 'done';
          _phase = _CallPhase.done;
        });
      }
    }));

    final sessionId = await _mockService!.startSession(lang: _lang);
    await _mockService!.sendAudio(sessionId, [], 'wav');
  }

  Future<void> _uploadFile() async {
    final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg']);
    if (files.isEmpty) return;

    final f = files.single;
    final bytes = await f.readAsBytes();

    setState(() {
      _phase = _CallPhase.analyzing;
      _currentStage = 'listening';
      _riskScore = 0;
      _riskHistory.clear();
      _detectedSignals.clear();
      _result = null;
    });

    try {
      // Try WebSocket streaming first
      final sessionId = 'vr-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      final channel = widget.api.connectStream(sessionId);

      channel.sink.add(jsonEncode({'type': 'start', 'lang': _lang}));
      channel.sink.add(jsonEncode({
        'type': 'audio',
        'data': base64Encode(bytes),
        'fmt': f.name.split('.').last,
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
            });
          case 'final':
            final r = (msg['response'] as Map).cast<String, dynamic>();
            setState(() {
              _result = r;
              _phase = _CallPhase.done;
              _currentStage = 'done';
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
        final r = await widget.api.uploadAudio(bytes: bytes, filename: f.name, lang: _lang);
        if (mounted) {
          setState(() {
            _result = r as Map<String, dynamic>;
            _phase = _CallPhase.done;
            _currentStage = 'done';
            final riskScore = (r['risk'] as Map?)?['score'] as int?;
            if (riskScore != null) _riskScore = riskScore;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _phase = _CallPhase.idle);
      }
    }
  }

  String _mapStage(String msg) {
    if (msg.contains('listen')) return 'listening';
    if (msg.contains('transcript') || msg.contains('ASR')) return 'understanding';
    if (msg.contains('voice') || msg.contains('spoof')) return 'checking_voice';
    if (msg.contains('scam') || msg.contains('intent')) return 'checking_intent';
    return 'calculating';
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _mockService?.dispose();
    super.dispose();
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

        // Hero — Start Simulated Call
        PremiumCard(
          color: VrColors.primary.withValues(alpha: 0.04),
          borderColor: VrColors.primary.withValues(alpha: 0.2),
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VrColors.primary.withValues(alpha: 0.1),
                  border: Border.all(color: VrColors.primary.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.phone_in_talk, color: VrColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Start Simulated Call',
                style: VrTypography.sectionTitle.copyWith(color: VrColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Experience the live threat detection pipeline with a simulated scam call scenario.',
                textAlign: TextAlign.center,
                style: VrTypography.bodySmall.copyWith(color: VrColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _startDemo,
                child: const Text('Start Demo Call'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Upload audio file
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Or analyze a recording',
                  style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Upload a WAV/MP3 file to analyze with the real backend.',
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
