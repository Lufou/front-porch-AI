// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/waifu/waifu.dart';

void main() {
  test(
    'preamble tells the model todowrite is not the end of the OpenCode turn',
    () {
      expect(
        kWaifuOpenCodePreamble,
        contains('todowrite does not finish the turn'),
      );
      expect(kWaifuOpenCodePreamble, contains('write, edit, or bash'));
      expect(
        RegExp(
          r'\bshe\b',
          caseSensitive: false,
        ).hasMatch(kWaifuOpenCodePreamble),
        isFalse,
      );
    },
  );

  test('preamble asks for an in-character wrap-up, not a generic recap', () {
    expect(
      kWaifuOpenCodePreamble,
      contains('what you did, then what is next if anything'),
    );
    expect(
      kWaifuOpenCodePreamble,
      contains('Always end as this character, never a generic agent recap'),
    );
    expect(
      kWaifuOpenCodePreamble,
      contains('The spoken reply is one in-character line'),
    );
  });
}
