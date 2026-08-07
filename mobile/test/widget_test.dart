import 'package:flutter_test/flutter_test.dart';
import 'package:chat_perdu/models/report.dart';

void main() {
  test('Report parses API payload', () {
    final r = Report.fromJson(
        {'id': '1', 'name': 'Moka', 'status': 'Perdu', 'place': 'Paris'});
    expect(r.name, 'Moka');
    expect(r.status, 'Perdu');
  });
}
