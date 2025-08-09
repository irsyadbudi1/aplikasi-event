// api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://103.160.63.165/api';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic> _extractAuthPayload(dynamic decoded) {
    if (decoded == null) return {};
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('data') && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data']);
      } else {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return {};
  }

  // ==================== REGISTER ====================
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String studentNumber,
    required String major,
    required String classYear,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'student_number': studentNumber,
          'major': major,
          'class_year': int.tryParse(classYear) ?? classYear,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      print('Register Status: ${response.statusCode} ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final payload = _extractAuthPayload(decoded);
        final token = payload['token'] ?? decoded['token'];
        final user = payload['user'] ?? decoded['user'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          if (user != null) {
            await prefs.setString('user', jsonEncode(user));
          }
          return {'success': true, 'data': payload.isNotEmpty ? payload : decoded};
        } else {
          return {'success': false, 'message': 'Token not found in response'};
        }
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Registration failed',
          'errors': decoded['errors']
        };
      }
    } catch (e) {
      print('Register Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== LOGIN ====================
  static Future<Map<String, dynamic>> login({
    required String studentNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'student_number': studentNumber,
          'password': password,
        }),
      );

      print('Login Status: ${response.statusCode} ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final payload = _extractAuthPayload(decoded);
        final token = payload['token'] ?? decoded['token'];
        final user = payload['user'] ?? decoded['user'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          if (user != null) await prefs.setString('user', jsonEncode(user));
          return {'success': true, 'data': payload.isNotEmpty ? payload : decoded};
        } else {
          return {'success': false, 'message': 'Token not found in response'};
        }
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Login failed',
          'errors': decoded['errors']
        };
      }
    } catch (e) {
      print('Login Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== GET ALL EVENTS (full pagination, no filter here) ====================
  static Future<Map<String, dynamic>> getEvents({bool sorted = true}) async {
    try {
      final headers = await _getHeaders();
      int page = 1;
      List<Map<String, dynamic>> allEvents = [];

      while (true) {
        final uri = Uri.parse('$baseUrl/events').replace(queryParameters: {
          'page': page.toString(),
          'per_page': '100'
        });

        final response = await http.get(uri, headers: headers);
        print('Get Events Page $page: ${response.statusCode}');

        if (response.body.isEmpty) {
          return {'success': false, 'message': 'Empty response from server'};
        }

        final decoded = jsonDecode(response.body);

        if (response.statusCode != 200) {
          if (response.statusCode == 401) {
            return {'success': false, 'message': 'Unauthenticated'};
          }
          return {'success': false, 'message': decoded['message'] ?? 'Failed to load events'};
        }

        final rawData = decoded['data'];
        if (rawData is Map && rawData.containsKey('events') && rawData['events'] is List) {
          for (var e in rawData['events']) {
            if (e is Map) {
              allEvents.add(Map<String, dynamic>.from(e));
            }
          }

          // cek pagination
          final pagination = rawData['pagination'];
          if (pagination is Map &&
              pagination.containsKey('current_page') &&
              pagination.containsKey('last_page')) {
            if (pagination['current_page'] >= pagination['last_page']) {
              break;
            }
          } else {
            break;
          }
        } else {
          break;
        }

        page++;
      }

      // Urutkan berdasarkan created_at terbaru jika diminta
      if (sorted) {
        allEvents.sort((a, b) {
          final ad = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
          final bd = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
          return bd.compareTo(ad);
        });
      }

      return {'success': true, 'data': allEvents};
    } catch (e) {
      print('Get Events Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== CREATE EVENT ====================
  static Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required String startDateTime, // format: yyyy-MM-dd HH:mm:ss
    required String endDateTime,   // format: yyyy-MM-dd HH:mm:ss
    required String location,
    required int maxAttendees,
    required int price,
    required String category,
    required String imageUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Unauthorized. Please login.'};
      }

      final headers = await _getHeaders();
      final body = jsonEncode({
        "title": title,
        "description": description,
        "start_date": startDateTime,
        "end_date": endDateTime,
        "location": location,
        "max_attendees": maxAttendees,
        "price": price,
        "category": category,
        "image_url": imageUrl
      });

      print('Create Event Request: headers=$headers body=$body');

      final response = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: headers,
        body: body,
      );

      print('Create Event Status: ${response.statusCode} ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': decoded['data'] ?? decoded};
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Validation error',
          'errors': decoded['errors'] ?? {}
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Unauthorized. Please login again.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to create event'};
      }
    } catch (e) {
      print('Create Event Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== AUTH UTILS ====================
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null && userString.isNotEmpty) {
      try {
        return jsonDecode(userString) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }
}
