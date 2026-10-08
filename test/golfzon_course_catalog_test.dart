import 'package:flutter_test/flutter_test.dart';

import 'package:blackshell_golf/main.dart';

void main() {
  test('GOLFZON starter catalog is searchable and source tagged', () {
    expect(GolfzonCourseCatalog.courses.length, greaterThanOrEqualTo(20));
    expect(
      GolfzonCourseCatalog.courses.every((course) => course.isGolfzonCourse),
      isTrue,
    );

    final japanResults = GolfzonCourseCatalog.search('japan');
    expect(japanResults, isNotEmpty);
    expect(japanResults.every((course) => course.country == 'Japan'), isTrue);

    final pebbleBeach = GolfzonCourseCatalog.search('pebble beach');
    expect(pebbleBeach, hasLength(1));
    expect(pebbleBeach.single.totalYards, 6785);
  });
}
