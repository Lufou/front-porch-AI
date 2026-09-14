// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import 'package:flutter/material.dart';

/// Base font size for reading surfaces: chat bubbles, the composer, and the
/// message editor. Chat bubbles pass `StorageService.textScale` into
/// RichText themselves (Flutter's RichText default is noScaling, and the
/// ambient MediaQuery is what chrome uses — it can sit at 1.0 while the
/// pref is 2.0). Composer / edit still ride MediaQuery. Never *also*
/// multiply this base by the pref or you double-apply on Text() paths.
const double kReadingFontSize = 14.0;

/// Inclusive range for the Reading Size slider (General Settings and the
/// in-chat UI sheet share this).
const double kReadingScaleMin = 0.7;
const double kReadingScaleMax = 2.0;

/// Sidebar helper / journal preview copy. Contrast is primary text,
/// not a faint secondary.
const double kSidebarHelpFontSize = 13.0;

/// Shared prose style for reading surfaces. Callers add color / height / italic
/// but not a second scale factor.
TextStyle readingSurfaceStyle({
  required Color color,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontSize: kReadingFontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    height: height,
  );
}
