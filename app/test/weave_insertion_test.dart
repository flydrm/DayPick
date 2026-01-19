import 'package:flutter_test/flutter_test.dart';

import 'package:daypick/features/weave/weave_insertion.dart';

void main() {
  test('insertAfterCollectAnchor inserts after existing anchor', () {
    const body = 'Intro\n\n[[收集箱]]\n\nAfter';
    const insert = '> 闪念：A\n> body';
    final next = insertAfterCollectAnchor(body, insert);
    expect(next, 'Intro\n\n[[收集箱]]\n\n$insert\n\nAfter');
  });

  test('insertAfterCollectAnchor appends anchor when missing', () {
    const body = 'Intro';
    const insert = '> 任务：T';
    final next = insertAfterCollectAnchor(body, insert);
    expect(next, 'Intro\n\n[[收集箱]]\n\n$insert');
  });

  test('splitCollectAnchor removes anchor token from parts', () {
    const body = 'A\n\n[[收集箱]]\n\nB';
    final split = splitCollectAnchor(body);
    expect(split.hasAnchor, true);
    expect(split.before.contains('[[收集箱]]'), false);
    expect(split.after.contains('[[收集箱]]'), false);
  });
}
