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
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Web Search plus a dummy-proof note about the library `tools/` folder.
class PorchLifeMcpWebCard extends StatelessWidget {
  const PorchLifeMcpWebCard({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final toolsPath = storage.rootPath == null
        ? 'tools'
        : storage.toolsDir.path;
    return FeatureGroupCard(
      title: 'Web Search and extra tools',
      subtitle: 'looking things up, and recipe cards from your library',
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
        Padding(
          key: const Key('user-tools-folder-note'),
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: AppColors.iconSecondary(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Extra tools are JSON recipe cards you drop in the tools '
                  'folder next to chats and worlds — not programs, and not '
                  'a Docker server. Each card is a name, a short description, '
                  'and an HTTP address. Disabled or broken cards are skipped. '
                  'That folder is:\n$toolsPath',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
