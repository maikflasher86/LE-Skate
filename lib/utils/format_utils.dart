import 'dart:convert';

import 'package:intl/intl.dart';

String formatDateTime(DateTime dateTime) =>
    DateFormat('dd.MM.yyyy HH:mm').format(dateTime.toLocal());

String formatJsonForDisplay(String rawJson) {
  if (rawJson.isEmpty) {
    return rawJson;
  }

  try {
    final decoded = jsonDecode(rawJson);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return rawJson;
  }
}

String truncateForLog(String text, {int maxLength = 2000}) {
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}... (gekürzt)';
}

String? extractJsonObject(String content) {
  final start = content.indexOf('{');
  final end = content.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return null;
  }
  return content.substring(start, end + 1);
}
