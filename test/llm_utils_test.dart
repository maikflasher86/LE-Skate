import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/utils/llm_utils.dart';

Map<String, dynamic> _training(String id) => {
  'id': id,
  'score': 50,
  'llm_score': null,
  'verdict': 'Maybe',
  'reason': 'heuristic',
  'recommendation': null,
};

Map<String, dynamic> _payload(List<String> ids) => {
  'fetched_at': '2026-07-05T09:30:00.000',
  'trainings': [for (final id in ids) _training(id)],
};

/// Wraps [text] in a Gemini-style response body.
String _llmBody(String text) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': text},
        ],
      },
    },
  ],
});

String _evaluations(List<Map<String, dynamic>> items) =>
    jsonEncode({'evaluations': items});

Map<String, dynamic> _merge(Map<String, dynamic> payload, String? llmBody) =>
    mergeLlmEvaluationsInPayload({'payload': payload, 'llmBody': llmBody});

List<Map<String, dynamic>> _trainings(Map<String, dynamic> payload) =>
    (payload['trainings'] as List).cast<Map<String, dynamic>>();

void main() {
  group('mergeLlmEvaluationsInPayload', () {
    test('maps verdicts case-insensitively and ignores unknown verdicts', () {
      final result = _merge(
        _payload(['a', 'b', 'c', 'd']),
        _llmBody(
          _evaluations([
            {'id': 'a', 'verdict': 'GO'},
            {'id': 'b', 'verdict': 'maybe'},
            {'id': 'c', 'verdict': 'No'},
            {'id': 'd', 'verdict': 'perhaps'},
          ]),
        ),
      );

      expect(_trainings(result).map((t) => t['verdict']), [
        'Go',
        'Maybe',
        'No',
        'Maybe', // unchanged
      ]);
    });

    test('clamps scores to 0–100 and truncates decimals', () {
      final result = _merge(
        _payload(['a', 'b', 'c']),
        _llmBody(
          _evaluations([
            {'id': 'a', 'score': 150},
            {'id': 'b', 'score': -5},
            {'id': 'c', 'score': 72.6},
          ]),
        ),
      );

      final trainings = _trainings(result);
      expect(trainings.map((t) => t['score']), [100, 0, 72]);
      expect(trainings.map((t) => t['llm_score']), [100, 0, 72]);
    });

    test('trims the reason and keeps the recommendation as-is', () {
      final result = _merge(
        _payload(['a']),
        _llmBody(
          _evaluations([
            {
              'id': 'a',
              'reason': '  Trocken.  ',
              'recommendation': ' Früher starten ',
            },
          ]),
        ),
      );

      final training = _trainings(result).single;
      expect(training['reason'], 'Trocken.');
      // NOTE: current behaviour – the recommendation is not trimmed.
      expect(training['recommendation'], ' Früher starten ');
    });

    test('ignores blank reason and recommendation', () {
      final result = _merge(
        _payload(['a']),
        _llmBody(
          _evaluations([
            {'id': 'a', 'reason': '   ', 'recommendation': ''},
          ]),
        ),
      );

      final training = _trainings(result).single;
      expect(training['reason'], 'heuristic');
      expect(training['recommendation'], isNull);
    });

    test('leaves trainings without a matching id untouched', () {
      final result = _merge(
        _payload(['a', 'b']),
        _llmBody(
          _evaluations([
            {'id': 'a', 'score': 90, 'verdict': 'go'},
            {'score': 10, 'verdict': 'no'}, // no id → ignored
            {'id': 'unknown', 'score': 10, 'verdict': 'no'},
          ]),
        ),
      );

      final trainings = _trainings(result);
      expect(trainings[0]['score'], 90);
      expect(trainings[0]['verdict'], 'Go');
      expect(trainings[1], _training('b'));
    });

    test('extracts JSON wrapped in markdown fences across parts', () {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '```json\n{"evaluations": [{"id": "a", '},
                {'text': '"score": 88}]}\n```'},
              ],
            },
          },
        ],
      });

      final result = _merge(_payload(['a']), body);
      expect(_trainings(result).single['llm_score'], 88);
    });

    test('returns the payload unchanged for empty or unusable input', () {
      final expected = _payload(['a']);

      expect(_merge(_payload(['a']), null), expected);
      expect(_merge(_payload(['a']), ''), expected);
      expect(_merge(_payload(['a']), jsonEncode({'candidates': []})), expected);
      expect(_merge(_payload(['a']), jsonEncode({})), expected);
      expect(_merge(_payload(['a']), _llmBody('no json here')), expected);
      expect(
        _merge(_payload(['a']), _llmBody(_evaluations([]))),
        expected,
      );
      expect(_merge(_payload(['a']), _llmBody('{}')), expected);
    });

    test('throws on malformed JSON', () {
      // NOTE: current behaviour – malformed JSON is not caught here; the
      // caller (ForecastService) wraps it into an exception.
      expect(
        () => _merge(_payload(['a']), 'not json'),
        throwsFormatException,
      );
      expect(
        () => _merge(_payload(['a']), _llmBody('{not json}')),
        throwsFormatException,
      );
    });
  });
}
