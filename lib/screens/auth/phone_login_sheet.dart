// Phone login bottom sheet: send OTP via Firebase, then verify the code.

import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';

class PhoneLoginSheet extends StatefulWidget {
  const PhoneLoginSheet({super.key});

  /// Opens the sheet over the auth screens.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.only(bottom: 0),
        child: PhoneLoginSheet(),
      ),
    );
  }

  @override
  State<PhoneLoginSheet> createState() => _PhoneLoginSheetState();
}

class _PhoneLoginSheetState extends State<PhoneLoginSheet> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final GlobalKey<FormState> _phoneForm = GlobalKey<FormState>();

  String _dialCode = '+20'; // default: Egypt
  String? _verificationId;
  bool _busy = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneForm.currentState!.validate()) return;
    setState(() => _busy = true);
    await FirebaseAuthService.verifyPhone(
      phoneNumber: '$_dialCode${_phoneCtrl.text.trim()}',
      onCodeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _busy = false;
          });
        }
      },
      onAutoVerify: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (_) {}
      },
      onFailed: (FirebaseAuthException e) {
        if (mounted) setState(() => _busy = false);
        Fluttertoast.showToast(msg: authErrorAr(e.code));
      },
    );
    if (mounted && _verificationId == null) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    if (_verificationId == null || _otpCtrl.text.trim().length < 6) {
      Fluttertoast.showToast(msg: 'أدخل الكود المكون من ٦ أرقام');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuthService.verifySmsCode(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: authErrorAr(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _verificationId == null ? 'الدخول برقم الهاتف' : 'أدخل الكود',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 20),
            if (_verificationId == null) ...<Widget>[
              Form(
                key: _phoneForm,
                child: Row(
                  children: <Widget>[
                    // Country selector with flag + dial code.
                    OutlinedButton(
                      onPressed: () => showCountryPicker(
                        context: context,
                        onSelect: (Country c) =>
                            setState(() => _dialCode = '+${c.phoneCode}'),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: Text('$_dialCode ▾'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                        decoration: const InputDecoration(
                          hintText: '10xxxxxxxx',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'إرسال كود التحقق',
                loading: _busy,
                onPressed: _sendOtp,
              ),
            ] else ...<Widget>[
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: '------',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'تحقق ودخول',
                loading: _busy,
                onPressed: _verify,
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
