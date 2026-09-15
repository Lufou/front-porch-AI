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
/// Regen advertises (directUserSend on that path). Continue does not.
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
    if (_httpThisSend >= 4) {
      return WebSearchResult(
        query: raw,
        snippet: '',
        fromCache: false,
        httpAttempted: false,
      );
    }
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
    _httpThisSend++;
    final searchUri = mediawikiSearchUri(wikiBase, query);
    try {
      final searchResp = await _get(searchUri);
      debugPrint(
        '[WikiSearch] ${searchUri.host} search status=${searchResp.statusCode} '
        'bodyChars=${searchResp.body.length}',
      );
      if (searchResp.statusCode != 200) return '';
      if (searchResp.bodyBytes.length > kMediaWikiMaxBodyBytes) return '';
      final titles = parseMediaWikiSearchTitles(searchResp.body);
      if (usesMediaWikiActionApi(wikiBase) && titles.isNotEmpty) {
        httpCalls++;
        _httpThisSend++;
        final parseUri = mediawikiParseUri(wikiBase, titles.first);
        final parseResp = await _get(parseUri);
        debugPrint(
          '[WikiSearch] ${parseUri.host} parse page=${titles.first} '
          'status=${parseResp.statusCode} bodyChars=${parseResp.body.length}',
        );
        if (parseResp.statusCode == 200 &&
            parseResp.bodyBytes.length <= kMediaWikiMaxBodyBytes) {
          final parsed = parseMediaWikiParseHtml(parseResp.body);
          if (parsed.trim().isNotEmpty) return parsed;
        }
        httpCalls++;
        _httpThisSend++;
        final extractUri = mediawikiExtractUri(wikiBase, titles);
        final extractResp = await _get(extractUri);
        debugPrint(
          '[WikiSearch] ${extractUri.host} extract status='
          '${extractResp.statusCode} bodyChars=${extractResp.body.length}',
        );
        if (extractResp.statusCode == 200 &&
            extractResp.bodyBytes.length <= kMediaWikiMaxBodyBytes) {
          final extract = parseMediaWikiExtracts(extractResp.body);
          if (extract.trim().isNotEmpty) return extract;
        }
      }
      return parseMediaWikiBody(searchResp.body);
    } catch (e) {
      debugPrint('[WikiSearch] THREW: $e');
      return '';
    }
  }

  Future<http.Response> _get(Uri uri) async {
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'application/json';
    return _sendWithoutRedirects(request);
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
