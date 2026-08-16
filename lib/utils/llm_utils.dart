import 'dart:convert';

import 'package:inliner2/utils/format_utils.dart';

Map<String, dynamic> mergeLlmEvaluationsInPayload(Map<String, dynamic> input) {
  final payload = Map<String, dynamic>.from(
    input['payload'] as Map<String, dynamic>,
  );
  final llmBody = input['llmBody'] as String?;
  if (llmBody == null || llmBody.isEmpty) {
    return payload;
  }

  final outer = jsonDecode(llmBody) as Map<String, dynamic>;
  final candidates = outer['candidates'] as List<dynamic>?;
  if (candidates == null || candidates.isEmpty) {
    return payload;
  }

  final candidate = candidates.first as Map<String, dynamic>;
  final parts =
      (candidate['content'] as Map<String, dynamic>?)?['parts']
          as List<dynamic>?;
  final content = parts
      ?.whereType<Map<String, dynamic>>()
      .map((p) => p['text'] as String? ?? '')
      .join();
  if (content == null || content.isEmpty) {
    return payload;
  }

  final jsonContent = extractJsonObject(content);
  if (jsonContent == null) {
    return payload;
  }

  final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
  final llmEvaluations = (decoded['evaluations'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .toList();
  if (llmEvaluations.isEmpty) {
    return payload;
  }

  final byId = <String, Map<String, dynamic>>{
    for (final item in llmEvaluations)
      if (item['id'] is String) item['id'] as String: item,
  };

  final trainings = (payload['trainings'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final entry in trainings) {
    final id = entry['id'] as String?;
    if (id == null) {
      continue;
    }
    final llmItem = byId[id];
    if (llmItem == null) {
      continue;
    }

    final llmScore = (llmItem['score'] as num?)?.toInt();
    final llmVerdictRaw = (llmItem['verdict'] as String?)?.toLowerCase();
    final llmReason = llmItem['reason'] as String?;
    final llmRecommendation = llmItem['recommendation'] as String?;

    if (llmScore != null) {
      entry['score'] = llmScore.clamp(0, 100);
      entry['llm_score'] = llmScore.clamp(0, 100);
    }
    if (llmVerdictRaw != null) {
      if (llmVerdictRaw == 'go') {
        entry['verdict'] = 'Go';
      } else if (llmVerdictRaw == 'maybe') {
        entry['verdict'] = 'Maybe';
      } else if (llmVerdictRaw == 'no') {
        entry['verdict'] = 'No';
      }
    }
    if (llmReason != null && llmReason.trim().isNotEmpty) {
      entry['reason'] = llmReason.trim();
    }
    if (llmRecommendation != null && llmRecommendation.trim().isNotEmpty) {
      entry['recommendation'] = llmRecommendation;
    }
  }

  return payload;
}
