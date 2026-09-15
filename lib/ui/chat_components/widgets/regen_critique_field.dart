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

import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Optional one-line reject reason on last-bot regen chrome.
class RegenCritiqueField extends StatefulWidget {
  const RegenCritiqueField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<RegenCritiqueField> createState() => _RegenCritiqueFieldState();
}

class _RegenCritiqueFieldState extends State<RegenCritiqueField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focus = FocusNode();
    _focus.addListener(_ensureVisible);
  }

  @override
  void dispose() {
    _focus.removeListener(_ensureVisible);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _ensureVisible() {
    if (!_focus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.85,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        key: const Key('regen-critique-field'),
        controller: _controller,
        focusNode: _focus,
        maxLines: 1,
        maxLength: 500,
        onChanged: widget.onChanged,
        style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context)),
        decoration: InputDecoration(
          hintText: 'why this take was wrong — optional',
          hintStyle: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary(context),
          ),
          isDense: true,
          counterText: '',
          filled: true,
          fillColor: AppColors.surfaceContainerOf(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: amber.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: amber.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: amber),
          ),
        ),
      ),
    );
  }
}
