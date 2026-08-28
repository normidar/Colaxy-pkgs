import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

/// An in-memory [StoreReviewsApi] holding a fixed set of reviews.
class _FakeReviewsApi implements StoreReviewsApi {
  _FakeReviewsApi(this.store, this.reviews);

  @override
  final Store store;

  final List<StoreReview> reviews;
  final replies = <String, String>{};
  bool closed = false;
  int listCalls = 0;

  @override
  Stream<StoreReview> list([ReviewQuery query = const ReviewQuery()]) async* {
    listCalls++;
    for (final review in reviews) {
      if (query.matches(
        rating: review.rating,
        reviewHasReply: review.hasReply,
      )) {
        yield review;
      }
    }
  }

  @override
  Future<ReviewPage> listPage([
    ReviewQuery query = const ReviewQuery(),
  ]) async => ReviewPage(store: store, reviews: reviews);

  @override
  Future<StoreReview?> get(String reviewId) async {
    for (final review in reviews) {
      if (review.id == reviewId) return review;
    }
    return null;
  }

  @override
  Future<ReviewReply> reply(String reviewId, String body) async {
    replies[reviewId] = body;
    return ReviewReply(store: store, body: body);
  }

  @override
  void close() => closed = true;
}

StoreReview _review(Store store, String id, {int rating = 3}) => StoreReview(
  store: store,
  id: id,
  rating: rating,
);

void main() {
  late _FakeReviewsApi play;
  late _FakeReviewsApi appStore;
  late MergedReviewsApi merged;

  setUp(() {
    play = _FakeReviewsApi(Store.googlePlay, [
      _review(Store.googlePlay, 'gp:1', rating: 1),
      _review(Store.googlePlay, 'gp:2', rating: 5),
    ]);
    appStore = _FakeReviewsApi(Store.appStore, [
      _review(Store.appStore, 'as:1', rating: 1),
    ]);
    merged = MergedReviewsApi([play, appStore]);
  });

  group('list', () {
    test('yields every store, one fully drained before the next', () async {
      final reviews = await merged.list().toList();

      expect(reviews.map((r) => r.id), ['gp:1', 'gp:2', 'as:1']);
    });

    test('passes the query through to each store', () async {
      final reviews = await merged
          .list(const ReviewQuery(ratings: {1}))
          .toList();

      expect(reviews.map((r) => r.id), ['gp:1', 'as:1']);
    });

    test('does not touch a later store if the caller stops early', () async {
      // Draining every store regardless would spend Play quota on reviews
      // nobody asked for.
      await merged.list().first;

      expect(play.listCalls, 1);
      expect(appStore.listCalls, 0);
    });
  });

  group('store', () {
    test('throws when several stores are configured', () {
      expect(() => merged.store, throwsStateError);
    });

    test('delegates when only one store is configured', () {
      expect(MergedReviewsApi([play]).store, Store.googlePlay);
    });
  });

  group('listPage', () {
    test('is unsupported across stores, since cursors are per-store', () {
      expect(merged.listPage, throwsUnsupportedError);
    });

    test('delegates when only one store is configured', () async {
      final page = await MergedReviewsApi([appStore]).listPage();

      expect(page.store, Store.appStore);
    });
  });

  group('get', () {
    test('finds a review in whichever store holds it', () async {
      expect((await merged.get('as:1'))!.store, Store.appStore);
      expect((await merged.get('gp:2'))!.store, Store.googlePlay);
    });

    test('returns null when no store has it', () async {
      expect(await merged.get('nope'), isNull);
    });
  });

  group('reply', () {
    test('routes the reply to the owning store', () async {
      await merged.reply('as:1', 'Thanks!');

      expect(appStore.replies, {'as:1': 'Thanks!'});
      expect(play.replies, isEmpty);
    });

    test('throws ReviewNotFoundException for an unknown review', () async {
      await expectLater(
        merged.reply('nope', 'Thanks!'),
        throwsA(
          isA<ReviewNotFoundException>().having(
            (e) => e.reviewId,
            'reviewId',
            'nope',
          ),
        ),
      );
    });
  });

  test('close() closes every store', () {
    merged.close();

    expect(play.closed, isTrue);
    expect(appStore.closed, isTrue);
  });
}
