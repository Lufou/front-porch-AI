// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// Live ObjectiveProposal through the tools-vs-text fork. Canned LLM
// payloads — not source greps. Confused/unparsed must never fake a YES.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart' hide AvatarImage;
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/chat/objective_eval_tools.dart';
import 'package:front_porch_ai/services/chat/objective_proposal.dart';
import 'package:front_porch_ai/services/chat/pass_support.dart';
import 'package:front_porch_ai/services/chat/tool_eval_spec.dart';
import 'package:front_porch_ai/services/llm_service.dart';

class _FakeLlm extends LLMService {
  _FakeLlm(this._streamFactory);

  final Stream<String> Function(GenerationParams) _streamFactory;
  bool _ready = true;
  int streamCalls = 0;

  @override
  bool get isReady => _ready;
  set isReady(bool v) => _ready = v;

  @override
  String get backendName => 'fake-objective-tools';

  @override
  Stream<String> generateStream(GenerationParams params) {
    streamCalls++;
    return _streamFactory(params);
  }

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  bool get hasListeners => false;
  @override
  void notifyListeners() {}
  @override
  // ignore: must_call_super
  void dispose() {}
}

Objective _mkObj(String id, String o) => Objective(
  id: id,
  characterId: 'c1',
  objective: o,
  chatId: null,
  active: true,
  isPrimary: true,
  injectionDepth: 3,
  checkFrequency: 3,
  tasks: '[]',
  createdAt: DateTime.now(),
);

ObjectiveProposal _live({
  required _FakeLlm llm,
  required List<Objective> actives,
  List<Map<String, dynamic>> Function(Objective)? tasksFor,
  Future<void> Function(String, String)? saveTasks,
  Future<void> Function(Objective, String)? mark,
  Future<void> Function(String)? deact,
  LlmToolResponse? Function(ToolEvalSpec spec)? onTool,
  bool preferText = false,
}) {
  final probe = ToolTransportProbe();
  return ObjectiveProposal(
    stripThinkBlocks: (t) => t,
    getLlmService: () => llm,
    getActiveCharacter: () => CharacterCard(name: 'Nia', scenario: 'dock'),
    getActiveGroup: () => null,
    getIsObserverMode: () => false,
    getUserName: () => 'User',
    getRealismEnabled: () => true,
    getMessages: () => const <ChatMessage>[],
    getActiveObjectives: () => actives,
    tasksForObjective: tasksFor ?? (o) => const [],
    loadActiveObjectives: () async {},
    saveObjectiveTasks: saveTasks ?? (id, j) async {},
    deactivateObjective: deact ?? (id) async {},
    markTaskCompleted: mark ?? (obj, desc) async {},
    getIsCheckingCompletion: () => false,
    setIsCheckingCompletion: (v) {},
    onNotify: () {},
    fireToolEval: (ToolEvalSpec spec) async => onTool?.call(spec),
    probe: probe,
    getBackendIdentity: () => 'fake-objective-tools||',
    getPreferTextEvals: () => preferText,
  );
}

LlmToolResponse _verdicts(List<dynamic> verdicts) => LlmToolResponse(
  calls: [
    LlmToolCall(
      name: kObjectiveVerdictsTool,
      arguments: {'verdicts': verdicts},
    ),
  ],
  text: '',
);

LlmToolResponse _tasks(List<String> tasks) => LlmToolResponse(
  calls: [
    LlmToolCall(name: kObjectiveTasksTool, arguments: {'tasks': tasks}),
  ],
  text: '',
);

