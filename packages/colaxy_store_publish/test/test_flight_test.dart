import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'app_store_support.dart';
import 'support.dart';

AppStorePublisher _publisher(Recorder recorder, {StoreConsoleLog? onLog}) =>
    AppStorePublisher(
      client: AppStoreConnectClient(
        apiKey: testApiKey(),
        httpClient: recorder.client,
        retryPolicy: const RetryPolicy.none(),
      ),
      appId: '6740000000',
      onLog: onLog,
    );

/// Answers the calls a distribution makes.
void _serveStore(
  Recorder recorder, {
  bool internal = true,
  String externalState = 'READY_FOR_BETA_TESTING',
  bool missingCompliance = false,
}) => recorder.route((request) {
  final path = request.url.path;
  if (path.endsWith('/betaGroups')) {
    return Recorder.ok(
      jsonApiList([
        resource('betaGroups', 'g-1', {
          'name': internal ? 'Internal' : 'External',
          'isInternalGroup': internal,
        }),
      ]),
    );
  }
  if (path.endsWith('/buildBetaDetails')) {
    return Recorder.ok(
      jsonApiList([
        resource('buildBetaDetails', 'd-1', {
          'internalBuildState': missingCompliance
              ? 'MISSING_EXPORT_COMPLIANCE'
              : 'READY_FOR_BETA_TESTING',
          'externalBuildState': externalState,
        }),
      ]),
    );
  }
  // The build's notes are at `/v1/builds/{id}/betaBuildLocalizations` and
  // creating one POSTs to `/v1/betaBuildLocalizations`. Same suffix, so the
  // method is what tells them apart.
  if (path.endsWith('/betaBuildLocalizations')) {
    if (request.method == 'POST') {
      return Recorder.ok(
        jsonApiOne(
          resource('betaBuildLocalizations', 'bbl-1', {'locale': 'ja'}),
        ),
      );
    }
    return Recorder.ok(jsonApiList([]));
  }
  return Recorder.ok(const <String, dynamic>{});
});

