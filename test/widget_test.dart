import 'package:dc_driver/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('job reads a Firestore map and formats the address', () {
    final j = Job.fromMap('j1', {
      'orderId': 'DC26000050',
      'orderDocId': 'abc',
      'type': 'pickup',
      'status': 'assigned',
      'customerName': 'Amelia Rhodes',
      'address': {'line1': '14 Brick Lane', 'line2': 'Flat 2', 'city': 'London', 'postalCode': 'E1 6RF'},
      'items': [
        {'name': 'Suit', 'qty': 2},
        {'name': 'Shirt', 'qty': 3},
      ],
      'amountDue': '£12.50',
    });
    expect(j.isPickup, isTrue);
    expect(j.firstName, 'Amelia');
    expect(j.fullAddress, '14 Brick Lane, Flat 2, London E1 6RF');
    expect(j.itemCount, 5);
    expect(j.amountDue, 12.5);
  });
}
