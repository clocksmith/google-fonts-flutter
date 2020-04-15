import 'dart:convert' as convert;
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AssetManifest {
//  static var _jsonMemoizer = AsyncMemoizer<Map<String, dynamic>>();
  static Map<String, dynamic> _json;
  static Future<Map<String, dynamic>> _jsonFuture;

  static Future<Map<String, dynamic>> json() {
    if (_jsonFuture == null) {
      _jsonFuture = _loadAssetManifestJson();
    }
    return _jsonFuture;
//    if (_json != null) {
//      return Future.value(_json);
//    }
//    Future<Map<String, dynamic>> future = _jsonMemoizer.runOnce(() => _loadAssetManifestJson());
//    future.then((value) => _json = value);
//    return future;
//  return _jsonMemoizer.runOnce(() => _loadAssetManifestJson());
//    return _loadAssetManifestJson();
  }

  static Future<Map<String, dynamic>> _loadAssetManifestJson() async {
    try {
      final jsonString = await rootBundle.loadString('AssetManifest.json', cache: false);
      return convert.json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading AssetManifest.json, e: $e');
      rootBundle.evict('AssetManifest.json');
      return Future.value(null);
    }
  }

  @visibleForTesting
  static void reset() {
//    _jsonMemoizer = AsyncMemoizer<Map<String, dynamic>>();
    _json = null;
    _jsonFuture = null;
  }
}