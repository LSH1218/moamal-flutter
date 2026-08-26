import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/participant.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/deep_link_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'student_session_screen.dart';

const _kRow1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
const _kRow2 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
const _kRow3 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
const _kRow4 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];
const _kKeyboardBg = Color(0xFFE4E0D6);

// ── 세션 코드 입력 화면 ───────────────────────────────────────────────────────
class JoinScreen extends StatefulWidget {
  /// true면 진입 직후 QR 스캐너를 바로 열어준다.
  /// 럜딩의 QR 버튼은 이 경로로 들어온다 — 스캔을 취소하면
  /// 코드 입력 화면에 그대로 남아 수동 입력으로 이어갈 수 있다 (Gemini-1-Join-01).
  final bool autoScan;

  const JoinScreen({super.key, this.autoScan = false});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _chars = <String>[];
  bool _hasError = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanQr();
      });
    }
  }

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 키패드가 고정 높이면 좀은 화면에서 코드 칸과 QR 버튼을
            // 밀어낸다. 가용 높이의 34%를 상한으로 잡고 키 높이를
            // 역산한다 (Gemini-1-Join-02).
            final keyPadV = _keyPadV(constraints.maxHeight);
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildContent(),
                  ),
                ),
                _buildNextButton(canNext),
                _buildKeyboard(keyPadV),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 가용 높이에서 키 1개의 상하 패딩을 역산한다.
  /// 키패드 전체 = 패딩(8+12) + 4행 + 행간 3×7.
  /// 한 행 높이 = 패딩×2 + 글자 높이(≈ 22).
  /// 하한 6dp는 타겟 높이 34dp를 보장하기 위한 값이다.
  double _keyPadV(double maxHeight) {
    const textH = 22.0;
    const chrome = 8 + 12 + 7 * 3; // 패딩 + 행간
    // 320×693dp 기기에서 34%는 padV를 10.2로 내놓아 기존 11과 거의 같았다.
    // 실측 필요 높이 690dp vs 가용 620dp로 70dp가 부족해 예산을 30%로 좀힌다.
    final budget = maxHeight * 0.30 - chrome;
    final rowH = budget / 4;
    return ((rowH - textH) / 2).clamp(6.0, 11.0);
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
    // 320dp에서는 fontSize 30이 제목을 3줄로 밀어 한 줄(≈ 39dp)을 통째로 버린다.
    // 코드 칸이 화면 밖으로 밀려나는 가장 큰 원인이다 (Gemini-1-Join-02).
    final narrow = context.isNarrow;
    final titleSize = narrow ? 24.0 : 30.0;
    final gap = narrow ? 12.0 : 18.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, narrow ? 14 : 22, 20, narrow ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '선생님이 보여준\n6자리 코드를 넣어요',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1.25,
              color: kInk,
            ),
          ),
          SizedBox(height: narrow ? 6 : 8),
          Text(
            '칠판 화면의 코드와 똑같이 눌러요',
            style: TextStyle(
              fontSize: 14,
              color: kInk.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: gap),
          _buildCodeCells(),
          if (_hasError) ...[
            const SizedBox(height: 12),
            _buildErrorCard(),
          ],
          SizedBox(height: gap),
          _buildOrDivider(),
          SizedBox(height: gap),
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
      padding: EdgeInsets.fromLTRB(14, 0, 14, context.isNarrow ? 6 : 10),
      child: GestureDetector(
        onTap: canNext ? _verify : null,
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: context.isNarrow ? 15 : 19),
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

  Widget _buildKeyboard(double padV) {
    return Container(
      color: _kKeyboardBg,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Column(
        children: [
          _buildKeyRow(_kRow1, padV),
          const SizedBox(height: 7),
          _buildKeyRow(_kRow2, padV),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildKeyRow(_kRow3, padV),
          ),
          const SizedBox(height: 7),
          _buildDelRow(padV),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys, double padV) {
    return Row(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: _Key(
                label: keys[i], padV: padV, onTap: () => _addChar(keys[i])),
          ),
        ],
      ],
    );
  }

  Widget _buildDelRow(double padV) {
    return Row(
      children: [
        const Expanded(flex: 3, child: SizedBox()),
        const SizedBox(width: 5),
        for (int i = 0; i < _kRow4.length; i++) ...[
          Expanded(
            flex: 2,
            child: _Key(
                label: _kRow4[i], padV: padV, onTap: () => _addChar(_kRow4[i])),
          ),
          const SizedBox(width: 5),
        ],
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _del,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: padV),
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
  final double padV;

  const _Key({required this.label, required this.onTap, this.padV = 11});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: padV),
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

  /// 일정 시간 인식되지 않으면 수동 입력을 권한다.
  /// 랜딩 QR 버튼이 이 화면으로 직행하므로, 여기서 막히면 학생은
  /// 카메라 화면만 보고 서 있게 된다 (Gemini-1-Join-03).
  static const _hintAfter = Duration(seconds: 8);
  bool _slowHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(_hintAfter, () {
      if (mounted && !_detected) setState(() => _slowHint = true);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _fallbackToCode() {
    _hintTimer?.cancel();
    Navigator.pop(context); // 코드 입력 화면으로 돌아간다
  }

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
                _hintTimer?.cancel();
                Navigator.pop(context, code);
              }
            },
            errorBuilder: (context, error) => _CameraUnavailable(
              onUseCode: _fallbackToCode,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 18, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _fallbackToCode,
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
                            _slowHint
                                ? '잘 안 읽히면 아래에서 코드로 들어갈 수 있어요'
                                : '교사 화면의 QR 코드를 사각형 안에 맞춰주세요',
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
                // 인식이 안 될 때 빠져나갈 길. 좌상단 화살표만으로는
                // 학생이 대안을 찾지 못한다.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                  child: GestureDetector(
                    onTap: _fallbackToCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _slowHint
                            ? kYellow
                            : Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _slowHint
                              ? kYellow
                              : Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_alt_outlined,
                              size: 22,
                              color: _slowHint ? kInk : Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            '코드 직접 입력하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _slowHint ? kInk : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// 카메라를 열 수 없을 때(권한 거부·하드웨어 없음·에뮬레이터 등)
/// 검은 화면 대신 이유와 대안을 보여준다.
class _CameraUnavailable extends StatelessWidget {
  final VoidCallback onUseCode;

  const _CameraUnavailable({required this.onUseCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kInk,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white, size: 44),
          const SizedBox(height: 16),
          const Text(
            '카메라를 열 수 없어요',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '카메라 권한이 꺼져 있거나 사용할 수 없는 기기예요.\n선생님이 보여준 6자리 코드로 들어갈 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onUseCode,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
              decoration: BoxDecoration(
                color: kYellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '코드 직접 입력하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
