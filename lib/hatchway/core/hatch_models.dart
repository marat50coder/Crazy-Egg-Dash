enum NestRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    NestRoute.native => 'native',
    NestRoute.portal => 'portal',
    NestRoute.undecided => 'undecided',
  };

  static NestRoute parse(String? value) => switch (value) {
    'portal' || 'web' => NestRoute.portal,
    'native' || 'game' => NestRoute.native,
    _ => NestRoute.undecided,
  };
}

class HatchReply {
  const HatchReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory HatchReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return HatchReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory HatchReply.rejected(String reason) =>
      HatchReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class HatchDestination {
  const HatchDestination();
}

final class NativeNest extends HatchDestination {
  const NativeNest();
}

final class PortalNest extends HatchDestination {
  const PortalNest(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineNest extends HatchDestination {
  const OfflineNest({required this.returnToNative});

  final bool returnToNative;
}
