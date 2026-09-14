// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// After a web_search/MCP inject, the character completion point must still
// be the speaker prefix (`Name:`). PromptPlan insertion order IS render
// order; registering `web_search` after `suffix` left the untrusted dump
// as the last user-turn bytes the model continued from.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/prompt_injection/search_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_plan.dart';

void main() {
  test(
    'production plan registers web_search before suffix, chance_time after',
    () {
      final src = File('lib/services/chat/chat_service_generation_plan.dart')
          .readAsStringSync();
      final search = src.indexOf("id: 'web_search'");
      final suffix = src.indexOf("id: 'suffix'");
      final chance = src.indexOf("id: 'chance_time'");
      expect(search, greaterThanOrEqualTo(0));
      expect(
        suffix,
        greaterThan(search),
        reason: 'wiki dump after Name: makes the dump the completion point',
      );
      expect(
        chance,
        greaterThan(suffix),
        reason: 'Chance Time stays after suffix — do not bury it under search',
      );
    },
  );

  test('after inject, userText still ends on the speaker prefix', () {
    final plan = PromptPlan()
      ..add(id: 'history', text: 'Sam: what is zxqwt\n')
      ..add(
        id: 'web_search',
        text: '${SearchInjection.emptyResultFragment('zxqwt')}\n',
      )
      ..add(id: 'suffix', text: '\nMara:')
      ..add(id: 'chance_time', text: '')
      ..add(id: 'porch_night', text: '')
      ..add(id: 'item_intro', text: '');

    expect(
      plan.userText.trimRight(),
      endsWith('Mara:'),
      reason: 'the model must complete the character line, not the dump',
    );
    expect(
      plan.userText.indexOf('zxqwt'),
      lessThan(plan.userText.lastIndexOf('Mara:')),
    );
  });
}
