// Forgot password: sends a Firebase reset email.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuthService.sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
      Fluttertoast.showToast(msg: 'تم إرسال رابط الاستعادة لبريدك 📩');
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: authErrorAr(e.code));
    } catch (_) {
      Fluttertoast.showToast(msg: 'تعذر الإرسال، حاول لاحقاً');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: <Widget>[
              const SizedBox(height: 24),
              const Icon(Icons.lock_reset_outlined,
                  size: 72, color: AppColors.navy),
              const SizedBox(height: 16),
              const Text(
                'اكتب بريدك الإلكتروني وسنرسل لك رابط إعادة تعيين كلمة المرور.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, height: 1.6),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                enabled: !_sent,
                decoration: const InputDecoration(
                  hintText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: _sent ? 'تم الإرسال ✅' : 'إرسال الرابط',
                loading: _busy,
                onPressed: _sent ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
