import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../store/app_store.dart';

/// Non-consumable product id (App Store Connect / StoreKit config).
const kPremiumProductId = 'drive_studio_premium';

/// Purchase / restore surface. Wave 2 fills StoreKit on iOS; web/Windows keep
/// a debug unlock so product flows stay testable without a Mac.
abstract class PurchaseService {
  bool get isAvailable;
  bool get supportsStoreKit;
  String get productId;
  Stream<PurchaseEvent> get events;

  Future<void> init();
  Future<void> dispose();
  Future<PurchaseResult> purchasePremium();
  Future<PurchaseResult> restorePurchases();
  void unlockDebug();
  void lockDebug();
}

enum PurchaseEventKind { unlocked, locked, error, pending }

class PurchaseEvent {
  const PurchaseEvent(this.kind, {this.message});
  final PurchaseEventKind kind;
  final String? message;
}

class PurchaseResult {
  const PurchaseResult({
    required this.ok,
    this.message,
    this.pending = false,
  });
  final bool ok;
  final String? message;
  final bool pending;

  static const success = PurchaseResult(ok: true);
  static PurchaseResult fail(String message) =>
      PurchaseResult(ok: false, message: message);
  static const pendingResult = PurchaseResult(ok: false, pending: true);
}

/// Factory picks StoreKit-backed impl on iOS (non-web), else debug.
PurchaseService createPurchaseService(AppStore store) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return IapPurchaseService(store);
  }
  return DebugPurchaseService(store);
}

/// Web / Windows / Android preview — mirrors Settings debug toggle.
class DebugPurchaseService implements PurchaseService {
  DebugPurchaseService(this._store);

  final AppStore _store;
  final _controller = StreamController<PurchaseEvent>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  bool get supportsStoreKit => false;

  @override
  String get productId => kPremiumProductId;

  @override
  Stream<PurchaseEvent> get events => _controller.stream;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<PurchaseResult> purchasePremium() async {
    unlockDebug();
    return PurchaseResult.success;
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    // Nothing to restore off-StoreKit; leave current flag as-is.
    _controller.add(
      PurchaseEvent(
        _store.isPremium
            ? PurchaseEventKind.unlocked
            : PurchaseEventKind.locked,
        message: 'No App Store purchases on this platform.',
      ),
    );
    return PurchaseResult(
      ok: _store.isPremium,
      message: _store.isPremium
          ? 'Premium already unlocked'
          : 'No purchases to restore on this platform',
    );
  }

  @override
  void unlockDebug() {
    _store.setPremium(true);
    _controller.add(const PurchaseEvent(PurchaseEventKind.unlocked));
  }

  @override
  void lockDebug() {
    _store.setPremium(false);
    _controller.add(const PurchaseEvent(PurchaseEventKind.locked));
  }
}

/// iOS StoreKit bridge via `in_app_purchase`. Requires product configured in
/// App Store Connect + StoreKit config file for local sandbox (Wave 2 Mac).
class IapPurchaseService implements PurchaseService {
  IapPurchaseService(this._store);

  final AppStore _store;
  final InAppPurchase _iap = InAppPurchase.instance;
  final _controller = StreamController<PurchaseEvent>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;
  ProductDetails? _product;

  @override
  bool get isAvailable => _available;

  @override
  bool get supportsStoreKit => true;

  @override
  String get productId => kPremiumProductId;

  @override
  Stream<PurchaseEvent> get events => _controller.stream;

  @override
  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      _controller.add(
        const PurchaseEvent(
          PurchaseEventKind.error,
          message: 'StoreKit unavailable',
        ),
      );
      return;
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        _controller.add(
          PurchaseEvent(PurchaseEventKind.error, message: e.toString()),
        );
      },
    );
    final response = await _iap.queryProductDetails({kPremiumProductId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
    }
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != kPremiumProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _store.setPremium(true);
          _controller.add(const PurchaseEvent(PurchaseEventKind.unlocked));
          if (p.pendingCompletePurchase) {
            _iap.completePurchase(p);
          }
        case PurchaseStatus.pending:
          _controller.add(const PurchaseEvent(PurchaseEventKind.pending));
        case PurchaseStatus.error:
          _controller.add(
            PurchaseEvent(
              PurchaseEventKind.error,
              message: p.error?.message ?? 'Purchase failed',
            ),
          );
          if (p.pendingCompletePurchase) {
            _iap.completePurchase(p);
          }
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) {
            _iap.completePurchase(p);
          }
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }

  @override
  Future<PurchaseResult> purchasePremium() async {
    if (!_available) {
      return PurchaseResult.fail('StoreKit is not available on this device.');
    }
    var product = _product;
    if (product == null) {
      final response = await _iap.queryProductDetails({kPremiumProductId});
      if (response.productDetails.isEmpty) {
        return PurchaseResult.fail(
          'Product $kPremiumProductId not found. Configure in App Store Connect.',
        );
      }
      product = response.productDetails.first;
      _product = product;
    }
    final param = PurchaseParam(productDetails: product);
    final started = await _iap.buyNonConsumable(purchaseParam: param);
    if (!started) {
      return PurchaseResult.fail('Could not start purchase sheet.');
    }
    return PurchaseResult.pendingResult;
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    if (!_available) {
      return PurchaseResult.fail('StoreKit is not available on this device.');
    }
    await _iap.restorePurchases();
    return PurchaseResult.pendingResult;
  }

  @override
  void unlockDebug() {
    // Intentionally no-op on StoreKit path — use sandbox purchase instead.
  }

  @override
  void lockDebug() {
    // No-op on StoreKit path.
  }
}
