// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// OpenRouter ↔ Nano-GPT (and oMLX) must restore that host's last model,
// same slot rule as the per-host API key vault.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/storage/settings/remote_api_key_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _openRouter = kOpenRouterApiV1;
const _nanoGpt = kNanoGptApiV1;

void _mockPathProvider() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_test_').path;
        }
        return null;
      });
}

Future<StorageService> _storage([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final service = StorageService();
  await service.initialized;
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _mockPathProvider();

  test('switching URL restores that host last model', () async {
    final storage = await _storage();
    await storage.setRemoteApiUrl(_openRouter);
    await storage.setRemoteModelName('x-ai/grok-4.6');
    await storage.setRemoteApiUrl(_nanoGpt);
    await storage.setRemoteModelName('moonshotai/kimi-k2.6:thinking');

    await storage.setRemoteApiUrl(_openRouter);
    expect(storage.remoteModelName, 'x-ai/grok-4.6');
    await storage.setRemoteApiUrl(_nanoGpt);
    expect(storage.remoteModelName, 'moonshotai/kimi-k2.6:thinking');
  });

  test(
    'oMLX backend keeps its own model without overwriting the URL slot',
    () async {
      final storage = await _storage();
      await storage.setBackendType('openRouter');
      await storage.setRemoteApiUrl(_openRouter);
      await storage.setRemoteModelName('x-ai/grok-4.6');

      await storage.setBackendType('omlx');
      await storage.setRemoteModelName('mlx-community/foo');
      expect(storage.remoteApiUrl, _openRouter);

      await storage.setBackendType('openRouter');
      expect(storage.remoteModelName, 'x-ai/grok-4.6');
      await storage.setBackendType('omlx');
      expect(storage.remoteModelName, 'mlx-community/foo');
    },
  );
}
