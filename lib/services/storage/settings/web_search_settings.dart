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

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'settings_base.dart';

/// Global default + Tavily API key for model-initiated web search.
///
/// Default OFF. The global is read live at generation time, so flipping it
/// applies to already-open chats. There is no per-chat or sidebar override.
///
/// The key lives in SharedPreferences — the same durable store as OpenRouter
/// keys and MCP tokens. macOS keychain was the previous store; ad-hoc /
/// Rawhide launches often come back empty (the reason MCP left the
/// keychain). A leftover keychain value is copied into prefs on load.
/// No key → Wikipedia.
class WebSearchSettings with SettingsBase {
  WebSearchSettings({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  }) : _secureStorage = secureStorage;

  static const _apiKeyName = 'search_api_key';

  final FlutterSecureStorage _secureStorage;
  bool _webSearchDefault = false;
  String _searchApiKey = '';
  String _wikiBaseUrl = '';
  final Map<String, String> _wikiBySession = {};

  bool get webSearchDefault => _webSearchDefault;
  String get searchApiKey => _searchApiKey;
  bool get hasApiKey => _searchApiKey.trim().isNotEmpty;

  /// Porch Life default wiki URL. Empty = wiki_search off for chats that
  /// have not pasted their own.
  String get wikiBaseUrl => _wikiBaseUrl;

  /// This chat's wiki URL: session override if one was saved (including
  /// explicit empty = off), otherwise the Porch Life default.
  String wikiUrlForChat(String? sessionId) {
    if (sessionId != null && _wikiBySession.containsKey(sessionId)) {
      return _wikiBySession[sessionId]!;
    }
    return _wikiBaseUrl;
  }

  Future<void> load() async {
    _webSearchDefault = prefs?.getBool(k('web_search_default')) ?? false;
    _wikiBaseUrl = prefs?.getString(k('wiki_base_url')) ?? '';
    _wikiBySession
      ..clear()
      ..addAll(_decodeWikiMap(prefs?.getString(k('wiki_urls_by_session'))));
    final key = k(_apiKeyName);
    // Null prefs = in-memory sandbox. Never read the live macOS keychain.
    if (prefs == null) {
      _searchApiKey = '';
      return;
    }
    final fromPrefs = prefs?.getString(key)?.trim() ?? '';
    if (fromPrefs.isNotEmpty) {
      _searchApiKey = fromPrefs;
      if (prefs?.getString(key) != fromPrefs) {
        await prefs?.setString(key, fromPrefs);
      }
      return;
    }
    try {
      final secured = (await _secureStorage.read(key: key))?.trim() ?? '';
      if (secured.isEmpty) {
        _searchApiKey = '';
        return;
      }
      _searchApiKey = secured;
      await prefs?.setString(key, secured);
    } catch (e, st) {
      _searchApiKey = '';
      debugPrint('[WebSearch] keychain read failed (prefs empty): $e\n$st');
    }
  }

  Future<void> setWebSearchDefault(bool value) async {
    _webSearchDefault = value;
    await prefs?.setBool(k('web_search_default'), value);
    notify();
  }

  Future<void> setSearchApiKey(String value) async {
    final key = k(_apiKeyName);
    final trimmed = value.trim();
    _searchApiKey = trimmed;
    if (prefs == null) {
      notify();
      return;
    }
    if (trimmed.isEmpty) {
      await prefs?.remove(key);
    } else {
      await prefs?.setString(key, trimmed);
    }
    try {
      if (trimmed.isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: trimmed);
      }
    } catch (e, st) {
      debugPrint('[WebSearch] keychain write failed (prefs kept): $e\n$st');
    }
    notify();
  }

  Future<void> setWikiBaseUrl(String value) async {
    _wikiBaseUrl = value.trim();
    final key = k('wiki_base_url');
    if (_wikiBaseUrl.isEmpty) {
      await prefs?.remove(key);
    } else {
      await prefs?.setString(key, _wikiBaseUrl);
    }
    notify();
  }

  Future<void> setChatWikiUrl(String sessionId, String value) async {
    if (sessionId.isEmpty) {
      await setWikiBaseUrl(value);
      return;
    }
    _wikiBySession[sessionId] = value.trim();
    await _persistWikiMap();
    notify();
  }

  Future<void> applyWikiUrlForSession(String? sessionId, String url) async {
    if (sessionId == null || sessionId.isEmpty) {
      await setWikiBaseUrl(url);
    } else {
      await setChatWikiUrl(sessionId, url);
    }
  }

  Future<void> _persistWikiMap() async {
    final key = k('wiki_urls_by_session');
    if (_wikiBySession.isEmpty) {
      await prefs?.remove(key);
      return;
    }
    await prefs?.setString(key, jsonEncode(_wikiBySession));
  }

  static Map<String, String> _decodeWikiMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String) e.key as String: '${e.value ?? ''}',
      };
    } catch (_) {
      return {};
    }
  }
}
