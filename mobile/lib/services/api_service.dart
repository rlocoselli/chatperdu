import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/report.dart';

class ApiService {
  Future<Map<String, dynamic>> _json(http.Response response,
      {required String fallback}) async {
    final dynamic raw = response.body.isEmpty ? {} : jsonDecode(response.body);
    final data = raw is Map<String, dynamic>
        ? raw
        : <String, dynamic>{'data': raw};
    if (response.statusCode >= 300) {
      throw Exception(data['error'] ?? fallback);
    }
    return data;
  }

  Future<Map<String, String>> _authHeaders() async {
    final p = await SharedPreferences.getInstance();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${p.getString('audela-token') ?? ''}'
    };
  }

  Future<bool> hasToken() async =>
      (await SharedPreferences.getInstance()).containsKey('audela-token');

  Uri audelaGoogleLoginUri({bool signup = false}) {
    final apiOrigin = Uri.parse(AppConfig.apiUrl).origin;
    final params = <String, String>{
      'mode': signup ? 'signup' : 'login',
      'redirect_to': apiOrigin,
    };
    return Uri.parse('${AppConfig.apiUrl}/auth/google/start').replace(
      queryParameters: params,
    );
  }

  Future<void> authenticate(String mode,
      {required String email,
      required String password,
      String name = ''}) async {
    final r = await http.post(Uri.parse('${AppConfig.apiUrl}/auth/$mode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}));
    final data = await _json(r, fallback: 'Connexion impossible');
    final p = await SharedPreferences.getInstance();
    await p.setString('audela-token', data['token']);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final r = await http.get(Uri.parse('${AppConfig.apiUrl}/notifications'),
        headers: await _authHeaders());
    return List<Map<String, dynamic>>.from(
        (await _json(r, fallback: 'Connexion requise'))['items']);
  }

  Future<Map<String, dynamic>> notificationPreferences() async {
    final r = await http.get(
        Uri.parse('${AppConfig.apiUrl}/notification-preferences'),
        headers: await _authHeaders());
    return Map<String, dynamic>.from(
        await _json(r, fallback: 'Connexion requise'));
  }

  Future<void> saveNotificationPreferences(Map<String, dynamic> data) async {
    final response = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/notification-preferences'),
        headers: await _authHeaders(), body: jsonEncode(data));
    await _json(response, fallback: 'Enregistrement impossible');
  }

  Future<List<Report>> reports(
      {String query = '', String status = 'Tous'}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/reports')
        .replace(queryParameters: {'q': query, 'status': status});
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    final data = await _json(response, fallback: 'Service indisponible');
    return (data['items'] as List)
        .map((e) => Report.fromJson(e))
        .toList();
  }

  Future<String> uploadImage(String path) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('${AppConfig.apiUrl}/uploads'));
    request.files.add(await http.MultipartFile.fromPath('file', path));
    final token =
        (await SharedPreferences.getInstance()).getString('audela-token');
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.Response.fromStream(await request.send());
    final data = await _json(response, fallback: 'Téléversement impossible');
    return data['path'] ?? data['url'] ?? '';
  }

  Future<Report> publish(Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('${AppConfig.apiUrl}/reports'),
        headers: await _authHeaders(), body: jsonEncode(data));
    return Report.fromJson(
        await _json(response, fallback: 'Publication impossible'));
  }

  Future<void> sighting(String id, String message,
      {String place = '', String contact = ''}) async {
    final r = await http.post(
        Uri.parse('${AppConfig.apiUrl}/reports/$id/sightings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'message': message, 'place': place, 'contact': contact}));
    await _json(r, fallback: 'Envoi impossible');
  }

  Future<void> deleteReport(String id) async {
    final r = await http.delete(Uri.parse('${AppConfig.apiUrl}/reports/$id'),
        headers: await _authHeaders());
    await _json(r, fallback: 'Suppression impossible');
  }
}
