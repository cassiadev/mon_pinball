import 'pinball_test_harness.dart';

abstract class Hooks {
  static Future<void> beforeAll() => preparePinballTestEnvironment();

  static Future<void> beforeEach(String title, [List<String>? tags]) async {}

  static Future<void> afterEach(
    String title,
    bool success, [
    List<String>? tags,
  ]) async {}

  static Future<void> afterAll() async {}
}
