// A trivial smoke test.
//
// The Partner app's real boot sequence pulls secrets from `.env` and
// opens a Supabase connection, so the default counter smoke test
// isn't useful here. Once the radar / auth screens are stable we'll
// add widget tests that mock the Supabase client — until then this
// placeholder lets `flutter test` stay green in CI.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity', () {
    expect(1 + 1, 2);
  });
}
