import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

MetricPoint _point(int day, num value, {Map<String, String>? dimensions}) =>
    MetricPoint(
      date: DateTime.utc(2026, 8, day),
      value: value,
      dimensions: dimensions ?? const {},
    );

StoreMetric _units(List<MetricPoint> points) => StoreMetric(
  store: Store.appStore,
  name: 'units',
  unit: MetricUnit.count,
  points: points,
);

void main() {
  group('aggregation', () {
    test('total sums every value', () {
      expect(_units([_point(20, 12), _point(21, 3)]).total, 15);
    });

    test('average is the unweighted mean over points', () {
      final rate = StoreMetric(
        store: Store.googlePlay,
        name: 'crashRate',
        unit: MetricUnit.rate,
        points: [_point(20, 0.02), _point(21, 0.04)],
      );

      expect(rate.average, closeTo(0.03, 1e-9));
    });

    test('an empty metric has a zero total and a null average', () {
      // Zero is the right sum of nothing; a mean of nothing is not zero.
      final empty = _units([]);

      expect(empty.total, 0);
      expect(empty.average, isNull);
      expect(empty.latest, isNull);
      expect(empty.period, isNull);
      expect(empty.isEmpty, isTrue);
    });

    test('latest finds the newest point regardless of list order', () {
      // Neither store promises an order.
      final metric = _units([_point(21, 3), _point(25, 9), _point(20, 12)]);

      expect(metric.latest!.value, 9);
    });

    test('period spans the earliest and latest dates', () {
      final metric = _units([_point(21, 3), _point(25, 9), _point(20, 12)]);

      expect(metric.period, (
        from: DateTime.utc(2026, 8, 20),
        to: DateTime.utc(2026, 8, 25),
      ));
    });
  });

  group('sortedByDate', () {
    test('orders points oldest first', () {
      final metric = _units([_point(25, 9), _point(20, 12), _point(21, 3)]);

      expect(
        metric.sortedByDate().points.map((p) => p.value),
        [12, 3, 9],
      );
    });

    test('leaves the original untouched', () {
      final metric = _units([_point(25, 9), _point(20, 12)]);

      final sorted = metric.sortedByDate();

      expect(sorted.points.first.value, 12);
      expect(metric.points.first.value, 9);
    });
  });

  group('whereDimension', () {
    test('keeps only points matching the dimension', () {
      final metric = _units([
        _point(20, 12, dimensions: {'countryCode': 'JPN'}),
        _point(20, 5, dimensions: {'countryCode': 'USA'}),
        _point(21, 7, dimensions: {'countryCode': 'JPN'}),
      ]);

      expect(metric.whereDimension('countryCode', 'JPN').total, 19);
    });

    test('yields an empty metric when filtering a metric of totals', () {
      // Returning the unfiltered totals would look like a working filter and
      // silently report the world's numbers as one country's.
      final metric = _units([_point(20, 12), _point(21, 3)]);

      expect(metric.whereDimension('countryCode', 'JPN').isEmpty, isTrue);
    });

    test('keeps the metric identity', () {
      final metric = _units([
        _point(20, 12, dimensions: {'a': 'b'}),
      ]);

      final filtered = metric.whereDimension('a', 'b');

      expect(filtered.name, 'units');
      expect(filtered.store, Store.appStore);
      expect(filtered.unit, MetricUnit.count);
    });
  });

  group('byDate', () {
    test('collapses a breakdown into one value per day', () {
      final metric = _units([
        _point(20, 12, dimensions: {'countryCode': 'JPN'}),
        _point(20, 5, dimensions: {'countryCode': 'USA'}),
        _point(21, 7, dimensions: {'countryCode': 'JPN'}),
      ]);

      expect(metric.byDate, {
        DateTime.utc(2026, 8, 20): 17,
        DateTime.utc(2026, 8, 21): 7,
      });
    });
  });

  group('MetricPoint', () {
    test('isTotal distinguishes a total from a breakdown', () {
      expect(_point(20, 12).isTotal, isTrue);
      expect(_point(20, 12, dimensions: {'a': 'b'}).isTotal, isFalse);
    });
  });

  test('copyWith replaces only what it is given', () {
    final metric = _units([_point(20, 12)]);

    final renamed = metric.copyWith(name: 'installs');

    expect(renamed.name, 'installs');
    expect(renamed.total, 12);
    expect(renamed.unit, MetricUnit.count);
  });
}
