import 'package:flutter_test/flutter_test.dart';
import 'package:chores/shared/format.dart';

void main() {
  test('one format for every duration', () {
    expect(DurationFormat.format(0), '0s');
    expect(DurationFormat.format(40), '40s');
    expect(DurationFormat.format(5 * 60 + 7), '5m 07s');
    expect(DurationFormat.format(45 * 60), '45m 00s');
    expect(DurationFormat.format(3600 + 5 * 60 + 30), '1h 05m 30s');
    expect(DurationFormat.format(-5), '0s');
  });
}
