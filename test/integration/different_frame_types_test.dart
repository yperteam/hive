import 'package:flutter_test/flutter_test.dart';

import '../frames.dart';
import 'integration.dart';

Future _performTest(bool lazy) async {
  var box = await openBox(lazy);
  for (var frame in valueTestFrames) {
    if (frame.deleted) continue;
    await box.put(frame.key, frame.value);
  }

  box = await reopenBox(box);

  for (var frame in valueTestFrames) {
    if (frame.deleted) continue;
    var f = await box.get(frame.key);
    expect(f, frame.value);
  }
  await box.close();
}

void main() {
  group('different frame types', () {
    test('normal box', () => _performTest(false), timeout: longTimeout);

    test('lazy box', () => _performTest(true), timeout: longTimeout);
  });
}
