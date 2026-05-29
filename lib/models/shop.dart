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
        id: json['id'] as int,
        groupId: json['group_id'] as int?,
        name: json['name'] as String? ?? '',
        tags: (json['tags'] as List?)?.cast<String>(),
        content: json['content'] as String?,
        monthPrice: json['month_price'] as int?,
        quarterPrice: json['quarter_price'] as int?,
        halfYearPrice: json['half_year_price'] as int?,
        yearPrice: json['year_price'] as int?,
        twoYearPrice: json['two_year_price'] as int?,
        threeYearPrice: json['three_year_price'] as int?,
        onetimePrice: json['onetime_price'] as int?,
        resetPrice: json['reset_price'] as int?,
        capacityLimit: json['capacity_limit'],
        transferEnable: json['transfer_enable'] as int? ?? 0,
        speedLimit: json['speed_limit'] as int?,
        deviceLimit: json['device_limit'] as int?,
        show: json['show'] as bool? ?? true,
        sell: json['sell'] as bool? ?? true,
        renew: json['renew'] as bool? ?? true,
        resetTrafficMethod: json['reset_traffic_method'] as int?,
        sort: json['sort'] as int? ?? 0,
        createdAt: json['created_at'] as int?,
        updatedAt: json['updated_at'] as int?,
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
        id: json['id'] as int,
        userId: json['user_id'] as int? ?? 0,
        planId: json['plan_id'] as int? ?? 0,
        paymentId: json['payment_id'] as int?,
        couponId: json['coupon_id'] as int?,
        period: json['period'] as String? ?? '',
        tradeNo: json['trade_no'] as String? ?? '',
        callbackNo: json['callback_no'] as String?,
        totalAmount: json['total_amount'] as int? ?? 0,
        handlingAmount: json['handling_amount'] as int?,
        discountAmount: json['discount_amount'] as int?,
        surplusAmount: json['surplus_amount'] as int?,
        refundAmount: json['refund_amount'] as int?,
        balanceAmount: json['balance_amount'] as int?,
        type: json['type'] as int? ?? 1,
        status: json['status'] as int? ?? 0,
        commissionStatus: json['commission_status'] as int? ?? 0,
        commissionBalance: json['commission_balance'] as int? ?? 0,
        paidAt: json['paid_at'] as int?,
        createdAt: json['created_at'] as int? ?? 0,
        updatedAt: json['updated_at'] as int? ?? 0,
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
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        payment: json['payment'] as String? ?? '',
        icon: json['icon'] as String?,
        handlingFeeFixed: json['handling_fee_fixed'] as int?,
        handlingFeePercent: (json['handling_fee_percent'] as num?)?.toDouble(),
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
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as int? ?? 1,
        value: json['value'] as int? ?? 0,
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
        type: json['type'] as int,
        data: json['data'],
      );

  bool get isFree => type == -1;
  bool get isQrCode => type == 0;
  bool get isRedirect => type == 1;
  String? get url => data is String ? data as String : null;
}
