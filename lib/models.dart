/// Shared order statuses — the single list used by every DryClean Plus app.
class OrderStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const pickupAssigned = 'pickup_assigned';
  static const pickupEnRoute = 'pickup_en_route';
  static const pickupArrived = 'pickup_arrived';
  static const collected = 'collected';
  static const atFacility = 'at_facility';
  static const inspecting = 'inspecting';
  static const awaitingApproval = 'awaiting_approval';
  static const cleaning = 'cleaning';
  static const qualityCheck = 'quality_check';
  static const readyForDelivery = 'ready_for_delivery';
  static const deliveryAssigned = 'delivery_assigned';
  static const outForDelivery = 'out_for_delivery';
  static const deliveryArrived = 'delivery_arrived';
  static const delivered = 'delivered';
  static const pickupFailed = 'pickup_failed';
  static const deliveryFailed = 'delivery_failed';
  static const cancelled = 'cancelled';
}

/// A driver job's own status (one order has a pickup job and a delivery job).
class JobStatus {
  static const assigned = 'assigned';
  static const enRoute = 'en_route';
  static const arrived = 'arrived';
  static const completed = 'completed';
  static const failed = 'failed';
}

/// Normalises anything a scanner returns: bag tags (`BAG-1042`, `bag1042`), order numbers
/// and QR links (`https://…/b/BAG-1042`, `…?tag=BAG-1042`). Same rule as the intake app,
/// so a tag scanned at the door is always found at the facility.
String scanCode(String raw) {
  var c = raw.trim();
  final uri = Uri.tryParse(c);
  if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
    c = uri.queryParameters['tag'] ?? uri.queryParameters['code'] ?? uri.queryParameters['order'] ?? (uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
  }
  c = c.replaceFirst(RegExp(r'^(DCBAG|DC-BAG|TAG):', caseSensitive: false), '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
  final bag = RegExp(r'^BAG-?(\w+)$').firstMatch(c);
  return bag != null ? 'BAG-${bag.group(1)}' : c;
}

class JobItem {
  final String name;
  final int qty;
  const JobItem(this.name, this.qty);
}

class Job {
  final String id;
  final String orderId; // human order number, e.g. DC26000050
  final String orderDocId; // Firestore document id in `orders`
  final String type; // 'pickup' | 'delivery'
  final String status;
  final int sequence;
  final String date; // yyyy-MM-dd
  final String slot; // e.g. 18:00 - 21:00
  final String customerName;
  final String customerUid;
  final String phone;
  final String line1;
  final String line2;
  final String city;
  final String postcode;
  final double? lat;
  final double? lng;
  final String notes;
  final String handoff;
  final List<JobItem> items;
  final List<String> services; // bag orders: services picked in the app (items are counted at the facility)
  final int bags;
  final List<String> bagTags;
  final double amountDue;
  final String paymentMethod;
  final String? failReason;
  final DateTime? completedAt;

  const Job({
    required this.id,
    required this.orderId,
    required this.orderDocId,
    required this.type,
    required this.status,
    this.sequence = 0,
    this.date = '',
    this.slot = '',
    this.customerName = '',
    this.customerUid = '',
    this.phone = '',
    this.line1 = '',
    this.line2 = '',
    this.city = 'London',
    this.postcode = '',
    this.lat,
    this.lng,
    this.notes = '',
    this.handoff = '',
    this.items = const [],
    this.services = const [],
    this.bags = 0,
    this.bagTags = const [],
    this.amountDue = 0,
    this.paymentMethod = '',
    this.failReason,
    this.completedAt,
  });

  bool get isPickup => type == 'pickup';
  bool get isDone => status == JobStatus.completed || status == JobStatus.failed;
  bool get isActive => status == JobStatus.enRoute || status == JobStatus.arrived;
  bool get hasGeo => lat != null && lng != null;
  String get firstName => customerName.trim().split(' ').first;
  String get address => [line1, line2].where((s) => s.trim().isNotEmpty).join(', ');
  String get fullAddress => [address, '$city $postcode'.trim()].where((s) => s.trim().isNotEmpty).join(', ');
  int get itemCount => items.fold(0, (n, i) => n + i.qty);

  Job copyWith({String? status, double? lat, double? lng, int? bags, List<String>? bagTags, String? failReason, DateTime? completedAt}) => Job(
        id: id,
        orderId: orderId,
        orderDocId: orderDocId,
        type: type,
        status: status ?? this.status,
        sequence: sequence,
        date: date,
        slot: slot,
        customerName: customerName,
        customerUid: customerUid,
        phone: phone,
        line1: line1,
        line2: line2,
        city: city,
        postcode: postcode,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        notes: notes,
        handoff: handoff,
        items: items,
        services: services,
        bags: bags ?? this.bags,
        bagTags: bagTags ?? this.bagTags,
        amountDue: amountDue,
        paymentMethod: paymentMethod,
        failReason: failReason ?? this.failReason,
        completedAt: completedAt ?? this.completedAt,
      );

  static double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  factory Job.fromMap(String id, Map<String, dynamic> m) {
    final a = (m['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    final g = (m['geo'] as Map?)?.cast<String, dynamic>();
    final ts = m['completedAt'];
    return Job(
      id: id,
      orderId: '${m['orderId'] ?? ''}',
      orderDocId: '${m['orderDocId'] ?? m['orderId'] ?? ''}',
      type: '${m['type'] ?? 'pickup'}',
      status: '${m['status'] ?? JobStatus.assigned}',
      sequence: (m['sequence'] as num?)?.toInt() ?? 0,
      date: '${m['date'] ?? ''}',
      slot: '${m['slot'] ?? ''}',
      customerName: '${m['customerName'] ?? ''}',
      customerUid: '${m['customerUid'] ?? ''}',
      phone: '${m['phone'] ?? ''}',
      line1: '${a['line1'] ?? ''}',
      line2: '${a['line2'] ?? ''}',
      city: '${a['city'] ?? ''}',
      postcode: '${a['postalCode'] ?? a['postcode'] ?? ''}',
      lat: (g?['lat'] as num?)?.toDouble() ?? (a['latitude'] as num?)?.toDouble() ?? (a['lat'] as num?)?.toDouble(),
      lng: (g?['lng'] as num?)?.toDouble() ?? (a['longitude'] as num?)?.toDouble() ?? (a['lon'] as num?)?.toDouble(),
      notes: [m['notes'], if ('${m['customerNote'] ?? ''}'.isNotEmpty) 'Customer: ${m['customerNote']}'].where((e) => '${e ?? ''}'.trim().isNotEmpty).join(' · '),
      handoff: '${m['handoff'] ?? ''}',
      items: ((m['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((i) => JobItem('${i['name'] ?? 'Item'}', (i['qty'] as num?)?.toInt() ?? 1))
          .toList(),
      services: ((m['services'] as List?) ?? const []).map((e) => '$e').where((e) => e.trim().isNotEmpty).toList(),
      bags: (m['bags'] as num?)?.toInt() ?? 0,
      bagTags: ((m['bagTags'] as List?) ?? const []).map((e) => '$e').toList(),
      amountDue: _num(m['amountDue']),
      paymentMethod: '${m['paymentMethod'] ?? ''}',
      failReason: m['failReason'] as String?,
      completedAt: ts is DateTime ? ts : null, // Firestore Timestamps are converted by the repository
    );
  }
}

class DriverProfile {
  final String uid;
  final String name;
  final String phone;
  final String vehicle; // e.g. "White Ford E-Transit"
  final String reg;
  const DriverProfile({required this.uid, required this.name, this.phone = '', this.vehicle = '', this.reg = ''});
  String get firstName => name.trim().split(' ').first;
  String get initials => name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
}
