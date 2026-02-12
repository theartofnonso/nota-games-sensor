/// Response from the resubscribe API.
class ResubscriptionResponseDto {
  final String subscriptionId;
  final String status;
  final String customerId;
  final int currentPeriodStart;
  final int currentPeriodEnd;
  final List<ResubscriptionItemDto> items;

  const ResubscriptionResponseDto({
    required this.subscriptionId,
    required this.status,
    required this.customerId,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.items,
  });

  factory ResubscriptionResponseDto.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map((e) => ResubscriptionItemDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return ResubscriptionResponseDto(
      subscriptionId: json['subscriptionId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      currentPeriodStart: (json['currentPeriodStart'] as num?)?.toInt() ?? 0,
      currentPeriodEnd: (json['currentPeriodEnd'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }

  bool get isActive => status == 'active';
}

/// A subscription item (price/plan).
class ResubscriptionItemDto {
  final String priceId;
  final int amount; // Unit amount in cents
  final String currency;
  final String interval; // month or year
  final int intervalCount;
  final String productName;

  const ResubscriptionItemDto({
    required this.priceId,
    required this.amount,
    required this.currency,
    required this.interval,
    required this.intervalCount,
    required this.productName,
  });

  factory ResubscriptionItemDto.fromJson(Map<String, dynamic> json) {
    return ResubscriptionItemDto(
      priceId: json['priceId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'usd',
      interval: json['interval'] as String? ?? 'month',
      intervalCount: (json['intervalCount'] as num?)?.toInt() ?? 1,
      productName: json['productName'] as String? ?? '',
    );
  }

  /// Formatted price, e.g. "\$9.99/month" or "\$99/year"
  String get formattedPrice {
    final dollars = amount / 100;
    final formatted = dollars == dollars.truncateToDouble()
        ? dollars.toInt().toString()
        : dollars.toStringAsFixed(2);
    final symbol = currency.toUpperCase() == 'USD' ? '\$' : currency;
    final intervalLabel = intervalCount == 1
        ? '/$interval'
        : ' every $intervalCount ${interval}s';
    return '$symbol$formatted$intervalLabel';
  }
}