void main() {
  group('live checker — tools payload', () {
    test('YES tool call marks the open task complete', () async {
      final marks = <String>[];
      final llm = _FakeLlm((_) => Stream.value('1: YES from text — ignore'));
      final p = _live(
        llm: llm,
        actives: [_mkObj('o1', 'find the keeper')],
        tasksFor: (o) => [
          {'description': 'ask at the dock', 'completed': false},
        ],
        mark: (obj, desc) async => marks.add('${obj.id}:$desc'),
        // Boolean true, not the string "YES" — the text scrape's
        // contains('YES') fallback must not be what makes this pass.
        onTool: (_) => _verdicts([true]),
      );
      await p.checkTaskCompletionInBackground();
      expect(marks, ['o1:ask at the dock']);
      expect(
        llm.streamCalls,
        0,
        reason: 'usable tool call must not text-retry',
      );
    });

    test('NO / garbage / empty verdicts never fake a win', () async {
      for (final payload in [
        _verdicts(['NO']),
        _verdicts(['HUH']),
        _verdicts([]),
        _verdicts(['maybe later']),
      ]) {
        final marks = <String>[];
        final deacts = <String>[];
        final llm = _FakeLlm((_) => Stream.value('1: YES'));
        final p = _live(
          llm: llm,
          actives: [_mkObj('oNo', 'find the keeper')],
          tasksFor: (o) => [
            {'description': 'ask at the dock', 'completed': false},
          ],
          mark: (obj, desc) async => marks.add(desc),
          deact: (id) async => deacts.add(id),
          onTool: (_) => payload,
        );
        await p.checkTaskCompletionInBackground();
        expect(marks, isEmpty, reason: '$payload must not complete');
        expect(deacts, isEmpty, reason: '$payload must not retire the quest');
        expect(llm.streamCalls, 0);
      }
    });
  });

  group('live task gen — tools payload', () {
    test('tasks array is saved', () async {
      final saved = <String, String>{};
      final llm = _FakeLlm(
        (_) => Stream.value('gibberish that must not parse'),
      );
      final p = _live(
        llm: llm,
        actives: const [],
        saveTasks: (id, j) async => saved[id] = j,
        tasksFor: (o) => const [],
        onTool: (_) => _tasks([
          'Nia asks the harbour master about the keeper',
          'Nia walks the cliff path at dusk',
        ]),
      );
      await p.generateObjectiveTasks(
        _mkObj('oT', 'find the keeper'),
        taskCount: 2,
      );
      final parsed = (jsonDecode(saved['oT']!) as List)
          .cast<Map<String, dynamic>>();
      expect(parsed.map((t) => t['description']), [
        'Nia asks the harbour master about the keeper',
        'Nia walks the cliff path at dusk',
      ]);
      expect(parsed.every((t) => t['completed'] == false), isTrue);
      expect(llm.streamCalls, 0);
    });
  });

  group('text path still scrapes', () {
    test('1: YES completes', () async {
      final marks = <String>[];
      final llm = _FakeLlm((_) => Stream.value('1: YES'));
      final p = _live(
        llm: llm,
        actives: [_mkObj('oY', 'g')],
        tasksFor: (o) => [
          {'description': 'do the thing', 'completed': false},
        ],
        mark: (obj, desc) async => marks.add(desc),
        onTool: (_) => null,
      );
      await p.checkTaskCompletionInBackground();
      expect(marks, ['do the thing']);
    });

    test('1. do the thing saves a task', () async {
      final saved = <String, String>{};
      final llm = _FakeLlm(
        (_) => Stream.value('1. do the thing\n2. then this'),
      );
      final p = _live(
        llm: llm,
        actives: const [],
        saveTasks: (id, j) async => saved[id] = j,
        onTool: (_) => null,
      );
      await p.generateObjectiveTasks(_mkObj('oL', 'g'), taskCount: 2);
      final parsed = (jsonDecode(saved['oL']!) as List)
          .cast<Map<String, dynamic>>();
      expect(parsed.map((t) => t['description']), [
        'do the thing',
        'then this',
      ]);
    });

    test('preferText skips the tool even when a YES call is waiting', () async {
      final marks = <String>[];
      final llm = _FakeLlm((_) => Stream.value('1: NO'));
      var toolCalls = 0;
      final p = _live(
        llm: llm,
        actives: [_mkObj('oP', 'g')],
        tasksFor: (o) => [
          {'description': 'do', 'completed': false},
        ],
        mark: (obj, desc) async => marks.add(desc),
        preferText: true,
        onTool: (_) {
          toolCalls++;
          return _verdicts(['YES']);
        },
      );
      await p.checkTaskCompletionInBackground();
      expect(toolCalls, 0);
      expect(marks, isEmpty);
      expect(llm.streamCalls, 1);
    });
  });

  group('parsers', () {
    test('JSON verdicts align to the batch; extras dropped; shorts are NO', () {
      expect(parseObjectiveVerdicts('{"verdicts":["YES","NO","YES"]}', 2), [
        true,
        false,
      ]);
      expect(parseObjectiveVerdicts('{"verdicts":["YES"]}', 2), [true, false]);
      expect(parseObjectiveVerdicts('{"verdicts":[]}', 1), [false]);
    });

    test('numbered scrape still reads 1: YES', () {
      expect(parseObjectiveVerdicts('1: YES\n2: NO', 2), [true, false]);
      expect(parseObjectiveVerdicts('1. YES', 1), [true]);
    });
  });
}
