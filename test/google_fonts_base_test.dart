import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart';
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_family_with_variant.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:path_provider/path_provider.dart';

class MockHttpClient extends Mock implements http.Client {}

class TestFontLoader extends FontLoader {
  TestFontLoader(String family) : super(family);

  @override
  Future<void> loadFont(Uint8List list, String family) async {
    fontAssets.add(list);
  }

  List<Uint8List> fontAssets = <Uint8List>[];
}

var _localPathCallCount = 0;
var _load = 0;

const _fakeResponse = 'fake response body - success';
// The number of bytes in _fakeResponse.
const _fakeResponseLengthInBytes = 28;
// Computed by converting _fakeResponse to bytes and getting sha 256 hash.
const _fakeResponseHash =
    '1194f6ffe4d2f05258573616a77932c38041f3102763096c19437c3db1818a04';
final _fakeResponseFile = GoogleFontsFile(
  _fakeResponseHash,
  _fakeResponseLengthInBytes,
);

var printLog = <String>[];

void overridePrint(Future<Null> testFn()) => () {
      var spec = ZoneSpecification(print: (_, __, ___, msg) {
        // Add to log instead of printing to stdout
        printLog.add(msg);
      });
      return Zone.current.fork(specification: spec).run(testFn);
    };

void main() {
  setUp(() async {
    isWeb = false;
    GoogleFonts.config.allowHttp = true;
    _localPathCallCount = 0;
    _fontsChangeCallCount = 0;
  });
  
  setUpAll(() async {
    fontLoaderProvider = (family) => TestFontLoader(family);
    httpClient = MockHttpClient();
    when(httpClient.get(any)).thenAnswer((_) async {
      return http.Response(_fakeResponse, 200);
    });

    // The following snippet pulled from
    //  * https://flutter.dev/docs/cookbook/persistence/reading-writing-files#testing
    final directory = await Directory.systemTemp.createTemp();
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((methodCall) async {
      if (methodCall.method == 'getApplicationSupportDirectory') {
        _localPathCallCount++;
        return directory.path;
      }
      return null;
    });

    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/system', (message) {
      final Uint8List list = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      final messageString = utf8.decode(list);
      if (messageString == '{"type":"fontsChange"}') {
        _fontsChangeCallCount++;
      }
      _fontsChangeCallCount++;
      return null;
    });
  });

  tearDown(() {
    printLog.clear();
    fontsAttemptedToLoad.clear();
  });

  testWidgets('loadFontIfNecessary calls http get', (tester) async {
    final fakeDescriptor = GoogleFontsDescriptor(
      familyWithVariant: GoogleFontsFamilyWithVariant(
          family: 'Foo',
          googleFontsVariant: GoogleFontsVariant(
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
          )),
      file: _fakeResponseFile,
    );

    await loadFontIfNecessary(fakeDescriptor);

    verify(httpClient.get(anything)).called(1);
    verify(fontLoaderProvider)
  });

