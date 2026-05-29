/// Safely convert a JSON value to int, handling both int and double.
int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

class ShopPlan {
  const ShopPlan({
    required this.id,
    this.groupId,
    required this.name,
    this.tags,
    this.content,
    this.monthPrice,
    this.quarterPrice,
    this.halfYearPrice,
    this.yearPrice,
    this.twoYearPrice,
    this.threeYearPrice,
    this.onetimePrice,
    this.resetPrice,
    this.capacityLimit,
    this.transferEnable = 0,
    this.speedLimit,
    this.deviceLimit,
    this.show = true,
    this.sell = true,
    this.renew = true,
    this.resetTrafficMethod,
    this.sort = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int? groupId;
  final String name;
  final List<String>? tags;
  final String? content;
  final int? monthPrice;
  final int? quarterPrice;
  final int? halfYearPrice;
  final int? yearPrice;
  final int? twoYearPrice;
  final int? threeYearPrice;
  final int? onetimePrice;
  final int? resetPrice;
  final dynamic capacityLimit;
  final int transferEnable;
  final int? speedLimit;
  final int? deviceLimit;
  final bool show;
  final bool sell;
  final bool renew;
  final int? resetTrafficMethod;
  final int sort;
  final int? createdAt;
  final int? updatedAt;

  factory ShopPlan.fromJson(Map<String, Object?> json) => ShopPlan(
        id: _asInt(json['id']) ?? 0,
        groupId: _asInt(json['group_id']),
        name: json['name'] as String? ?? '',
        tags: (json['tags'] as List?)?.cast<String>(),
        content: json['content'] as String?,
        monthPrice: _asInt(json['month_price']),
        quarterPrice: _asInt(json['quarter_price']),
        halfYearPrice: _asInt(json['half_year_price']),
        yearPrice: _asInt(json['year_price']),
        twoYearPrice: _asInt(json['two_year_price']),
        threeYearPrice: _asInt(json['three_year_price']),
        onetimePrice: _asInt(json['onetime_price']),
        resetPrice: _asInt(json['reset_price']),
        capacityLimit: json['capacity_limit'],
        transferEnable: _asInt(json['transfer_enable']) ?? 0,
        speedLimit: _asInt(json['speed_limit']),
        deviceLimit: _asInt(json['device_limit']),
        show: json['show'] as bool? ?? true,
        sell: json['sell'] as bool? ?? true,
        renew: json['renew'] as bool? ?? true,
        resetTrafficMethod: _asInt(json['reset_traffic_method']),
        sort: _asInt(json['sort']) ?? 0,
        createdAt: _asInt(json['created_at']),
        updatedAt: _asInt(json['updated_at']),
      );

  bool get isSoldOut => capacityLimit == 'Sold out';

  /// Available (periodKey, priceInCents) pairs
  List<MapEntry<String, int>> get availablePeriods => [
        if (monthPrice != null) const MapEntry('month_price', 0).copyWithValue(monthPrice!),
        if (quarterPrice != null) const MapEntry('quarter_price', 0).copyWithValue(quarterPrice!),
        if (halfYearPrice != null) const MapEntry('half_year_price', 0).copyWithValue(halfYearPrice!),
        if (yearPrice != null) const MapEntry('year_price', 0).copyWithValue(yearPrice!),
        if (twoYearPrice != null) const MapEntry('two_year_price', 0).copyWithValue(twoYearPrice!),
        if (threeYearPrice != null) const MapEntry('three_year_price', 0).copyWithValue(threeYearPrice!),
        if (onetimePrice != null) const MapEntry('onetime_price', 0).copyWithValue(onetimePrice!),
      ];

  int? get lowestPrice {
    final prices = [
      monthPrice,
      quarterPrice,
      halfYearPrice,
      yearPrice,
      twoYearPrice,
      threeYearPrice,
      onetimePrice,
    ].whereType<int>().toList();
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }
}

extension on MapEntry<String, int> {
  MapEntry<String, int> copyWithValue(int v) => MapEntry(key, v);
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    this.userId = 0,
    this.planId = 0,
    this.paymentId,
    this.couponId,
    required this.period,
    required this.tradeNo,
    this.callbackNo,
    this.totalAmount = 0,
    this.handlingAmount,
    this.discountAmount,
    this.surplusAmount,
    this.refundAmount,
    this.balanceAmount,
    this.type = 1,
    this.status = 0,
    this.commissionStatus = 0,
    this.commissionBalance = 0,
    this.paidAt,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.plan,
  });

