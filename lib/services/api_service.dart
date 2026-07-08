import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _usersUrl = 'https://dummyjson.com/users?limit=100';

  // Verifies admin credentials against the DummyJSON users API.
  // Returns the user details map if successful, null if invalid credentials.
  static Future<Map<String, dynamic>?> authenticateAdmin(String username, String password) async {
    try {
      final response = await http.get(Uri.parse(_usersUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> users = data['users'] ?? [];

        for (var user in users) {
          if (user['username'] == username && user['password'] == password) {
            return user as Map<String, dynamic>;
          }
        }
      }
      return null;
    } catch (e) {
      // Re-throw or handle connection errors so they can be shown in custom dialogs
      throw Exception('Network error: Unable to reach authentication server. Please check your internet connection.');
    }
  }
}
