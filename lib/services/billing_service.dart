// Billing service — Google Play subscriptions via in_app_purchase.
//
// Products (configure identically in Play Console):
//   pro_monthly : 15 SAR / month
//   pro_yearly  : 120 SAR / year
//
// PRO state is persisted in the encrypted Hive box (`pro_until` timestamp),
// so purchases survive reinstalls and work offline. Always also wire
// server-side receipt validation for a real production release.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../utils/constants.dart';
import 'hive_service.dart';

class BillingService {
  BillingService() {
    _iap.purchaseStream.listen(
      _onPurchases,
      onDone: () {},
      onError: (Object e) {/* stream closed */},
    );
  }

  final InAppPurchase _iap = InAppPurchase.instance;

  final StreamController<List<ProductDetails>> _productsCtrl =
      StreamController<List<ProductDetails>>.broadcast();
  Stream<List<ProductDetails>> get productsStream => _productsCtrl.stream;

  List<ProductDetails> _products = <ProductDetails>[];
  List<ProductDetails> get products => _products;

  bool _available = false;
  bool get available => _available;

  /// Connects to the store and loads subscription products.
  Future<void> init() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      final ProductDetailsResponse res =
          await _iap.queryProductDetails(IapIds.all);
      if (res.notFoundIDs.isNotEmpty) {
        // Products not yet configured in Play Console — expected in dev.
      }
      _products = res.productDetails;
      _productsCtrl.add(_products);
    } catch (_) {
      _available = false;
    }
  }

  String priceOf(String productId) {
    for (final ProductDetails p in _products) {
      if (p.id == productId) return p.price;
    }
    return productId == IapIds.monthly
        ? '${PlanLimits.monthlyPriceSar.toStringAsFixed(0)} ر.س'
        : '${PlanLimits.yearlyPriceSar.toStringAsFixed(0)} ر.س';
  }

  /// Starts a non-consumable/subscription purchase flow.
  Future<bool> purchase(String productId) async {
    try {
      if (!_available) return false;
      final ProductDetails? details = _products
          .where((ProductDetails p) => p.id == productId)
          .firstOrNull;
      if (details == null) return false;
      final PurchaseParam param = PurchaseParam(productDetails: details);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  /// Restores previous purchases (Play requires exposing this in the UI).
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  // ------------------------------------------------------------------

  /// Handles the purchase stream: grants PRO, completes pending purchases.
  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _grantPro(p.productID);
      }
      if (p.status == PurchaseStatus.pending) continue;
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  Future<void> _grantPro(String productId) async {
    final DateTime now = DateTime.now();
    final DateTime until = productId == IapIds.yearly
        ? DateTime(now.year + 1, now.month, now.day)
        : DateTime(now.year, now.month + 1, now.day);
    await HiveService.setProUntil(until);
  }

  /// Manual re-check (app start): keeps the cached PRO flag honest.
  static bool revalidatePro() => HiveService.isProCached();

  void dispose() {
    _productsCtrl.close();
  }
}

/// Riverpod provider — a single app-wide BillingService instance.
final Provider<BillingService> billingProvider = Provider<BillingService>((Ref ref) {
  final BillingService service = BillingService();
  ref.onDispose(service.dispose);
  return service;
});
