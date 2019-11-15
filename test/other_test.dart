import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('test unnecessary code', () {
    const HiveField(0);
    const HiveType(adapterName: 'Adapter');
  });
}
