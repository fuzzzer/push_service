import 'package:http/http.dart' as http;

class SimpleHttpClient {
  final http.Client _client;

  SimpleHttpClient({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) {
    return _client.post(url, headers: headers, body: body);
  }
}
