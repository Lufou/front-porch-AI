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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/settings/widgets/widgets.dart';

/// MCP servers + Tavily/Wikipedia web search — their own Porch Life group
/// so they are not mixed in with Chaos / recap / absence.
class PorchLifeMcpWebCard extends StatelessWidget {
  const PorchLifeMcpWebCard({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    return FeatureGroupCard(
      title: 'MCP and Web',
      subtitle: 'tools from outside the porch, and looking things up',
      rows: [
        FeatureRow(
          icon: Icons.travel_explore,
          label: 'Web Search',
          need: FeatureNeed.alone,
          blurb:
              'When they hit a word or event they don\'t know, they can '
              'look it up and react as themselves — not reciting a wiki. '
              'Only the first reply to a message you send can search; '
              'Continue, Regenerate, guests, group follow-ups, and '
              'Dynamic Responses stay offline. '
              'Works with no key: search falls back to Wikipedia '
              '(encyclopedia lookups). Add a Tavily API key below '
              'for full web coverage. Off by default. Turning this on '
              'or off applies to every chat, including ones already open.',
          value: storage.webSearchSettings.webSearchDefault,
          onChanged: storage.webSearchSettings.setWebSearchDefault,
          showChildWhenOff: true,
          child: WebSearchKeyField(storage: storage),
        ),
        FeatureRow(
          icon: Icons.extension_outlined,
          label: 'MCP tools',
          need: FeatureNeed.alone,
          blurb:
              'Tools from MCP servers you run (Docker, weather, a '
              'calendar). Connecting a server is not consent: each chat '
              'has its own sidebar switches. This only seeds new chats. '
              'Off by default. Tap Docker or Find local servers, then '
              'Check connection. Front Porch does not spawn servers.',
          value: storage.mcpSettings.mcpDefault,
          onChanged: storage.mcpSettings.setMcpDefault,
          child: const McpServersPanel(),
        ),
      ],
    );
  }
}
