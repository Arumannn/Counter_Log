import "package:flutter_test/flutter_test.dart";
import "package:logbook_app_001/features/auth/login_controller.dart";

void main() {
  var actual, expected;

  group('Module 2 - Authentication', (){
    late LoginController controller;

    setUp(() {
      controller = LoginController();
    });

    test('Login with valid credentials should return user data', () {
      actual = controller.login('admin', 'admin123');
      expected = {
        'id': 'admin',
        'username': 'admin',
        'role': 'Ketua',
        'teamId': '1',
      };

      expect(actual, expected);
    });

    test('Login with invalid credentials should return null', () {
      actual = controller.login('invalid', 'invalid');
      expect(actual, null);
    });

    test('Logout should clear current user', () {
      controller.login('admin', 'admin123');
      controller.logout();
      expect(controller.currentUser, null);
    });
  });


}