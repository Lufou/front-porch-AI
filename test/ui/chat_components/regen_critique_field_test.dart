// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The optional regen-critique field must be visible on last-bot regen chrome
// (not on a greet / user bubble). Stacked in a short viewport, tapping it
// calls ensureVisible so the field is hittable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/tts_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/ui/chat_components/bubbles/message_bubble.dart';
import 'package:front_porch_ai/ui/chat_components/widgets/regen_critique_field.dart';

import '../../golden/support/creator_test_support.dart';
import '../../golden/support/fakes.dart';

StorageService _storage() {
  SharedPreferences.setMockInitialValues({});
  return StorageService();
}

const _fieldKey = Key('regen-critique-field');

void main() {
  setupPathProviderMock();

  Future<void> pumpBubble(
    WidgetTester tester, {
    required List<ChatMessage> messages,
    required int index,
  }) async {
    final character = CharacterCard(name: 'Mara');
    final chat = FakeChatService(
      activeCharacter: character,
      messages: messages,
    );
    addTearDown(chat.dispose);
    final tts = FakeTtsService();
    addTearDown(tts.dispose);
    final storage = _storage();
    addTearDown(storage.dispose);

    final bubble = MessageBubble(
      message: messages[index],
      index: index,
      character: character,
      chatService: chat,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<StorageService>.value(value: storage),
              ChangeNotifierProvider<TtsService>.value(value: tts),
              ChangeNotifierProvider<ChatService>.value(value: chat),
              ChangeNotifierProvider<UserPersonaService>.value(
                value: FakeUserPersonaService(),
              ),
            ],
            child: SizedBox(width: 680, child: bubble),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('field is visible on last-bot regen chrome', (tester) async {
    await pumpBubble(
      tester,
      messages: [
        ChatMessage(text: 'hi', sender: 'Sam', isUser: true),
        ChatMessage(
          text: 'He stands at the window.',
          sender: 'Mara',
          isUser: false,
        ),
      ],
      index: 1,
    );

    expect(find.byKey(_fieldKey), findsOneWidget);
    expect(find.text('why this take was wrong — optional'), findsOneWidget);
  });

  testWidgets('field is hidden on the opening greet', (tester) async {
    await pumpBubble(
      tester,
      messages: [
        ChatMessage(
          text: 'The porch light hums.',
          sender: 'Mara',
          isUser: false,
        ),
      ],
      index: 0,
    );
    expect(find.byKey(_fieldKey), findsNothing);
  });

  testWidgets('focusing a stacked field scrolls it into view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 180,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 500),
                  RegenCritiqueField(onChanged: (_) {}),
                  const SizedBox(height: 500),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byKey(_fieldKey);
    expect(field.hitTestable(), findsNothing);
    tester.widget<TextField>(field).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(field.hitTestable(), findsOneWidget);
  });
}
