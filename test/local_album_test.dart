import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_image_provider/local_album.dart';
import 'package:local_image_provider/local_image.dart';
import 'package:local_image_provider/local_image_provider.dart';

void main() {
  const String albumId1 = "album1";
  const String albumId2 = "album2";
  const String title1 = "title1";
  const String title2 = "title2";
  const int imageCount1 = 10;
  const int imageCount2 = 20;
  const String imgId1 = "img1";
  const String creation1 = "2019-10-25";
  const String expectedToString = "LocalAlbum($albumId1, title: $title1)";
  const int height1 = 100;
  const int width1 = 200;
  const LocalImage coverImg1 = LocalImage(imgId1, creation1, height1, width1);
  const LocalAlbum localAlbum1 =
      LocalAlbum(albumId1, coverImg1, title1, imageCount1);
  const LocalAlbum localAlbum1a =
      LocalAlbum(albumId1, coverImg1, title1, imageCount1);
  const LocalAlbum localAlbum2 =
      LocalAlbum(albumId2, coverImg1, title2, imageCount2);
  String requestedImgId;
  int requestedHeight;
  int requestedWidth;
  Uint8List imageBytes;
  LocalImageProvider localImageProvider;

  WidgetsFlutterBinding.ensureInitialized();
  
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
    test('set as expected', () {
      expect(localAlbum1.id, albumId1);
      expect(localAlbum1.title, title1);
      expect(localAlbum1.coverImg, coverImg1);
      expect(localAlbum1.imageCount, imageCount1);
    });
    test('Correct type returned', () {
      expect(LocalAlbumType.fromInt(0), LocalAlbumType.all);
      expect(LocalAlbumType.fromInt(1), LocalAlbumType.user);
      expect(LocalAlbumType.fromInt(2), LocalAlbumType.generated);
      expect(LocalAlbumType.fromInt(3), null);
    });
    test('hash works', () {
      expect(localAlbum1.hashCode, localAlbum1.hashCode);
      expect(localAlbum1.hashCode, localAlbum1a.hashCode);
      expect(localAlbum1.hashCode, isNot(localAlbum2.hashCode));
    });
    test('equals works', () {
      expect(localAlbum1, localAlbum1);
      expect(localAlbum1, localAlbum1a);
      expect(localAlbum1, isNot(localAlbum2));
    });
    test('toString works', () {
      expect(localAlbum1.toString(), expectedToString);
    });
  });

  group('json', () {
    test('roundtrips as expected', () {
      var roundtripAlbum = LocalAlbum.fromJson(localAlbum1.toJson());
      expect(localAlbum1.id, roundtripAlbum.id);
      expect(localAlbum1.title, roundtripAlbum.title);
      expect(localAlbum1.coverImg, roundtripAlbum.coverImg);
      expect(localAlbum1.imageCount, roundtripAlbum.imageCount);
    });
  });
  group('imageBytes', () {
    test('loads cover image', () async {
      var bytes =
          await localAlbum1.getCoverImage(localImageProvider, height1, width1);
      expect(requestedImgId, imgId1);
      expect(requestedHeight, height1);
      expect(requestedWidth, width1);
      expect(bytes, imageBytes);
    });
  });
}
