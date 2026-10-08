// Form validators + Arabic Firebase error mapping.

abstract final class Validators {
  static String? email(String? v) {
    final String value = v?.trim() ?? '';
    if (value.isEmpty) return 'من فضلك أدخل البريد الإلكتروني';
    final RegExp re = RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w.\-]+$');
    if (!re.hasMatch(value)) return 'البريد الإلكتروني غير صحيح';
    return null;
  }

  static String? password(String? v) {
    final String value = v ?? '';
    if (value.isEmpty) return 'من فضلك أدخل كلمة المرور';
    if (value.length < 6) return 'كلمة المرور ٦ أحرف على الأقل';
    return null;
  }

  static String? name(String? v) {
    final String value = v?.trim() ?? '';
    if (value.isEmpty) return 'من فضلك أدخل الاسم';
    if (value.length < 3) return 'الاسم قصير جداً';
    return null;
  }

  static String? phone(String? v) {
    final String value = v?.trim() ?? '';
    if (value.isEmpty) return 'من فضلك أدخل رقم الهاتف';
    if (!RegExp(r'^\d{8,15}$').hasMatch(value)) return 'رقم الهاتف غير صحيح';
    return null;
  }

  static String? amount(String? v) {
    final String value = v?.trim() ?? '';
    if (value.isEmpty) return 'من فضلك أدخل المبلغ';
    final double? parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null || parsed <= 0) return 'المبلغ غير صحيح';
    if (parsed > 999999999) return 'المبلغ كبير جداً';
    return null;
  }
}

/// Maps FirebaseAuthException codes to friendly Arabic messages.
String authErrorAr(String code) {
  switch (code) {
    case 'invalid-email':
      return 'البريد الإلكتروني غير صحيح';
    case 'user-disabled':
      return 'هذا الحساب معطل';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'البريد أو كلمة المرور غير صحيحة';
    case 'email-already-in-use':
      return 'هذا البريد مستخدم بالفعل — سجل الدخول';
    case 'weak-password':
      return 'كلمة المرور ضعيفة (٦ أحرف على الأقل)';
    case 'too-many-requests':
      return 'محاولات كثيرة، انتظر قليلاً ثم حاول';
    case 'network-request-failed':
      return 'لا يوجد اتصال بالإنترنت';
    case 'invalid-verification-code':
      return 'كود التحقق غير صحيح';
    case 'invalid-phone-number':
      return 'رقم الهاتف غير صحيح';
    case 'operation-not-allowed':
      return 'طريقة الدخول غير مفعّلة في Firebase Console';
    default:
      return 'حدث خطأ، حاول مرة أخرى';
  }
}