  final int id;
  final int userId;
  final int planId;
  final int? paymentId;
  final int? couponId;
  final String period;
  final String tradeNo;
  final String? callbackNo;
  final int totalAmount;
  final int? handlingAmount;
  final int? discountAmount;
  final int? surplusAmount;
  final int? refundAmount;
  final int? balanceAmount;
  final int type;
  final int status;
  final int commissionStatus;
  final int commissionBalance;
  final int? paidAt;
  final int createdAt;
  final int updatedAt;
  final ShopPlan? plan;

  factory ShopOrder.fromJson(Map<String, Object?> json) => ShopOrder(
        id: _asInt(json['id']) ?? 0,
        userId: _asInt(json['user_id']) ?? 0,
        planId: _asInt(json['plan_id']) ?? 0,
        paymentId: _asInt(json['payment_id']),
        couponId: _asInt(json['coupon_id']),
        period: json['period'] as String? ?? '',
        tradeNo: json['trade_no'] as String? ?? '',
        callbackNo: json['callback_no'] as String?,
        totalAmount: _asInt(json['total_amount']) ?? 0,
        handlingAmount: _asInt(json['handling_amount']),
        discountAmount: _asInt(json['discount_amount']),
        surplusAmount: _asInt(json['surplus_amount']),
        refundAmount: _asInt(json['refund_amount']),
        balanceAmount: _asInt(json['balance_amount']),
        type: _asInt(json['type']) ?? 1,
        status: _asInt(json['status']) ?? 0,
        commissionStatus: _asInt(json['commission_status']) ?? 0,
        commissionBalance: _asInt(json['commission_balance']) ?? 0,
        paidAt: _asInt(json['paid_at']),
        createdAt: _asInt(json['created_at']) ?? 0,
        updatedAt: _asInt(json['updated_at']) ?? 0,
        plan: json['plan'] is Map
            ? ShopPlan.fromJson((json['plan'] as Map).cast<String, Object?>())
            : null,
      );

  bool get isPending => status == 0;
  bool get isProcessing => status == 1;
  bool get isCancelled => status == 2;
  bool get isCompleted => status == 3;
  bool get isDiscounted => status == 4;

  bool get isNewPurchase => type == 1;
  bool get isRenewal => type == 2;
  bool get isUpgrade => type == 3;
  bool get isResetTraffic => type == 4;
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.payment,
    this.icon,
    this.handlingFeeFixed,
    this.handlingFeePercent,
  });

  final int id;
  final String name;
  final String payment;
  final String? icon;
  final int? handlingFeeFixed;
  final double? handlingFeePercent;

  factory PaymentMethod.fromJson(Map<String, Object?> json) => PaymentMethod(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        payment: json['payment'] as String? ?? '',
        icon: json['icon'] as String?,
        handlingFeeFixed: _asInt(json['handling_fee_fixed']),
        handlingFeePercent: (json['handling_fee_percent'] is num)
            ? (json['handling_fee_percent'] as num).toDouble()
            : double.tryParse(json['handling_fee_percent']?.toString() ?? ''),
      );
}

class CouponCheckResult {
  const CouponCheckResult({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.value,
  });

  final int id;
  final String code;
  final String name;

  /// 1 = fixed amount (cents), 2 = percentage
  final int type;
  final int value;

  factory CouponCheckResult.fromJson(Map<String, Object?> json) =>
      CouponCheckResult(
        id: _asInt(json['id']) ?? 0,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: _asInt(json['type']) ?? 1,
        value: _asInt(json['value']) ?? 0,
      );

  bool get isFixed => type == 1;
  bool get isPercentage => type == 2;
}

class CheckoutResult {
  const CheckoutResult({
    required this.type,
    required this.data,
  });

  /// -1 = free/completed, 0 = QR code URL, 1 = redirect URL
  final int type;
  final dynamic data;

  factory CheckoutResult.fromJson(Map<String, Object?> json) =>
      CheckoutResult(
        type: _asInt(json['type']) ?? 0,
        data: json['data'],
      );

  bool get isFree => type == -1;
  bool get isQrCode => type == 0;
  bool get isRedirect => type == 1;
  String? get url => data is String ? data as String : null;
}