//  testWidgets('loadFontIfNecessary throws if font cannot be loaded',
//      (tester) async {
//    // Mock a bad response.
//    when(httpClient.get(any)).thenAnswer((_) async {
//      return http.Response('fake response body - failure', 300);
//    });
//
//    final descriptorInAssets = GoogleFontsDescriptor(
//      familyWithVariant: GoogleFontsFamilyWithVariant(
//        family: 'Foo',
//        googleFontsVariant: GoogleFontsVariant(
//          fontWeight: FontWeight.w900,
//          fontStyle: FontStyle.italic,
//        ),
//      ),
//      file: _fakeResponseFile,
//    );
//
//    // Call loadFontIfNecessary and verify that it prints an error.
//    overridePrint(() async {
//      await loadFontIfNecessary(descriptorInAssets);
//      expect(printLog.length, 1);
//      expect(
//        printLog[0],
//        startsWith('google_fonts was unable to load font Foo-BlackItalic'),
//      );
//    });
//  });
//
//  testWidgets('loadFontIfNecessary does not call http if config is false',
//      (tester) async {
//    final fakeDescriptor = GoogleFontsDescriptor(
//      familyWithVariant: GoogleFontsFamilyWithVariant(
//        family: 'Foo',
//        googleFontsVariant: GoogleFontsVariant(
//          fontWeight: FontWeight.w400,
//          fontStyle: FontStyle.normal,
//        ),
//      ),
//      file: _fakeResponseFile,
//    );
//
//    GoogleFonts.config.allowHttp = false;
//
//    // Call loadFontIfNecessary and verify that it prints an error.
//    overridePrint(() async {
//      await loadFontIfNecessary(fakeDescriptor);
//      expect(printLog.length, 1);
//      expect(
//        printLog[0],
//        startsWith("google_fonts was unable to load font Foo-Regular"),
//      );
//      expect(
//        printLog[0],
//        endsWith(
//          "Ensure Foo-Regular.otf exists in a folder that is included in your pubspec's assets.",
//        ),
//      );
//    });
//
//    verifyNever(httpClient.get(anything));
//  });
//
//  testWidgets(
//      'loadFontIfNecessary does not make http get request on subsequent calls',
//      (tester) async {
//    final fakeDescriptor = GoogleFontsDescriptor(
//      familyWithVariant: GoogleFontsFamilyWithVariant(
//        family: 'Foo',
//        googleFontsVariant: GoogleFontsVariant(
//          fontWeight: FontWeight.w400,
//          fontStyle: FontStyle.normal,
//        ),
//      ),
//      file: _fakeResponseFile,
//    );
//
//    // 1st call.
//    await loadFontIfNecessary(fakeDescriptor);
//    verify(httpClient.get(anything)).called(1);
//
//    // 2nd call.
//    await loadFontIfNecessary(fakeDescriptor);
//    verifyNever(httpClient.get(anything));
//
//    // 3rd call.
//    await loadFontIfNecessary(fakeDescriptor);
//    verifyNever(httpClient.get(anything));
//  });
//
//  testWidgets(
//      'loadFontIfNecessary does not make more than 1 http get request on '
//      'parallel calls', (tester) async {
//    final fakeDescriptor = GoogleFontsDescriptor(
//      familyWithVariant: GoogleFontsFamilyWithVariant(
//        family: 'Foo',
//        googleFontsVariant: GoogleFontsVariant(
//          fontWeight: FontWeight.w400,
//          fontStyle: FontStyle.normal,
//        ),
//      ),
//      file: _fakeResponseFile,
//    );
//
//    // 1st call.
//    await loadFontIfNecessary(fakeDescriptor);
//    verify(httpClient.get(anything)).called(1);
//
//    // 2nd call.
//    await loadFontIfNecessary(fakeDescriptor);
//    verifyNever(httpClient.get(anything));
//
//    // 3rd call.
//    await loadFontIfNecessary(fakeDescriptor);
//    verifyNever(httpClient.get(anything));
//  });
//
//  testWidgets('loadFontIfNecessary writes font file to local file system',
//      (tester) async {
//    final fakeDescriptor = GoogleFontsDescriptor(
//      familyWithVariant: GoogleFontsFamilyWithVariant(
//          family: 'Foo',
//          googleFontsVariant: GoogleFontsVariant(
//            fontWeight: FontWeight.w400,
//            fontStyle: FontStyle.normal,
//          )),
//      file: _fakeResponseFile,
//    );
//
//    var directoryContents = await getApplicationSupportDirectory();
//    expect(directoryContents.listSync().isEmpty, isTrue);
//
//    await loadFontIfNecessary(fakeDescriptor);
//    directoryContents = await getApplicationSupportDirectory();
//
//    expect(directoryContents.listSync().isNotEmpty, isTrue);
//    expect(
//      directoryContents.listSync().single.toString().contains('Foo'),
//      isTrue,
//    );
//  });
//
//  testWidgets(
//      'loadFontIfNecessary doesn\'t write font file to local file system on'
//      'web', (tester) async {
//    isWeb = true;
//    final fakeDescriptor = GoogleFontsDescriptor(
//      familyWithVariant: GoogleFontsFamilyWithVariant(
//          family: 'Foo',
//          googleFontsVariant: GoogleFontsVariant(
//            fontWeight: FontWeight.w400,
//            fontStyle: FontStyle.normal,
//          )),
//      file: _fakeResponseFile,
//    );
//
//    var directoryContents = await getApplicationSupportDirectory();
//    expect(directoryContents.listSync().isEmpty, isTrue);
//
//    await loadFontIfNecessary(fakeDescriptor);
//    directoryContents = await getApplicationSupportDirectory();
//
//    expect(directoryContents.listSync().isEmpty, isTrue);
//  });
//
//  testWidgets(
//      'loadFontIfNecessary does not save anything to the local file system if '
//      'the file does not match the expected hash', (tester) async {
//    when(httpClient.get(any)).thenAnswer((_) async {
//      return http.Response('malicious intercepted response', 200);
//    });
//    final fakeDescriptor = GoogleFontsDescriptor(
//      familyWithVariant: GoogleFontsFamilyWithVariant(
//        family: 'Foo',
//        googleFontsVariant: GoogleFontsVariant(
//          fontWeight: FontWeight.w400,
//          fontStyle: FontStyle.normal,
//        ),
//      ),
//      file: _fakeResponseFile,
//    );
//
//    var directoryContents = await getApplicationSupportDirectory();
//    expect(directoryContents.listSync().isEmpty, isTrue);
//
//    await loadFontIfNecessary(fakeDescriptor);
//    directoryContents = await getApplicationSupportDirectory();
//    expect(directoryContents.listSync().isEmpty, isTrue);
//  });
}
