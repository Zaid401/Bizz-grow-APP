import 'dart:convert';

import 'package:http/http.dart' as http;

class AiUploadService {
  AiUploadService({http.Client? client}) : _client = client ?? http.Client();

  static const String _endpoint =
      'https://zyaawadtgdvawkdmnkcz.supabase.co/functions/v1/ai-product-detection';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5YWF3YWR0Z2R2YXdrZG1ua2N6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwOTI5MjQsImV4cCI6MjA4NTY2ODkyNH0.KCpqd7e6YJ8y_Z1qn9YSvIfEE3sb1zX5oPkO_BwcGYU';

  final http.Client _client;

  Future<Map<String, dynamic>> analyzeProduct(String base64Image) async {
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: const {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
      },
      body: jsonEncode({
        'images': [base64Image],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Request failed: ${response.statusCode} ${response.reasonPhrase ?? ''}\n${response.body}',
      );
    }

    return _parseJson(response.body);
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final extracted = _extractPayload(decoded);
        if (extracted != null) return extracted;
        return decoded;
      }
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map<String, dynamic>) return first;
      }
    } catch (_) {}

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(body);
    if (match != null) {
      final decoded = jsonDecode(match.group(0)!);
      if (decoded is Map<String, dynamic>) {
        final extracted = _extractPayload(decoded);
        if (extracted != null) return extracted;
        return decoded;
      }
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map<String, dynamic>) return first;
      }
    }

    throw Exception('Invalid response format');
  }

  Map<String, dynamic>? _extractPayload(Map<String, dynamic> decoded) {
    for (final key in ['products', 'data', 'result', 'payload', 'output']) {
      final value = decoded[key];
      if (value is Map<String, dynamic>) return value;
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is Map<String, dynamic>) return first;
      }
    }
    return null;
  }
}
