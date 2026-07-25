import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/participant.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'student_session_screen.dart';

// ── 세션 코드 입력 화면 ───────────────────────────────────────────────────
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codeController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6자리 세션 코드를 입력해주세요')),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final auth = context.read<AuthService>();
      await auth.signInAnonymously();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProfileScreen(sessionCode: code),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('참여 실패: $e')),
      );
      setState(() => _isJoining = false);
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code != null && mounted) {
      _codeController.text = code;
      _join();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            children: [
              TextSpan(text: '모아', style: TextStyle(color: Colors.white)),
              TextSpan(text: '말', style: TextStyle(color: kYellow)),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '세션 코드를 입력해 참여하세요',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: kInk),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 32,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          color: kInk),
                      maxLength: 6,
                      decoration: const InputDecoration(
                        hintText: 'XXXXXX',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _join(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isJoining ? null : _join,
                      child: _isJoining
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('참여하기', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _isJoining ? null : _scanQr,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('QR 코드로 참여'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 번호 · 이름 입력 화면 ─────────────────────────────────────────────────
class StudentProfileScreen extends StatefulWidget {
  final String sessionCode;

  const StudentProfileScreen({super.key, required this.sessionCode});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _isEntering = false;

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final numberText = _numberController.text.trim();
    final name = _nameController.text.trim();

    final number = int.tryParse(numberText);
    if (number == null || number <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('번호를 올바르게 입력해주세요')),
      );
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _isEntering = true);

    try {
      final auth = context.read<AuthService>();
      final repo = context.read<FirebaseMoamalRepository>();

      final participant = Participant(
        uid: auth.currentUid!,
        number: number,
        name: name,
        joinedAt: DateTime.now(),
      );
      await repo.joinSession(widget.sessionCode, participant);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentSessionScreen(sessionCode: widget.sessionCode),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('입장 실패: $e')),
      );
      setState(() => _isEntering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            children: [
              TextSpan(text: '모아', style: TextStyle(color: Colors.white)),
              TextSpan(text: '말', style: TextStyle(color: kYellow)),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '번호와 이름을 입력하세요',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: kInk),
                    textAlign: TextAlign.center,
                  ),
                    const SizedBox(height: 8),
                    Text(
                      '세션 코드: ${widget.sessionCode}',
                      style: const TextStyle(fontSize: 13, color: Colors.black38),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: _numberController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: kInk,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              counterText: '',
                            ),
                            onSubmitted: (_) => _nameFocus.requestFocus(),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '번',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: kInk),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: kInk,
                            ),
                            decoration: const InputDecoration(
                              hintText: '이름',
                              counterText: '',
                            ),
                            onSubmitted: (_) => _enter(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _isEntering ? null : _enter,
                      child: _isEntering
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('입장하기', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── QR 스캔 화면 ─────────────────────────────────────────────────────────
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR 코드 스캔'),
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_detected) return;
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw == null) return;
              final code = raw.trim().toUpperCase();
              if (code.length == 6) {
                _detected = true;
                Navigator.pop(context, code);
              }
            },
          ),
          Center(
            child: Builder(builder: (ctx) {
              final d = (MediaQuery.sizeOf(ctx).width * 0.6).clamp(180.0, 280.0);
              return Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }),
          ),
          const Align(
            alignment: Alignment(0, 0.55),
            child: Text(
              '교사 화면의 QR 코드를 사각형 안에 맞춰주세요',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
