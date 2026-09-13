// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Reading size is one pref and one MediaQuery scaler. Bubbles used to
// multiply StorageService.textScale on top of that scaler, so chat text
// jumped while the composer and the edit overlay stayed small.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/chat_components/chat_components.dart';
import 'package:front_porch_ai/ui/dialogs/dialogs.dart';
import 'package:front_porch_ai/ui/theme/theme.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

import '../../golden/support/fakes_storage.dart';

class _ReadingStorage extends FakeStorageService {
  _ReadingStorage(this.scale);
  final double scale;

  @override
  double get textScale => scale;

  @override
  String getChatFontFamily([
    CharacterCard? character,
    ChatThemePreset? themePreset,
    ChatThemeOverrides? themeOverrides,
  ]) => '';

  @override
  Color getUserTextColor([
    CharacterCard? character,
    ChatThemePreset? themePreset,
    ChatThemeOverrides? themeOverrides,
  ]) => Colors.white;

  @override
  Color getAiTextColor([
    CharacterCard? character,
    ChatThemePreset? themePreset,
    ChatThemeOverrides? themeOverrides,
  ]) => Colors.white;

  @override
  Color getDialogueColor([
    CharacterCard? character,
    ChatThemePreset? themePreset,
    ChatThemeOverrides? themeOverrides,
  ]) => Colors.amber;

  @override
  Color getActionColor([
    CharacterCard? character,
    ChatThemePreset? themePreset,
    ChatThemeOverrides? themeOverrides,
  ]) => Colors.lightBlue;
}

double _declaredFontSize(TextStyle? style) {
  final size = style?.fontSize;
  expect(
    size,
    isNotNull,
    reason: 'reading surface must set an explicit fontSize',
  );
  return size!;
}

double _scalerOf(Element element) =>
    MediaQuery.textScalerOf(element).scale(1.0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'at textScale 1.5, bubble, composer, and edit field move together without double-applying on bubbles',
    (tester) async {
      const scale = 1.5;
      final storage = _ReadingStorage(scale);
      final composer = TextEditingController(text: 'Hello composer');
      addTearDown(composer.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<StorageService>.value(
            value: storage,
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const StyledChatMessage(
                      text: '"Hello," she said.',
                      isUser: true,
                    ),
                    AppTextField(
                      key: const Key('composer'),
                      controller: composer,
                      style: readingSurfaceStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final bubbleText = tester.widget<RichText>(find.byType(RichText).first);
      final bubbleSize = _declaredFontSize((bubbleText.text as TextSpan).style);
      final bubbleElement = tester.element(find.byType(RichText).first);
      final bubbleScale = _scalerOf(bubbleElement);

      final composerField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('composer')),
          matching: find.byType(EditableText),
        ),
      );
      final composerSize = _declaredFontSize(composerField.style);
      final composerScale = _scalerOf(
        tester.element(find.byType(EditableText).first),
      );

      // Declared size is the shared base — not 14 * 1.5 = 21, which is the
      // double-apply that made bubbles jump while everything else lagged.
      expect(bubbleSize, kReadingFontSize);
      expect(composerSize, kReadingFontSize);
      expect(bubbleScale, scale);
      expect(composerScale, scale);
      expect(bubbleSize * bubbleScale, kReadingFontSize * scale);
      expect(composerSize * composerScale, bubbleSize * bubbleScale);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<StorageService>.value(
            value: storage,
            child: MaterialApp(
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showMessageEditDialog(
                      context: context,
                      initialText: 'Hello edit',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final editFields = find.byType(AppTextField);
      expect(editFields, findsWidgets);
      final bodyField = tester.widget<EditableText>(
        find.descendant(
          of: editFields.last,
          matching: find.byType(EditableText),
        ),
      );
      final editSize = _declaredFontSize(bodyField.style);
      final editScale = _scalerOf(
        tester.element(
          find.descendant(
            of: editFields.last,
            matching: find.byType(EditableText),
          ),
        ),
      );
      expect(editSize, kReadingFontSize);
      expect(editScale, scale);
      expect(editSize * editScale, bubbleSize * bubbleScale);
    },
  );

  testWidgets(
    'edit dialog re-applies the house scaler when the overlay drops it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (outer) {
              return MediaQuery(
                data: MediaQuery.of(
                  outer,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                // Inner context is what a chat bubble would have — the house
                // scaler lives on `home:`, not on the navigator overlay.
                child: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showMessageEditDialog(
                          context: context,
                          initialText: 'Hello edit',
                        );
                      },
                      child: const Text('Open'),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final body = find.descendant(
        of: find.byType(AppTextField).last,
        matching: find.byType(EditableText),
      );
      expect(_scalerOf(tester.element(body)), 1.5);
      final style = tester.widget<EditableText>(body).style;
      expect(_declaredFontSize(style) * 1.5, kReadingFontSize * 1.5);
    },
  );
}
