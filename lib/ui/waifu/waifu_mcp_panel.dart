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

import 'package:front_porch_ai/services/waifu/waifu.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/waifu/waifu_mcp_opt_in.dart';

/// Compile-fix after the chat MCP client was removed: keep the existing
/// opt-in checkbox, drop Docker/stdio connect (that path is gone).
class WaifuMcpPanel extends StatelessWidget {
  const WaifuMcpPanel({
    super.key,
    required this.session,
    required this.mcpOptIn,
    required this.onMcpOptIn,
    this.mcpLine,
  });

  final WaifuSession session;
  final bool mcpOptIn;
  final ValueChanged<bool> onMcpOptIn;
  final String? mcpLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('waifu-mcp-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WaifuMcpOptIn(
          value: mcpOptIn,
          pathMode: session.pathMode,
          onChanged: onMcpOptIn,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            kWaifuMcpOpenCodeHonesty,
            key: const Key('waifu-mcp-opencode-honesty'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        if (mcpLine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              mcpLine!,
              key: const Key('waifu-mcp-status'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
      ],
    );
  }
}
