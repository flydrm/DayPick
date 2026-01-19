import 'package:flutter_test/flutter_test.dart';

import 'package:daypick/features/notes/inline_route_token.dart';

void main() {
  test('stripInlineRouteToken extracts route and removes token', () {
    final parsed = stripInlineRouteToken('Buy milk [[route:/tasks/t-1]]');
    expect(parsed.route, '/tasks/t-1');
    expect(parsed.text, 'Buy milk');
  });

  test('stripInlineRouteToken ignores invalid route values', () {
    final parsed = stripInlineRouteToken('Buy milk [[route:tasks/t-1]]');
    expect(parsed.route, isNull);
    expect(parsed.text, 'Buy milk [[route:tasks/t-1]]');
  });

  test('stripInlineRouteToken keeps other [[...]] tokens', () {
    final parsed = stripInlineRouteToken('Intro [[收集箱]]');
    expect(parsed.route, isNull);
    expect(parsed.text, 'Intro [[收集箱]]');
  });
}
