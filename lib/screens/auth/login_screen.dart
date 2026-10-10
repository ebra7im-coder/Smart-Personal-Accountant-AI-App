// Login screen: email/password + Google + phone (OTP) + guest mode.

import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, UserCredential;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../models/user.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import 'phone_login_sheet.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _setUserAndGoHome(User profile) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.onboardingSeen, true);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final UserCredential cred = await FirebaseAuthService.signInWithEmail(
          _emailCtrl.text.trim(), _passCtrl.text);
      await _setUserAndGoHome(_profileFromCred(cred));
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: authErrorAr(e.code));
    } catch (_) {
      Fluttertoast.showToast(msg: 'تعذر الاتصال بالخادم، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  User _profileFromCred(UserCredential cred) => User(
        uid: cred.user?.uid ?? 'local',
        name: cred.user?.displayName ??
            (cred.user?.email ?? 'مستخدم').split('@').first,
        email: cred.user?.email ?? '',
        isGuest: false,
      );

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      final UserCredential cred = await FirebaseAuthService.signInWithGoogle();
      await _setUserAndGoHome(_profileFromCred(cred));
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: authErrorAr(e.code));
    } catch (_) {
      Fluttertoast.showToast(msg: 'تعذر تسجيل الدخول بجوجل (تحقق من الإعداد)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guest() async {
    setState(() => _busy = true);
    try {
      final UserCredential cred = await FirebaseAuthService.signInAsGuest();
      await _setUserAndGoHome(User(
        uid: cred.user?.uid ?? 'guest',
        name: 'زائر',
        email: '',
        isGuest: true,
      ));
    } catch (_) {
      // Local-only fallback: continue offline with a device-local profile.
      await _setUserAndGoHome(User(
        uid: 'guest',
        name: 'زائر',
        email: '',
        isGuest: true,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Image.asset(
                    'assets/images/app_icon.png',
                    width: 88,
                    height: 88,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'أهلاً بعودتك 👋',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                    decoration: const InputDecoration(
                      hintText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    validator: Validators.password,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.forgotPassword),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomButton(
                    label: 'تسجيل الدخول',
                    loading: _busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),
                  const _OrDivider(),
                  const SizedBox(height: 20),
                  _SocialButton(
                    icon: Icons.g_mobiledata_outlined,
                    label: 'الدخول بحساب جوجل',
                    onPressed: _google,
                  ),
                  _SocialButton(
                    icon: Icons.phone_outlined,
                    label: 'الدخول برقم الهاتف',
                    onPressed: () => PhoneLoginSheet.show(context),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _guest,
                    child: const Text('المتابعة كزائر (وضع بدون اتصال)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text('ما عندك حساب؟',
                          style: TextStyle(color: AppColors.textGrey)),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRoutes.register),
                        child: const Text('إنشاء حساب'),
                      ),
                    ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('أو', style: TextStyle(color: AppColors.textHint)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(
      {required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
        icon: Icon(icon, size: 26),
        label: Text(label),
      ),
    );
  }
}
