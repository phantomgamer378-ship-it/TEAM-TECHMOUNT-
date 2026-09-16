import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
// file_picker 12.x: pickFiles lives on FilePickerPlatform.instance.
import 'package:file_picker/file_picker.dart';

import 'api_client.dart';
import 'result_view.dart';
import 'vcs_theme.dart';
import 'widgets.dart';

/// Call Analysis — the MAIN demo screen (§16): pick/upload an audio file,
/// stream Risk(t) live over WebSocket (one update per second), then show the
/// full canonical result. Also the liveness verify flow.
class CallAnalysisView extends StatefulWidget {
  const CallAnalysisView({super.key, required this.api});

  final ApiClient api;

  @override
  State<CallAnalysisView> createState() => _CallAnalysisViewState();
}

enum _Phase { idle, uploading, streaming, verifying, done }

class _CallAnalysisViewState extends State<CallAnalysisView> {
  _Phase _phase = _Phase.idle;
  String _lang = 'hi';
  String _status = '';
  List<int> _liveScores = [];
  Map<String, dynamic>? _result;
  String? _sessionId;

  Timer? _bailout; // if WS stalls, fall back to plain HTTP upload

  Future<void> _pickAndAnalyze() async {
    final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'ogg']);
    if (files.isEmpty) return;
    final f = files.single;
    final bytes = await f.readAsBytes();
    setState(() {
      _phase = _Phase.uploading;
      _status = 'uploading ${f.name}…';
      _liveScores = [];
      _result = null;
    });

    try {
      await _streamAnalysis(bytes, f.name);
    } catch (_) {
      // WS unavailable → plain HTTP path (same pipeline, same contract).
      setState(() => _status = 'WebSocket unavailable — using HTTP upload…');
      final r = await widget.api.uploadAudio(
          bytes: bytes, filename: f.name, lang: _lang);
      setState(() {
        _result = r;
        _phase = _Phase.done;
        _sessionId = r['session_id']?.toString();
        _liveScores = ((r['risk_timeline'] as List?)
                    ?.map((e) => ((e as Map)['risk_score'] ?? 0) as int)
                    .toList()) ??
                [];
      });
    }
  }

  /// §12 protocol: start → audio(base64) → end; then consume
  /// status / risk_update / final events.
  Future<void> _streamAnalysis(List<int> bytes, String name) async {
    final sessionId =
        'flutter-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final channel = widget.api.connectStream(sessionId);
    setState(() => _phase = _Phase.streaming);

    _bailout = Timer(const Duration(seconds: 240), () {
      try {
        channel.sink.close();
      } catch (_) {}
    });

    channel.sink.add(jsonEncode({'type': 'start', 'lang': _lang}));
    channel.sink.add(jsonEncode({
      'type': 'audio',
      'data': b64Encode(bytes),
      'fmt': name.split('.').last,
    }));
    channel.sink.add(jsonEncode({'type': 'end'}));

    await for (final raw in channel.stream) {
      if (!mounted) break;
      final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'status':
          setState(() => _status = msg['message'].toString());
        case 'risk_update':
          setState(() {
            _liveScores.add((msg['risk_score'] ?? 0) as int);
            _status = 'live risk: ${msg['risk_score']}/100 (${msg['level']})';
          });
        case 'final':
          setState(() {
            _result = (msg['response'] as Map).cast<String, dynamic>();
            _sessionId = sessionId;
            _phase = _Phase.done;
          });
          await channel.sink.close();
          _bailout?.cancel();
          return;
        case 'error':
          setState(() {
            _status = 'error: ${msg['error']}';
            _phase = _Phase.done;
          });
          await channel.sink.close();
          _bailout?.cancel();
          return;
      }
    }
  }

  Future<void> _verifyLiveness(String spoken) async {
    if (_sessionId == null) return;
    setState(() => _phase = _Phase.verifying);
    final r = await widget.api
        .post('/api/liveness/verify', {'session_id': _sessionId, 'spoken_text': spoken});
    setState(() => _phase = _Phase.done);
    if (!mounted) return;
    final status = r['status']?.toString() ?? '?';
    final color = status == 'PASSED' ? VcsTheme.good : VcsTheme.danger;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: VcsTheme.card,
        content: Text('Liveness: $status',
            style: TextStyle(color: color, fontWeight: FontWeight.w700))));
  }

  @override
  void dispose() {
    _bailout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.uploading || _phase == _Phase.streaming;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          title: 'Analyse a call recording',
          trailing: DropdownButton<String>(
            value: _lang,
            dropdownColor: VcsTheme.card,
            items: const [
              DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
              DropdownMenuItem(value: 'mr', child: Text('मराठी')),
            ],
            onChanged: busy ? null : (v) => setState(() => _lang = v ?? 'hi'),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'Pick a WAV/MP3 clip — the risk timeline streams LIVE over '
                'WebSocket while the file is analysed, then the full verdict '
                'appears. (Mic recording and WebRTC are future phases.)',
                style: TextStyle(color: VcsTheme.textDim, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : _pickAndAnalyze,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: Text(busy ? _status : 'Choose audio file'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (_liveScores.isNotEmpty || _phase == _Phase.streaming)
          Panel(
            title: 'Risk timeline (live)',
            trailing: Text('${_liveScores.length} updates',
                style: const TextStyle(color: VcsTheme.textDim, fontSize: 12)),
            child:
                RiskTimelineChart(scores: _liveScores, height: 150),
          ),
        const SizedBox(height: 14),
        if (_result != null)
          Panel(title: 'Verdict', child: AnalysisResultView(result: _result)),
        if (_result?['liveness']?['required'] == true &&
            _sessionId != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Panel(
              title: 'Liveness verification',
              child: Column(children: [
                const Text(
                    'Ask the caller to say the challenge phrase, then submit '
                    'what they said (prototype: text match).',
                    style: TextStyle(color: VcsTheme.textDim, fontSize: 12)),
                const SizedBox(height: 10),
                _LivenessForm(onSubmit: _verifyLiveness),
              ]),
            ),
          ),
      ],
    );
  }
}

class _LivenessForm extends StatefulWidget {
  const _LivenessForm({required this.onSubmit});

  final Future<void> Function(String) onSubmit;

  @override
  State<_LivenessForm> createState() => _LivenessFormState();
}

class _LivenessFormState extends State<_LivenessForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'spoken response…'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
            onPressed: () async {
              await widget.onSubmit(_controller.text);
            },
            child: const Text('Verify')),
      ]);
}
