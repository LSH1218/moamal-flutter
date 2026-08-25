import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/participant.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/deep_link_service.dart';
import '../../theme/app_theme.dart';
import 'student_session_screen.dart';

const _kRow1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
const _kRow2 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
const _kRow3 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
const _kRow4 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];
const _kKeyboardBg = Color(0xFFE4E0D6);

// ── 세션 코드 입력 화면 ───────────────────────────────────────────────────────
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _chars = <String>[];
  bool _hasError = false;
  bool _isVerifying = false;

  String get _code => _chars.join();

  void _addChar(String c) {
    if (_chars.length >= 6 || _isVerifying) return;
    setState(() {
      _chars.add(c);
      _hasError = false;
    });
  }

  void _del() {
    if (_chars.isEmpty || _isVerifying) return;
    setState(() {
      _chars.removeLast();
      _hasError = false;
    });
  }

  void _clear() {
    if (_isVerifying) return;
    setState(() {
      _chars.clear();
      _hasError = false;
    });
  }

  Future<void> _verify() async {
    if (_chars.length != 6 || _isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      final auth = context.read<AuthService>();
      final repo = context.read<FirebaseMoamalRepository>();
      await auth.signInAnonymously();
      if (!mounted) return;
      final title = await repo.fetchSessionTitle(_code);
      if (!mounted) return;
      if (title == null) {
        setState(() {
          _hasError = true;
          _isVerifying = false;
        });
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProfileScreen(
            sessionCode: _code,
            sessionTitle: title,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code != null && mounted) {
      setState(() {
        _chars
          ..clear()
          ..addAll(code.characters.toList());
        _hasError = false;
      });
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _chars.length == 6 && !_isVerifying && !_hasError;

    return Scaffold(
      backgroundColor: kGround,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: _buildContent(),
              ),
            ),
            _buildNextButton(canNext),
            _buildKeyboard(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 18, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: kBorderMid),
              ),
              child: const Icon(Icons.chevron_left, color: kInk, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '수업 참여',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
          ),
          if (_chars.isNotEmpty)
            GestureDetector(
              onTap: _clear,
              child: const Text(
                '지우기',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Scrollable content ─────────────────────────────────────────────────────

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '선생님이 보여준\n6자리 코드를 넣어요',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1.3,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '칠판 화면의 코드와 똑같이 눌러요',
            style: TextStyle(
              fontSize: 14,
              color: kInk.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 18),
          _buildCodeCells(),
          if (_hasError) ...[
            const SizedBox(height: 12),
            _buildErrorCard(),
          ],
          const SizedBox(height: 18),
          _buildOrDivider(),
          const SizedBox(height: 18),
          _buildQrButton(),
        ],
      ),
    );
  }

  Widget _buildCodeCells() {
    return Row(
      children: [
        for (int i = 0; i < 6; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: AspectRatio(
              aspectRatio: 5 / 6,
              child: _CodeCell(
                char: i < _chars.length ? _chars[i] : null,
                isActive: i == _chars.length && !_hasError,
                isError: _hasError && i < _chars.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF0EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13.5, height: 1.5, color: kInk),
                children: [
                  const TextSpan(text: '이런 코드는 없어요.\n'),
                  TextSpan(
                    text: '칠판 화면을 다시 보고 눌러요',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: kInk.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
              color: kInk.withValues(alpha: 0.12), thickness: 1, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(
                fontSize: 12, color: kInk.withValues(alpha: 0.4)),
          ),
        ),
        Expanded(
          child: Divider(
              color: kInk.withValues(alpha: 0.12), thickness: 1, height: 1),
        ),
      ],
    );
  }

  Widget _buildQrButton() {
    return GestureDetector(
      onTap: _scanQr,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGreen, width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, color: kGreen, size: 24),
            SizedBox(width: 11),
            Text(
              'QR 코드 찍기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── [다음] button ──────────────────────────────────────────────────────────

  Widget _buildNextButton(bool canNext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: GestureDetector(
        onTap: canNext ? _verify : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 19),
          decoration: BoxDecoration(
            color: canNext ? kGreen : kDisabled,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _isVerifying
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                )
              : const Text(
                  '다음',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Custom keyboard ────────────────────────────────────────────────────────

  Widget _buildKeyboard() {
    return Container(
      color: _kKeyboardBg,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Column(
        children: [
          _buildKeyRow(_kRow1),
          const SizedBox(height: 7),
          _buildKeyRow(_kRow2),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildKeyRow(_kRow3),
          ),
          const SizedBox(height: 7),
          _buildDelRow(),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: _Key(label: keys[i], onTap: () => _addChar(keys[i])),
          ),
        ],
      ],
    );
  }

  Widget _buildDelRow() {
    return Row(
      children: [
        const Expanded(flex: 3, child: SizedBox()),
        const SizedBox(width: 5),
        for (int i = 0; i < _kRow4.length; i++) ...[
          Expanded(
            flex: 2,
            child: _Key(label: _kRow4[i], onTap: () => _addChar(_kRow4[i])),
          ),
          const SizedBox(width: 5),
        ],
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _del,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: kInk.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                '⌫',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Code cell widget ──────────────────────────────────────────────────────────

class _CodeCell extends StatelessWidget {
  final String? char;
  final bool isActive;
  final bool isError;

  const _CodeCell({this.char, this.isActive = false, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Border border;
    final Color textColor;

    if (isError && char != null) {
      bg = const Color(0xFFFCF0EF);
      border = Border.all(color: kRed.withValues(alpha: 0.3));
      textColor = kRed;
    } else if (char != null) {
      bg = kGround;
      border = Border.all(color: kBorderMid);
      textColor = kInk;
    } else if (isActive) {
      bg = kCardBg;
      border = Border.all(color: kGreen, width: 2);
      textColor = kInk;
    } else {
      bg = kCardBg;
      border = Border.all(color: kBorderMid);
      textColor = kInk;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: border,
      ),
      child: char != null
          ? Center(
              child: Text(
                char!,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  color: textColor,
                ),
              ),
            )
          : null,
    );
  }
}

// ── Keyboard key widget ───────────────────────────────────────────────────────

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Key({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: kInk,
          ),
        ),
      ),
    );
  }
}

// ── 번호 · 이름 입력 화면 ─────────────────────────────────────────────────────
class StudentProfileScreen extends StatefulWidget {
  final String sessionCode;
  final String sessionTitle;

  const StudentProfileScreen({
    super.key,
    required this.sessionCode,
    required this.sessionTitle,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _numberFocus = FocusNode();
  final _nameFocus = FocusNode();
  bool _isEntering = false;

  @override
  void initState() {
    super.initState();
    _numberFocus.addListener(() => setState(() {}));
    _nameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _numberFocus.dispose();
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StudentSessionScreen(sessionCode: widget.sessionCode),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildConfirmCard(),
                    const SizedBox(height: 20),
                    const Text(
                      '누구인지 알려주세요',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.12,
                        height: 1.3,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildNumberField(),
                    const SizedBox(height: 10),
                    _buildNameField(),
                    const SizedBox(height: 14),
                    Text(
                      '번호와 이름은 선생님 화면에만 보여요.\n친구들 화면에는 보이지 않아요.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: kInk.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 26),
              child: GestureDetector(
                onTap: _isEntering ? null : _enter,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 19),
                  decoration: BoxDecoration(
                    color: kGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _isEntering
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          ),
                        )
                      : const Text(
                          '들어가기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 18, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: kBorderMid),
              ),
              child: const Icon(Icons.chevron_left, color: kInk, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '수업 참여',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: kGreen,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check, color: Colors.white, size: 14),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13.5, color: kInk),
                children: [
                  TextSpan(
                    text: widget.sessionTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '\n코드 ${widget.sessionCode} 확인됐어요',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: kInk.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '번호',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kInk.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _numberFocus.hasFocus ? kGreen : kBorderDark,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _numberController,
                  focusNode: _numberFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.52,
                    color: kInk,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _nameFocus.requestFocus(),
                ),
              ),
              Text(
                '번',
                style: TextStyle(
                  fontSize: 15,
                  color: kInk.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '이름',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kInk.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _nameFocus.hasFocus ? kGreen : kBorderDark,
              width: 2,
            ),
          ),
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '이름을 입력해요',
              hintStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kInk.withValues(alpha: 0.3),
              ),
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _enter(),
          ),
        ),
      ],
    );
  }
}

// ── QR 스캔 화면 ─────────────────────────────────────────────────────────────
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
      backgroundColor: kInk,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_detected) return;
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw == null) return;
              // 딥링크(moamal://join/XXXXXX)와 평문 6자리를 모두 받는다.
              final code = DeepLinkService.parseScanned(raw);
              if (code != null) {
                _detected = true;
                Navigator.pop(context, code);
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 18, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'QR 코드 스캔',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Builder(builder: (ctx) {
                      final d = (MediaQuery.sizeOf(ctx).width * 0.6)
                          .clamp(180.0, 280.0);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: d,
                            height: d,
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: kYellow, width: 2.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '교사 화면의 QR 코드를 사각형 안에 맞춰주세요',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
