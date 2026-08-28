import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

void main() {
  group('data', () {
    test('reads a collection response', () {
      final page = JsonApiPage({
        'data': [
          {'type': 'customerReviews', 'id': 'a'},
          {'type': 'customerReviews', 'id': 'b'},
        ],
      });

      expect(page.data.map((r) => r['id']), ['a', 'b']);
    });

    test('wraps a single-resource response in a one-element list', () {
      // `/v1/customerReviews/{id}` answers with an object, not an array; the
      // same reading code should cope with both.
      final page = JsonApiPage({
        'data': {'type': 'customerReviews', 'id': 'a'},
      });

      expect(page.data.map((r) => r['id']), ['a']);
    });

    test('drops entries that are not objects', () {
      final page = JsonApiPage({
        'data': [
          {'id': 'a'},
          'nonsense',
          42,
        ],
      });

      expect(page.data, hasLength(1));
    });

    test('is empty when there is no data at all', () {
      expect(JsonApiPage(const {}).data, isEmpty);
      expect(JsonApiPage(const {'data': null}).data, isEmpty);
    });
  });

  group('nextCursor', () {
    test('reads links.next', () {
      final page = JsonApiPage({
        'links': {'next': 'https://api.example/p2'},
      });

      expect(page.nextCursor, 'https://api.example/p2');
      expect(page.isLast, isFalse);
    });

    test('treats a missing or empty next as the last page', () {
      expect(JsonApiPage(const {}).isLast, isTrue);
      expect(
        JsonApiPage(const {
          'links': {'self': 'https://api.example/p1'},
        }).isLast,
        isTrue,
      );
      expect(
        JsonApiPage(const {
          'links': {'next': ''},
        }).isLast,
        isTrue,
      );
    });
  });

  group('total', () {
    test('reads meta.paging.total', () {
      final page = JsonApiPage({
        'meta': {
          'paging': {'total': 412, 'limit': 20},
        },
      });

      expect(page.total, 412);
    });

    test('is null when the envelope has no paging metadata', () {
      expect(JsonApiPage(const {}).total, isNull);
      expect(JsonApiPage(const {'meta': <String, dynamic>{}}).total, isNull);
    });
  });

  test('included is handed back untouched', () {
    final page = JsonApiPage({
      'included': [
        {'type': 'customerReviewResponses', 'id': 'r1'},
      ],
    });

    expect(page.included, isA<List<dynamic>>());
  });
}
