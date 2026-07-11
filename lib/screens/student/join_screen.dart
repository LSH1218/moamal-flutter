import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'student_session_screen.dart';

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
          builder: (_) => StudentSessionScreen(sessionCode: code),
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
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                  : const Text('참여하기',
                      style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
