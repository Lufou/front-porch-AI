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

part of '../chat_service.dart';

/// Model-initiated `web_search` / `wiki_search` — builders. Web search on/off
/// is the Porch Life global, read live. Wiki search is this chat's URL.
extension ChatServiceWebSearch on ChatService {
  WebSearchService _buildWebSearchService() {
    return WebSearchService(
      getApiKey: () => _storageService.webSearchSettings.searchApiKey,
      getGlobalDefault: () =>
          _storageService.webSearchSettings.webSearchDefault,
    );
  }

  WikiSearchService _buildWikiSearchService() {
    return WikiSearchService(
      getBaseUrl: () =>
          _storageService.webSearchSettings.wikiUrlForChat(_currentSessionId),
    );
  }

  String get _wikiBaseUrlImpl =>
      _storageService.webSearchSettings.wikiUrlForChat(_currentSessionId);

  Future<void> _setWikiBaseUrlImpl(String url) async {
    await _storageService.webSearchSettings.applyWikiUrlForSession(
      _currentSessionId,
      url,
    );
    notifyListeners();
  }
}
