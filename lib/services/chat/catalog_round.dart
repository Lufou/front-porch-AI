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

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/services/chat/mediawiki_search.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/prompt_injection.dart';
import 'package:front_porch_ai/services/chat/tool_catalog.dart';
import 'package:front_porch_ai/services/chat/user_tool_cards.dart';
import 'package:front_porch_ai/services/chat/web_search_service.dart';
import 'package:front_porch_ai/services/chat/web_search_tools.dart';
import 'package:front_porch_ai/services/chat/wiki_search_service.dart';
import 'package:front_porch_ai/services/chat/wiki_search_tools.dart';
import 'package:front_porch_ai/services/llm_service.dart';

/// Outcome of the one tools round-trip over the unified catalog.
class CatalogRound {
  const CatalogRound({
    this.injection,
    this.searchReceipt,
    this.wikiReceipt,
    this.toolReceipt,
    this.spokenText,
  });

  final String? injection;
  final Map<String, dynamic>? searchReceipt;
  final Map<String, dynamic>? wikiReceipt;
  final Map<String, dynamic>? toolReceipt;

  /// Spoken character text from `generateWithTools` when no advertised
  /// tool fired. Dispatch may use this as the bubble instead of a second
  /// empty completion.
  final String? spokenText;
}

/// One `generateWithTools` with the flat catalog. Dispatches by source:
/// in-process `web_search` vs a user recipe card. A name that is not in the
/// advertised catalog is a no-op. Cap: first advertised call only.
Future<CatalogRound> runCatalogRound({
  required LLMService llm,
  required GenerationParams params,
  required CatalogBuildResult catalog,
  required WebSearchService search,
  WikiSearchService? wiki,
  Future<UserToolHttpResult> Function(
    CatalogTool entry,
    Map<String, dynamic> arguments,
  )?
  executeUserTool,
}) async {
  final tools = catalog.toOpenAiTools();
  debugPrint(
    '[Tools] catalog round backend=${llm.backendName} '
    'tools=${[for (final t in catalog.tools) t.name]} '
    'reasoning=${params.reasoningEnabled}',
  );
  LlmToolResponse? resp;
  try {
    resp = await llm.generateWithTools(params, tools);
  } catch (e) {
    debugPrint('[Tools] generateWithTools THREW: $e');
    return const CatalogRound();
  }
  if (resp == null) {
    debugPrint('[Tools] generateWithTools returned null (tools unsupported)');
    return const CatalogRound();
  }
  debugPrint(
    '[Tools] think calls=${resp.calls.map((c) => c.name).toList()} '
    'textChars=${resp.text.length}',
  );

  LlmToolCall? call;
  CatalogTool? entry;
  for (final c in resp.calls) {
    final found = catalog.lookup(c.name);
    if (found != null) {
      call = c;
      entry = found;
      break;
    }
    debugPrint(
      '[Tools] ignoring unadvertised call name=${c.name} (no-op, not in catalog)',
    );
  }
  if (call == null || entry == null) {
    final text = resp.text.trim();
    debugPrint(
      '[Tools] no advertised tool call — '
      '${text.isEmpty ? 'will stream in-character reply' : 'using spoken tools text'}',
    );
    return CatalogRound(spokenText: text.isEmpty ? null : text);
  }

  if (entry.source == ToolSource.inProcess &&
      entry.name == kWebSearchToolName) {
    return _dispatchSearch(call, search);
  }
  if (entry.source == ToolSource.inProcess &&
      entry.name == kWikiSearchToolName) {
    return _dispatchWiki(call, wiki);
  }
  if (entry.source == ToolSource.userCard) {
    return _dispatchUserCard(
      call: call,
      entry: entry,
      executeUserTool: executeUserTool,
    );
  }
  debugPrint('[Tools] no-op: catalog entry ${entry.name} has no dispatcher');
  return const CatalogRound();
}

Future<CatalogRound> _dispatchWiki(
  LlmToolCall call,
  WikiSearchService? wiki,
) async {
  if (wiki == null || !wiki.isActive) {
    final query = WebSearchService.prepareQuery(
      call.arguments['query']?.toString() ?? '',
    );
    return CatalogRound(
      injection: SearchInjection.emptyResultFragment(query),
      searchReceipt: {'query': query, 'ok': false, 'source': 'wiki'},
      wikiReceipt: {'query': query, 'ok': false, 'source': 'wiki'},
    );
  }
  final query = WebSearchService.prepareQuery(
    call.arguments['query']?.toString() ?? '',
  );
  debugPrint('[Tools] dispatch in-process wiki_search query="$query"');
  final outcome = await wiki.lookup(query);
  final injection = outcome.ok
      ? SearchInjection.wikiResultFragment(outcome.snippet)
      : SearchInjection.emptyResultFragment(outcome.query);
  final base = parseWikiBaseUrl(wiki.getBaseUrl());
  final receipt = <String, dynamic>{
    'query': outcome.query,
    'ok': outcome.ok,
    'cached': outcome.fromCache,
    'source': 'wiki',
    if (base != null) 'url': base.origin,
  };
  return CatalogRound(
    injection: injection,
    searchReceipt: receipt,
    wikiReceipt: receipt,
  );
}

Future<CatalogRound> _dispatchSearch(
  LlmToolCall call,
  WebSearchService search,
) async {
  final query = WebSearchService.prepareQuery(
    call.arguments['query']?.toString() ?? '',
  );
  debugPrint('[Tools] dispatch in-process web_search query="$query"');
  final outcome = await search.lookup(query);
  final injection = outcome.ok
      ? SearchInjection.resultFragment(outcome.snippet)
      : SearchInjection.emptyResultFragment(outcome.query);
  return CatalogRound(
    injection: injection,
    searchReceipt: {
      'query': outcome.query,
      'ok': outcome.ok,
      'cached': outcome.fromCache,
    },
  );
}

Future<CatalogRound> _dispatchUserCard({
  required LlmToolCall call,
  required CatalogTool entry,
  Future<UserToolHttpResult> Function(
    CatalogTool entry,
    Map<String, dynamic> arguments,
  )?
  executeUserTool,
}) async {
  debugPrint('[Tools] dispatch user card tool=${entry.name}');
  UserToolHttpResult result;
  if (executeUserTool != null) {
    result = await executeUserTool(entry, call.arguments);
  } else {
    final card = entry.card;
    if (card == null) {
      result = const UserToolHttpResult(ok: false, text: '');
    } else {
      result = await executeUserToolCard(card, call.arguments);
    }
  }
  final injection = result.ok
      ? UserToolInjection.resultFragment(result.text)
      : UserToolInjection.emptyResultFragment;
  return CatalogRound(
    injection: injection,
    toolReceipt: {'tool': entry.name, 'ok': result.ok},
  );
}
