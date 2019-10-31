import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_image_provider/local_image.dart';
import 'package:local_image_provider/local_image_provider.dart';

void main() {
  const String testId1 = "id1";
  const String create1 = "2019-11-25";
  const int width1 = 100;
  const int height1 = 200;
  const String testId2 = "id2";
  const String create2 = "2019-10-17";
  const int width2 = 300;
  const int height2 = 600;
  const double scale80Percent = 0.8;
  const int width80Percent = 80;
  const int height80Percent = 160;
  const String expectedToString =
      "LocalImage($testId1, creation: $create1, height: $height1, width: $width1)";
  const img1 = LocalImage(testId1, create1, height1, width1);
  const img1a = LocalImage(testId1, create1, height1, width1);
  const img2 = LocalImage(testId2, create2, height2, width2);

  String requestedImgId;
  int requestedHeight;
  int requestedWidth;
  Uint8List imageBytes;
  LocalImageProvider localImageProvider;

  setUp(() async {
    List<int> imgInt = "087imgbytes234".codeUnits;
    imageBytes = Uint8List.fromList(imgInt);
    localImageProvider =
        LocalImageProvider.withMethodChannel(LocalImageProvider.lipChannel);
    localImageProvider.channel
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == "initialize") {
        return true;
      } else if (methodCall.method == "image_bytes") {
        requestedImgId = methodCall.arguments["id"];
        requestedHeight = methodCall.arguments["pixelHeight"];
        requestedWidth = methodCall.arguments["pixelWidth"];
        return imageBytes;
      }
      return null;
    });
    await localImageProvider.initialize();
  });

  group('properties', () {
    test(' properties set properly', () {
      var img = LocalImage(testId1, create1, height1, width1);
      expect(img.id, testId1);
      expect(img.creationDate, create1);
      expect(img.pixelHeight, height1);
      expect(img.pixelWidth, width1);
    });
    test('hash works', () {
      expect(img1.hashCode, img1.hashCode);
      expect(img1.hashCode, img1a.hashCode);
      expect(img1.hashCode, isNot(img2.hashCode));
    });
    test('equals works', () {
      expect(img1, img1);
      expect(img1, img1a);
      expect(img1, isNot(img2));
    });
    test('toString as expected', () {
      expect(img1.toString(), expectedToString);
    });
  });
  group('json', () {
    test('round trips as expected', () {
      var img = LocalImage(testId1, create1, height1, width1);
      var json = img.toJson();
      var img1 = LocalImage.fromJson(json);
      expect(img.id, img1.id);
      expect(img.pixelHeight, img1.pixelHeight);
      expect(img.pixelWidth, img1.pixelWidth);
      expect(img.creationDate, img1.creationDate);
    });
  });
  group('imageBytes', () {
    test('simple get succeeds', () async {
      var img = LocalImage(testId1, create1, height1, width1);
      var bytes = await img.getImageBytes(localImageProvider, height1, width1);
      expect(requestedImgId, testId1);
      expect(requestedHeight, height1);
      expect(requestedWidth, width1);
      expect(bytes, imageBytes);
    });
    test('scaled get succeeds', () async {
      var img = LocalImage(testId1, create1, height1, width1);
      var bytes =
          await img.getScaledImageBytes(localImageProvider, scale80Percent);
      expect(requestedImgId, testId1);
      expect(requestedHeight, height80Percent);
      expect(requestedWidth, width80Percent);
      expect(bytes, imageBytes);
    });
  });
}
