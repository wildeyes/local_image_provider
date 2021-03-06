import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:local_image_provider/local_album.dart';
import 'package:local_image_provider/local_image.dart';

/// An interface to get information from the local image storage on the device.
///
/// Use [LocalImageProvider] to query for albums and images.
/// The general flow is as follows:
/// ```dart
///   LocalImageProvider lip = LocalImageProvider();
///   await lip.initialize();
///   if ( lip.isAvailable ) {
///     List<LocalImage> images = await lip.findLatest(10);
///     if ( images.isNotEmpty) {
///       // Do stuff with the image
///     }
///   }
///   else {
///     print('Access denied.');
///   }
/// ```
class LocalImageProvider {
  @visibleForTesting
  static const MethodChannel lipChannel =
      const MethodChannel('plugin.csdcorp.com/local_image_provider');

  static final LocalImageProvider _instance =
      LocalImageProvider.withMethodChannel(lipChannel);
  final MethodChannel channel;
  bool _initWorked = false;
  int _bytesLoaded = 0;
  int _totalLoadTime = 0;
  int _lastLoadTime = 0;
  final Stopwatch _stopwatch = Stopwatch();

  /// Returns the singleton instance of the [LocalImageProvider].
  factory LocalImageProvider() => _instance;
  @visibleForTesting
  LocalImageProvider.withMethodChannel(this.channel);

  /// True if [initialize] succeeded and the user granted
  /// permission to access local images.
  ///
  /// Use this property to determine if calls to the [LocalImageProvider]
  /// are availablle. If [isAvailable] is false then other calls with
  /// throw an [LocalImageProviderNotInitializedException] exception. This
  /// method can be called before [initialize] although it will
  /// return false.
  bool get isAvailable => _initWorked;

  /// Returns true if the user has already granted permission to access photos.
  ///
  /// This method can be called before [initialize] to check if permission
  /// has already been granted. If this returns false then the [initialize]
  /// call will prompt the user for permission if it is allowed to do so.
  /// Note that applications cannot ask for permission again if the user has
  /// denied them permission in the past.
  Future<bool> get hasPermission async {
    bool hasPermission = await channel.invokeMethod('has_permission');
    return hasPermission;
  }

  /// Initialize and request permission to use platform services.
  ///
  /// If this returns false then either the user has denied permission
  /// to use the platform services or the services are not available
  /// for some reason, possibly due to platform version.
  Future<bool> initialize() async {
    if (_initWorked) {
      return Future.value(_initWorked);
    }
    _initWorked = await channel.invokeMethod('initialize');
    return _initWorked;
  }

  /// Returns the list of [LocalAlbum] available on the device matching the [localAlbumType]
  Future<List<LocalAlbum>> findAlbums(LocalAlbumType localAlbumType) async {
    if (!_initWorked) {
      throw LocalImageProviderNotInitializedException();
    }
    final List<dynamic> albums =
        await channel.invokeMethod('albums', localAlbumType.value);
    return albums.map((albumJson) {
      // print(albumJson);
      Map<String, dynamic> photoMap = jsonDecode(albumJson);
      return LocalAlbum.fromJson(photoMap);
    }).toList();
  }

  /// Returns the newest images on the local device up to [maxImages] in length.
  ///
  /// This list may be empty if there are no images on the device or the
  /// user has denied permission to see their local images.
  Future<List<LocalImage>> findLatest(int maxImages) async {
    if (!_initWorked) {
      throw LocalImageProviderNotInitializedException();
    }
    final List<dynamic> images =
        await channel.invokeMethod('latest_images', maxImages);
    return _jsonToLocalImages(images);
  }

  /// Returns the images contained in the given album on the local device
  /// up to [maxImages] in length.
  ///
  /// This list may be empty if there are no images in the album or the
  /// user has denied permission to see their local images. If there are
  /// more images in the album than maxImages the list is silently truncated.
  /// Note that images are quite small and fast to load since they don't load
  /// the image contents just basic metadata, so it is usually safe to load a
  /// large number of images from an album if required.
  Future<List<LocalImage>> findImagesInAlbum(
      String albumId, int maxImages) async {
    if (!_initWorked) {
      throw LocalImageProviderNotInitializedException();
    }
    final List<dynamic> images = await channel.invokeMethod(
        'images_in_album', {'albumId': albumId, 'maxImages': maxImages});
    return _jsonToLocalImages(images);
  }

  /// Returns a version of the image at the given size in a jpeg format suitable for loading with
  /// [MemoryImage].
  ///
  /// The returned image will maintain its aspect ratio while fitting within the given dimensions
  /// [height], [width]. The [id] to use is available from a returned [LocalImage]. The image is
  /// sent from the device as a JPEG compressed at 0.7 quality, which is a reasonable tradeoff
  /// between quality and size. If displayed images look blurry or low quality try requesting
  /// more pixels, i.e. a larger value for [height] and [width].
  /// Instead of using this directly look at [DeviceImage] which creates an [ImageProvider] from
  /// a [LocalImage], suitable for use in a widget tree.
  Future<Uint8List> imageBytes(String id, int height, int width) async {
    if (!_initWorked) {
      throw LocalImageProviderNotInitializedException();
    }
    _stopwatch.reset();
    _stopwatch.start();
    final Uint8List photoBytes = await channel.invokeMethod(
        'image_bytes', {'id': id, 'pixelHeight': height, 'pixelWidth': width});
    _stopwatch.stop();
    _totalLoadTime += _stopwatch.elapsedMilliseconds;
    _lastLoadTime = _stopwatch.elapsedMilliseconds;
    _bytesLoaded += photoBytes.length;
    return photoBytes;
  }

  /// Resets the [totalLoadTime], [lastLaodTime], and [imgBytesLoaded]
  /// stats to zero.
  void resetStats() {
    _totalLoadTime = 0;
    _lastLoadTime = 0;
    _bytesLoaded = 0;
  }

  /// Returns the total milliseconds spent in [imageBytes] since the last call
  /// to [resetStats].
  int get totalLoadTime => _totalLoadTime;

  /// Returns the milliseconds spent in the last call to [imageBytes] assuming
  /// that [resetStats] wasn't called after the last call.
  int get lastLoadTime => _lastLoadTime;

  /// Returns the total bytes loaded in [imageBytes] since the last call
  /// to [resetStats].
  int get imgBytesLoaded => _bytesLoaded;

  List<LocalImage> _jsonToLocalImages(List<dynamic> jsonImages) {
    return jsonImages.map((imageJson) {
      // print(photoJson);
      Map<String, dynamic> imageMap = jsonDecode(imageJson);
      return LocalImage.fromJson(imageMap);
    }).toList();
  }
}

/// Thrown when a method is called that requires successful
/// initialization first. See [initialize]
class LocalImageProviderNotInitializedException implements Exception {}
