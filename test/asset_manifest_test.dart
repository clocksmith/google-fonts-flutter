import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/asset_manifest.dart';

const _fakeAssetManifestText = '{"value": "fake"}';
var _assetManifestLoadCount = 0;

void main() {
  setUpAll(() async {
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) {
      _assetManifestLoadCount++;
      final Uint8List encoded = utf8.encoder.convert(_fakeAssetManifestText);
      return Future.value(encoded.buffer.asByteData());
    });
  });

  tearDown(() async {
    _assetManifestLoadCount = 0;
    AssetManifest.reset();
  });

  testWidgets('AssetManifest loads', (tester) async {
    final manifestJson = await AssetManifest.json();
    _verifyAssetManifestLoadedOnce();
    _verifyAssetManifestContent(manifestJson);
  });

  testWidgets('AssetManifest loads once when called multiple times in succession', (tester) async {
    final manifestJson1 = await AssetManifest.json();
    _verifyAssetManifestLoadedOnce();
    _verifyAssetManifestContent(manifestJson1);

    final manifestJson2 = await AssetManifest.json();
    _verifyAssetManifestLoadedOnce();
    _verifyAssetManifestContent(manifestJson2);
  });

  testWidgets('AssetManifest loads once when called multiple times in parallel', (tester) async {
    final manifestJsons = await Future.wait([
      AssetManifest.json(),
      AssetManifest.json(),
      AssetManifest.json(),
    ]);
    _verifyAssetManifestLoadedOnce();
    manifestJsons.forEach(_verifyAssetManifestContent);
  });

  testWidgets(
      'AssetManifest loads once when called multiple times in parallel then multiple times in succession',
      (tester) async {
    final manifestJsons = await Future.wait([
      AssetManifest.json(),
      AssetManifest.json(),
      AssetManifest.json(),
    ]);
    _verifyAssetManifestLoadedOnce();
    manifestJsons.forEach(_verifyAssetManifestContent);

    final manifestJson3 = await AssetManifest.json();
    final manifestJson4 = await AssetManifest.json();
    _verifyAssetManifestLoadedOnce();
    _verifyAssetManifestContent(manifestJson3);
    _verifyAssetManifestContent(manifestJson4);
  });
}

void _verifyAssetManifestLoadedOnce() {
  expect(_assetManifestLoadCount, 1);
}

void _verifyAssetManifestContent(Map<String, dynamic> manifestJson) {
  expect(manifestJson['value'], 'fake');
}
