import 'package:http/http.dart' as http;

/// Simple HTTP GET utility for making API calls
Future<String> getAPI({
  required String endpoint,
  Map<String, String>? queryParameters,
}) async {
  try {
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to get data from API: ${response.statusCode}');
    }
  } catch (e) {
    print('Failed to get data from API: $e');
    rethrow;
  }
}
