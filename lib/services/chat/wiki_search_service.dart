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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:front_porch_ai/services/chat/mediawiki_search.dart';
import 'package:front_porch_ai/services/chat/web_search_service.dart';

/// Same turn window as [shouldAdvertiseWebSearch], but the switch is "this
/// chat has a usable wiki URL" instead of the Porch Life web-search global.
bool shouldAdvertiseWikiSearch({
  required String wikiUrl,
  required bool directUserSend,
  required bool continueMode,
  required bool toolsUnsupported,
  bool autonomousMode = false,
}) {
  return parseWikiBaseUrl(wikiUrl) != null &&
      directUserSend &&
      !continueMode &&
      !autonomousMode &&
      !toolsUnsupported;
}

/// MediaWiki / Fandom lookup against the pasted host. Session cache; HTTP
/// only on a miss from an eligible direct user send.
class WikiSearchService {
  WikiSearchService({required this.getBaseUrl, this.sendRequest});

  final String Function() getBaseUrl;

  /// Request-level test seam. Production leaves this null.
  Future<http.Response> Function(http.BaseRequest request)? sendRequest;

  bool get isActive => parseWikiBaseUrl(getBaseUrl()) != null;

  int httpCalls = 0;
  final Map<String, String> _cache = {};
  int _httpThisSend = 0;

  void beginUserSend() => _httpThisSend = 0;

  void resetCache() {
    _cache.clear();
    _httpThisSend = 0;
  }

  void resetForFreshChat() => resetCache();

  Future<WebSearchResult> lookup(String query) async {
    final base = parseWikiBaseUrl(getBaseUrl());
    if (base == null) {
      return const WebSearchResult(
        query: '',
        snippet: '',
        fromCache: false,
        httpAttempted: false,
      );
    }
    final raw = WebSearchService.prepareQuery(query);
    if (raw.isEmpty) {
      return const WebSearchResult(
        query: '',
        snippet: '',
        fromCache: false,
        httpAttempted: false,
      );
    }
    final key = '${base.host}|${WebSearchService.normalizeQuery(raw)}';
    final cached = _cache[key];
    if (cached != null) {
      return WebSearchResult(
        query: raw,
        snippet: cached,
        fromCache: true,
        httpAttempted: false,
      );
    }
    if (_httpThisSend >= 1) {
      return WebSearchResult(
        query: raw,
        snippet: '',
        fromCache: false,
        httpAttempted: false,
      );
    }
    _httpThisSend++;
    final snippet = await _httpLookup(base, raw);
    if (snippet.trim().isEmpty) {
      return WebSearchResult(
        query: raw,
        snippet: '',
        fromCache: false,
        httpAttempted: true,
      );
    }
    _cache[key] = snippet;
    return WebSearchResult(
      query: raw,
      snippet: snippet,
      fromCache: false,
      httpAttempted: true,
    );
  }

  Future<String> _httpLookup(Uri wikiBase, String query) async {
    httpCalls++;
    final uri = mediawikiSearchUri(wikiBase, query);
    try {
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'application/json';
      final response = await _sendWithoutRedirects(request);
      debugPrint(
        '[WikiSearch] ${uri.host} status=${response.statusCode} '
        'bodyChars=${response.body.length}',
      );
      if (response.statusCode != 200) return '';
      if (response.bodyBytes.length > kMediaWikiMaxBodyBytes) return '';
      return parseMediaWikiBody(response.body);
    } catch (e) {
      debugPrint('[WikiSearch] THREW: $e');
      return '';
    }
  }

  Future<http.Response> _sendWithoutRedirects(http.Request request) async {
    request
      ..followRedirects = false
      ..maxRedirects = 0;
    final custom = sendRequest;
    if (custom != null) {
      return custom(request).timeout(kWebSearchTimeout);
    }
    final client = http.Client();
    try {
      return await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(kWebSearchTimeout);
    } finally {
      client.close();
    }
  }
}
