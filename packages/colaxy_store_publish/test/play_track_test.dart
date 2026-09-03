import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'support.dart';

PlayTracksApi _api(Recorder recorder) => PlayTracksApi(
  api: publisherApi(recorder),
  packageName: 'com.example.app',
  editId: 'edit-1',
  guard: PlayApiGuard(retryPolicy: const RetryPolicy.none()),
);

void main() {
  group('withRelease', () {
    test('keeps releases the incoming one does not supersede', () {
      // `tracks.update` replaces the whole release list, so a track sent with
      // one release drops the others. This is the guard against that.
      const track = PlayTrack(
        name: 'production',
        releases: [
          PlayTrackRelease(
            versionCodes: [410],
            status: PlayReleaseStatus.halted,
          ),
        ],
      );

      final next = track.withRelease(
        const PlayTrackRelease(versionCodes: [412]),
      );

      expect(next.releases, hasLength(2));
      expect(next.releases.first.versionCodes, [410]);
    });

    test('replaces a release that shares a version code', () {
      const track = PlayTrack(
        name: 'internal',
        releases: [
          PlayTrackRelease(
            versionCodes: [412],
            status: PlayReleaseStatus.draft,
          ),
        ],
      );

      final next = track.withRelease(
        const PlayTrackRelease(
          versionCodes: [412],
          status: PlayReleaseStatus.halted,
        ),
      );

      expect(next.releases, hasLength(1));
      expect(next.releases.single.status, PlayReleaseStatus.halted);
    });
  });

  group('rollout consistency', () {
    test('a staged rollout needs a fraction strictly inside 0 and 1', () {
      const staged = PlayTrackRelease(
        versionCodes: [412],
        status: PlayReleaseStatus.inProgress,
      );

      expect(staged.isRolloutConsistent, isFalse);
      expect(
        const PlayTrackRelease(
          versionCodes: [412],
          status: PlayReleaseStatus.inProgress,
          userFraction: 0.1,
        ).isRolloutConsistent,
        isTrue,
      );
    });

    test('update refuses an inconsistent rollout before sending it', () {
      final recorder = Recorder();

      expect(
        () => _api(recorder).update(
          const PlayTrack(
            name: 'production',
            releases: [
              PlayTrackRelease(
                versionCodes: [412],
                status: PlayReleaseStatus.inProgress,
              ),
            ],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(recorder.requests, isEmpty);
    });
  });

  group('release', () {
    test('reads the track first, then merges into it', () async {
      final recorder = Recorder()
        ..enqueue({
          'tracks': [
            {
              'track': 'production',
              'releases': [
                {
                  'versionCodes': ['410'],
                  'status': 'halted',
                },
              ],
            },
          ],
        })
        ..enqueue({'track': 'production'});

      await _api(recorder).release(
        track: PlayTrack.production,
        versionCodes: [412],
      );

      expect(recorder.trace.first, startsWith('GET'));
      final sent =
          jsonDecode(recorder.requests.last.body) as Map<String, dynamic>;
      expect(sent['releases'], hasLength(2));
    });

    test('sends version codes as strings, as the API types them', () async {
      final recorder = Recorder()
        ..enqueue(const <String, dynamic>{})
        ..enqueue({'track': 'internal'});

      await _api(recorder).release(
        track: PlayTrack.internal,
        versionCodes: [412],
      );

      final sent =
          jsonDecode(recorder.requests.last.body) as Map<String, dynamic>;
      final releases = sent['releases'] as List<dynamic>;
      expect(
        (releases.single as Map<String, dynamic>)['versionCodes'],
        ['412'],
      );
    });

    test('carries release notes as one entry per locale', () async {
      final recorder = Recorder()
        ..enqueue(const <String, dynamic>{})
        ..enqueue({'track': 'internal'});

      await _api(recorder).release(
        track: PlayTrack.internal,
        versionCodes: [412],
        releaseNotes: const {'ja-JP': '不具合の修正', 'en-US': 'Bug fixes'},
      );

      final sent =
          jsonDecode(recorder.requests.last.body) as Map<String, dynamic>;
      final releases = sent['releases'] as List<dynamic>;
      final notes =
          (releases.single as Map<String, dynamic>)['releaseNotes']
              as List<dynamic>;
      expect(notes, hasLength(2));
    });

    test('refuses a release with no version codes', () {
      final recorder = Recorder();

      expect(
        () => _api(recorder).release(
          track: PlayTrack.internal,
          versionCodes: const [],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(recorder.requests, isEmpty);
    });
  });
}
