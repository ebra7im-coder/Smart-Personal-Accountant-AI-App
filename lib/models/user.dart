import 'package:hive/hive.dart';

part 'user.g.dart';

/// App-level user profile. An anonymous (guest) user keeps [isGuest] = true.
@HiveType(typeId: 10)
class User extends HiveObject {
  @HiveField(0)
  final String uid;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final bool isGuest;

  @HiveField(4)
  bool isPro;

  /// ISO date until which the PRO subscription is active (trial included).
  @HiveField(5)
  String? proUntil;

  @HiveField(6)
  final String currency;

  User({
    required this.uid,
    required this.name,
    required this.email,
    required this.isGuest,
    this.isPro = false,
    this.proUntil,
    this.currency = 'ج.م',
  });

  bool get isProActive =>
      isPro &&
      (proUntil == null ||
          DateTime.tryParse(proUntil!) == null ||
          DateTime.parse(proUntil!).isAfter(DateTime.now()));

  User copyWith({
    String? uid,
    String? name,
    String? email,
    bool? isGuest,
    bool? isPro,
    String? proUntil,
    String? currency,
  }) =>
      User(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        email: email ?? this.email,
        isGuest: isGuest ?? this.isGuest,
        isPro: isPro ?? this.isPro,
        proUntil: proUntil ?? this.proUntil,
        currency: currency ?? this.currency,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'uid': uid,
        'name': name,
        'email': email,
        'isGuest': isGuest,
        'isPro': isPro,
        'proUntil': proUntil,
        'currency': currency,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        uid: (map['uid'] ?? '') as String,
        name: (map['name'] ?? 'مستخدم') as String,
        email: (map['email'] ?? '') as String,
        isGuest: (map['isGuest'] ?? false) as bool,
        isPro: (map['isPro'] ?? false) as bool,
        proUntil: map['proUntil'] as String?,
        currency: (map['currency'] ?? 'ج.م') as String,
      );
}
