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

/// Objectives eval tools — the same tools-vs-text fork Realism uses
/// (`fireStructuredEval` + `preferTextEvals`), not a third door and not
/// chat-reply / Waifu todo tools. Propose-a-quest stays on the judges;
/// this file is YES/NO completion and task generation only.
library;

import 'dart:convert';

import 'package:front_porch_ai/services/chat/eval_json_merge.dart';
import 'package:front_porch_ai/services/services.dart' show LlmToolCall;

const String kObjectiveVerdictsTool = 'report_objective_verdicts';
const String kObjectiveTasksTool = 'report_objective_tasks';

Map<String, dynamic> _tool(
  String name,
  String description,
  Map<String, Map<String, dynamic>> fields,
  List<String> required,
) => {
  'type': 'function',
  'function': {
    'name': name,
    'description': description,
    'parameters': {
      'type': 'object',
      'properties': fields,
      'required': required,
    },
  },
};

final Map<String, Map<String, dynamic>> _verdictsFields = {
  'verdicts': {
    'type': 'array',
    'items': {'type': 'string'},
    'description': 'YES or NO for each numbered item, in order. Unsure is NO.',
  },
};

final Map<String, Map<String, dynamic>> _tasksFields = {
  'tasks': {
    'type': 'array',
    'items': {'type': 'string'},
    'description':
        'Sequential in-story actions the CHARACTER personally takes, '
        'never the user.',
  },
};

final List<Map<String, dynamic>> kObjectiveVerdictsEvalTools = [
  _tool(
    kObjectiveVerdictsTool,
    'Report whether each batched quest/task is complete.',
    _verdictsFields,
    const ['verdicts'],
  ),
];

final List<Map<String, dynamic>> kObjectiveTasksEvalTools = [
  _tool(
    kObjectiveTasksTool,
    'Report the character\'s own next steps for the objective.',
    _tasksFields,
    const ['tasks'],
  ),
];

List<String>? _asStringList(dynamic v) {
  if (v == null) return null;
  if (v is List) {
    return [
      for (final e in v)
        if (e != null) e.toString(),
    ];
  }
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return [s];
}

/// Convert a matching tool call into flat JSON the parsers consume.
/// Empty `verdicts`/`tasks` is a real answer (all-NO / parse-fail restore),
/// never a reason to fall back to text.
String? objectiveToolCallToJson(String toolName, List<LlmToolCall> calls) {
  for (final call in calls) {
    if (call.name != toolName) continue;
    final key = toolName == kObjectiveVerdictsTool
        ? 'verdicts'
        : toolName == kObjectiveTasksTool
        ? 'tasks'
        : null;
    if (key == null) continue;
    final list = _asStringList(call.arguments[key]);
    if (list == null) continue;
    return jsonEncode({key: list});
  }
  return null;
}

/// True only for an explicit yes. Confused / "1" / empty is NO — never
/// complete a quest because the model mumbled.
bool objectiveVerdictIsYes(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  final u = v.toString().trim().toUpperCase();
  if (u.isEmpty || u == 'NO' || u == 'FALSE' || u == 'N') return false;
  if (u == 'YES' || u == 'TRUE' || u == 'Y') return true;
  return RegExp(r'\bYES\b').hasMatch(u);
}

List<String>? _stringListFromJsonKey(String text, String key) {
  final decoded = parseEvalJsonObject(text);
  if (decoded == null || !decoded.containsKey(key)) return null;
  return _asStringList(decoded[key]);
}

/// One bool per batched item. Missing / unparsed items are false.
List<bool> parseObjectiveVerdicts(String text, int itemCount) {
  final out = List<bool>.filled(itemCount < 0 ? 0 : itemCount, false);
  if (itemCount <= 0) return out;
  final fromJson = _stringListFromJsonKey(text, 'verdicts');
  if (fromJson != null) {
    for (var i = 0; i < itemCount && i < fromJson.length; i++) {
      out[i] = objectiveVerdictIsYes(fromJson[i]);
    }
    return out;
  }
  final numbered = <int, bool>{};
  for (final m in RegExp(
    r'^\s*(\d+)\s*[:.)\-]\s*(YES|NO)\b',
    multiLine: true,
    caseSensitive: false,
  ).allMatches(text)) {
    numbered[int.parse(m.group(1)!)] = m.group(2)!.toUpperCase() == 'YES';
  }
  if (numbered.isEmpty && itemCount == 1) {
    numbered[1] = text.toUpperCase().contains('YES');
  }
  for (var i = 0; i < itemCount; i++) {
    out[i] = numbered[i + 1] ?? false;
  }
  return out;
}