void main() {
  group('distribute', () {
    test('assigns the build and submits for beta review when external',
        () async {
      // Assigning to an external group and stopping there leaves the build at
      // READY_FOR_BETA_SUBMISSION and no tester ever sees it.
      final recorder = Recorder();
      _serveStore(recorder, internal: false);

      await _publisher(recorder).testFlight.distribute(
        buildId: 'b-1',
        groupNames: ['External'],
      );

      expect(
        recorder.trace.any(
          (line) => line.endsWith('/v1/betaAppReviewSubmissions'),
        ),
        isTrue,
      );
    });

    test('does not submit for beta review for an internal group', () async {
      final recorder = Recorder();
      _serveStore(recorder);

      await _publisher(recorder).testFlight.distribute(
        buildId: 'b-1',
        groupNames: ['Internal'],
      );

      expect(
        recorder.trace.any(
          (line) => line.endsWith('/v1/betaAppReviewSubmissions'),
        ),
        isFalse,
      );
    });

    test('treats a group of unknown kind as external', () async {
      // Assuming internal would skip the review and strand the build, with
      // nothing saying why.
      final recorder = Recorder()
        ..route((request) {
          if (request.url.path.endsWith('/betaGroups')) {
            return Recorder.ok(
              jsonApiList([
                resource('betaGroups', 'g-1', {'name': 'Mystery'}),
              ]),
            );
          }
          if (request.url.path.endsWith('/buildBetaDetails')) {
            return Recorder.ok(jsonApiList([]));
          }
          return Recorder.ok(const <String, dynamic>{});
        });

      await _publisher(recorder).testFlight.distribute(
        buildId: 'b-1',
        groupNames: ['Mystery'],
      );

      expect(
        recorder.trace.any(
          (line) => line.endsWith('/v1/betaAppReviewSubmissions'),
        ),
        isTrue,
      );
    });

    test('can be told not to submit, and says so', () async {
      final logs = <String>[];
      final recorder = Recorder();
      _serveStore(recorder, internal: false);

      await _publisher(recorder, onLog: logs.add).testFlight.distribute(
        buildId: 'b-1',
        groupNames: ['External'],
        submitForBetaReview: false,
      );

      expect(
        recorder.trace.any(
          (line) => line.endsWith('/v1/betaAppReviewSubmissions'),
        ),
        isFalse,
      );
      expect(
        logs.any((line) => line.contains('will not receive this build')),
        isTrue,
      );
    });

    test('names the groups that exist when one is not found', () async {
      final recorder = Recorder();
      _serveStore(recorder);

      await expectLater(
        _publisher(recorder).testFlight.distribute(
          buildId: 'b-1',
          groupNames: ['Nope'],
        ),
        throwsA(
          isA<FastlaneLayoutException>().having(
            (e) => e.message,
            'message',
            contains('Internal'),
          ),
        ),
      );
    });

    test('refuses to distribute to no group at all', () {
      final recorder = Recorder();

      expect(
        () => _publisher(recorder).testFlight.distribute(
          buildId: 'b-1',
          groupNames: const [],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(recorder.requests, isEmpty);
    });

    test('writes tester notes to the build, not the listing', () async {
      // BetaBuildLocalization.whatsNew and AppStoreVersionLocalization.whatsNew
      // are different fields on different resources.
      final recorder = Recorder();
      _serveStore(recorder);

      await _publisher(recorder).testFlight.distribute(
        buildId: 'b-1',
        groupNames: ['Internal'],
        testerNotes: {'ja': '不具合の修正'},
      );

      final write = recorder.requests.firstWhere(
        (r) => r.url.path == '/v1/betaBuildLocalizations',
      );
      final body = jsonDecode(write.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      expect(
        (data['attributes'] as Map<String, dynamic>)['whatsNew'],
        '不具合の修正',
      );
      expect(data['relationships'], contains('build'));
    });
  });

  group('the states that strand a build', () {
    test('warns when the export compliance answer is missing', () async {
      final logs = <String>[];
      final recorder = Recorder();
      _serveStore(recorder, missingCompliance: true);

      await _publisher(recorder, onLog: logs.add).testFlight.distribute(
        buildId: 'b-1',
        groupNames: ['Internal'],
      );

      expect(
        logs.any((line) => line.contains('export compliance')),
        isTrue,
      );
    });

    test('warns when an external build is still awaiting submission',
        () async {
      final logs = <String>[];
      final recorder = Recorder();
      _serveStore(
        recorder,
        internal: false,
        externalState: 'READY_FOR_BETA_SUBMISSION',
      );

      await _publisher(recorder, onLog: logs.add).testFlight.distribute(
        buildId: 'b-1',
        groupNames: ['External'],
      );

      expect(
        logs.any((line) => line.contains('READY_FOR_BETA_SUBMISSION')),
        isTrue,
      );
    });

    test('the two build states are different enums', () {
      // ExternalBetaState carries the beta review cycle; the internal one
      // does not, because internal testers skip review.
      final internal = InternalBetaState.values.map((s) => s.wireName).toSet();
      final external = ExternalBetaState.values.map((s) => s.wireName).toSet();

      expect(external, contains('READY_FOR_BETA_SUBMISSION'));
      expect(external, contains('IN_BETA_REVIEW'));
      expect(internal, isNot(contains('READY_FOR_BETA_SUBMISSION')));
    });
  });

  group('review submission', () {
    test('prepare creates the submission and its item, and submits nothing',
        () async {
      // A submission with no item is valid, submittable, and submits nothing.
      final recorder = Recorder()
        ..enqueue(
          jsonApiOne(
            resource('reviewSubmissions', 'rs-1', {'platform': 'IOS'}),
          ),
        )
        ..enqueue(jsonApiOne(resource('reviewSubmissionItems', 'ri-1', {})));

      final submission = await _publisher(recorder).reviewSubmissions.prepare(
        platform: 'IOS',
        appStoreVersionId: 'v1',
      );

      expect(submission.isSubmitted, isFalse);
      expect(recorder.trace, [
        'POST /v1/reviewSubmissions',
        'POST /v1/reviewSubmissionItems',
      ]);
      final item =
          jsonDecode(recorder.requests.last.body) as Map<String, dynamic>;
      expect(
        (item['data'] as Map<String, dynamic>)['relationships'],
        allOf(contains('reviewSubmission'), contains('appStoreVersion')),
      );
    });

    test('submitting is a separate PATCH', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiOne(
            resource('reviewSubmissions', 'rs-1', {
              'submittedDate': '2026-09-03T00:00:00Z',
            }),
          ),
        );

      final submitted =
          await _publisher(recorder).reviewSubmissions.submit('rs-1');

      expect(submitted.isSubmitted, isTrue);
      expect(recorder.requests.single.method, 'PATCH');
      final body =
          jsonDecode(recorder.requests.single.body) as Map<String, dynamic>;
      expect(
        ((body['data'] as Map<String, dynamic>)['attributes']
            as Map<String, dynamic>)['submitted'],
        isTrue,
      );
    });

    test('cancel sends canceled rather than submitted', () async {
      final recorder = Recorder()
        ..enqueue(jsonApiOne(resource('reviewSubmissions', 'rs-1', {})));

      await _publisher(recorder).reviewSubmissions.cancel('rs-1');

      final body =
          jsonDecode(recorder.requests.single.body) as Map<String, dynamic>;
      final attributes = (body['data'] as Map<String, dynamic>)['attributes']
          as Map<String, dynamic>;
      expect(attributes['canceled'], isTrue);
      expect(attributes, isNot(contains('submitted')));
    });
  });

  group('builds', () {
    test('finds the newest by uploadedDate, not by response order', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('builds', 'old', {
              'version': '410',
              'uploadedDate': '2026-08-01T00:00:00Z',
            }),
            resource('builds', 'new', {
              'version': '412',
              'uploadedDate': '2026-09-01T00:00:00Z',
            }),
          ]),
        );

      final build = await _publisher(recorder).builds.latest();

      expect(build?.id, 'new');
    });

    test('filters on the build number, which is not the marketing version',
        () async {
      final recorder = Recorder()..enqueue(jsonApiList([]));

      await _publisher(recorder).builds.list(
        version: '412',
        preReleaseVersion: '1.4.0',
      );

      final query = recorder.requests.single.url.queryParameters;
      expect(query['filter[version]'], '412');
      expect(query['filter[preReleaseVersion.version]'], '1.4.0');
    });

    test('setting export compliance PATCHes the build', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiOne(
            resource('builds', 'b-1', {'usesNonExemptEncryption': false}),
          ),
        );

      await _publisher(recorder).builds.setExportCompliance(
        buildId: 'b-1',
        usesNonExemptEncryption: false,
      );

      expect(recorder.requests.single.method, 'PATCH');
      expect(recorder.requests.single.url.path, '/v1/builds/b-1');
    });
  });
}
