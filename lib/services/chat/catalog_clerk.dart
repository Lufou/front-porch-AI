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

import 'dart:convert';

import 'package:front_porch_ai/services/llm_service.dart';

/// Hard cap on advertised tool dispatches per character turn (doorbell
/// included). Extra `generateWithTools` trips after a ring are the clerk;
/// they never become the bubble.
const int kClerkMaxDispatchRounds = 3;

/// Joined scrap ceiling. Three wiki clips at [kWikiInjectCharCap] would
/// drown the mouth prompt; keep the collated block in the same neighborhood
/// as two full wiki pages.
const int kClerkCollateCharCap = 7000;

/// Prefix on tool-result rows so a follow-up `generateWithTools` fetches
/// another page instead of writing in character. Discarded if she speaks.
const String kClerkToolResultHint =
    'Library clip — not the spoken reply. Call another tool if this is too '
    'thin or you need another page. Do not write the character\'s line.';

/// Join unique mouth fragments. Wiki scraps keep their wiki wrapper;
/// web_search keeps UNTRUSTED. Empty list → null.
String? collateCatalogInjections(Iterable<String> parts) {
  final unique = <String>[];
  for (final raw in parts) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (unique.contains(t)) continue;
    unique.add(t);
  }
  if (unique.isEmpty) return null;
  var joined = unique.join('\n\n');
  if (joined.length <= kClerkCollateCharCap) return joined;
  return joined.substring(0, kClerkCollateCharCap).trim();
}

/// Cheap follow-up params: same prompt/samplers, no thinking, messages
/// carry the tool transcript. Doorbell params are left untouched.
GenerationParams clerkFollowupParams(
  GenerationParams base,
  List<Map<String, Object>> messages,
) {
  return GenerationParams(
    prompt: base.prompt,
    maxLength: base.maxLength,
    minLength: base.minLength,
    temperature: base.temperature,
    repeatPenalty: base.repeatPenalty,
    topP: base.topP,
    minP: base.minP,
    topK: base.topK,
    dryMultiplier: base.dryMultiplier,
    repPenTokens: base.repPenTokens,
    dynatempRange: base.dynatempRange,
    xtcThreshold: base.xtcThreshold,
    xtcProbability: base.xtcProbability,
    stopSequences: base.stopSequences,
    reasoningEnabled: false,
    reasoningEffort: base.reasoningEffort,
    reasoningMaxTokens: 0,
    salvageReasoning: false,
    bannedPhrases: base.bannedPhrases,
    systemPrompt: base.systemPrompt,
    grammar: base.grammar,
    banEosToken: base.banEosToken,
    trimStop: base.trimStop,
    images: base.images,
    toolChoice: base.toolChoice,
    onChunk: base.onChunk,
    stillWantTools: base.stillWantTools,
    backendIdentity: base.backendIdentity,
    chatMessages: messages,
  );
}

Map<String, Object> clerkAssistantToolCallMessage({
  required LlmToolCall call,
  required String callId,
  String text = '',
}) {
  return {
    'role': 'assistant',
    'content': text,
    'tool_calls': [
      {
        'id': callId,
        'type': 'function',
        'function': {
          'name': call.name,
          'arguments': jsonEncode(call.arguments),
        },
      },
    ],
  };
}

Map<String, Object> clerkToolResultMessage({
  required String callId,
  required String clip,
}) {
  final body = clip.trim();
  return {
    'role': 'tool',
    'tool_call_id': callId,
    'content': body.isEmpty
        ? kClerkToolResultHint
        : '$kClerkToolResultHint\n\n$body',
  };
}

String clerkCallId(LlmToolCall call, int n) {
  final id = call.id.trim();
  if (id.isNotEmpty) return id;
  return 'clerk_$n';
}
