import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  // 교사 자격 신청 구글폼 URL — 실제 폼 만든 후 교체
  static const _formUrl = 'https://forms.gle/TODO';

  Future<void> _retry(BuildContext context) async {
    final auth = context.read<AuthService>();
    try {
      final access = await auth.checkTeacherAccess();
      if (!context.mounted) return;
      if (access == TeacherAccessResult.approved) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('아직 승인되지 않았습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<AuthService>();
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded,
                        size: 36, color: kGreen),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '교사 자격 확인 대기 중',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '교육청·학교 이메일이 아닌 계정으로 로그인하셨습니다.\n아래 신청 버튼을 눌러 교사 자격을 신청해 주세요.\n승인 후 다시 로그인하면 바로 입장하실 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: url_launcher 패키지로 _formUrl 열기
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('신청 폼 URL을 설정해 주세요.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '교사 자격 신청하기',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => _retry(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '승인 확인 (승인 후 탭)',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => _signOut(context),
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.black38, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