/// Deduped, capped task maps (`description` + `completed: false`).
List<Map<String, dynamic>> parseObjectiveTasks(String text, int taskCount) {
  final cap = taskCount < 1 ? 1 : taskCount;
  final fromJson = _stringListFromJsonKey(text, 'tasks');
  final genTasks = <Map<String, dynamic>>[];
  void addDesc(String desc) {
    final t = desc.trim();
    if (t.isEmpty || t.startsWith('[')) return;
    genTasks.add({'description': t, 'completed': false});
  }

  if (fromJson != null) {
    for (final d in fromJson) {
      addDesc(d);
    }
  } else {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final numbered = RegExp(r'^\d+[\.\)\-]?\s*(.+)').firstMatch(trimmed);
      if (numbered != null) {
        addDesc(numbered.group(1)!);
        continue;
      }
      final bullet = RegExp(r'^[-•*]\s+(.+)').firstMatch(trimmed);
      if (bullet != null) {
        addDesc(bullet.group(1)!);
        continue;
      }
      if (trimmed.length > 15 &&
          !trimmed.endsWith(':') &&
          genTasks.length < cap) {
        addDesc(trimmed);
      }
    }
  }
  final seen = <String>{};
  return genTasks
      .where((t) => seen.add(t['description'] as String))
      .take(cap)
      .toList();
}

String buildObjectiveCheckPrompt({
  required String contextText,
  required List<String> itemLines,
  required bool toolsMode,
}) {
  final items = itemLines.join('\n');
  final closing = toolsMode
      ? 'Evaluate EACH item below. Report by calling the '
            '$kObjectiveVerdictsTool tool with a "verdicts" array of YES or '
            'NO, one per item, in order. Unsure is NO. Use ONLY the tool — '
            'no plain-text reply.\n$items'
      : 'Evaluate EACH item below. Reply with ONLY one line per item, in '
            'order, formatted exactly as "1: YES" or "1: NO" — no '
            'explanations.\n$items';
  return 'You are evaluating whether roleplay tasks/objectives have been '
      'completed based on recent conversation. Be generous in your '
      'assessment — if the events in the conversation show an item has '
      'been accomplished, partially fulfilled, or naturally resolved, '
      'answer YES for it.\n\n'
      'Recent conversation:\n$contextText\n\n'
      '$closing';
}

String buildObjectiveTaskGenPrompt({
  required String preamble,
  required String charName,
  required String userName,
  required String scenario,
  required String objective,
  required String chatContext,
  required int taskCount,
  required bool toolsMode,
}) {
  final closing = toolsMode
      ? 'Report by calling the $kObjectiveTasksTool tool with a "tasks" '
            'array of exactly $taskCount strings. Each string is a short, '
            'clear action $charName performs. Use ONLY the tool — no '
            'plain-text reply.'
      : 'Output ONLY a numbered list of exactly $taskCount tasks, one per '
            'line, like:\n'
            '1. [a specific action $charName takes]\n'
            '2. [a specific action $charName takes]\n'
            '...\n'
            'Each task is a short, clear action $charName performs. No '
            'preamble, no explanations, just the numbered list.';
  return '$preamble'
      'You are breaking an objective down into the concrete steps that '
      '$charName — the CHARACTER, not the user — will personally carry '
      'out to pursue it. '
      'Given the objective, context, and recent conversation below, '
      'generate exactly $taskCount sequential tasks that $charName '
      'performs to achieve the objective. '
      'Every task is an in-story action $charName personally takes — '
      'NEVER an instruction, request, or task assigned to $userName '
      '(the user/player). '
      'Write each task in the third person with $charName as the one '
      'acting. '
      'Tasks should be specific, actionable, and naturally progress the '
      'story. '
      'Do NOT include tasks for things that have already happened in the '
      'conversation.\n\n'
      'Character who carries out every task: $charName\n'
      'Scenario: $scenario\n'
      'Objective $charName is pursuing: $objective\n\n'
      'Recent conversation:\n$chatContext\n\n'
      '$closing';
}
