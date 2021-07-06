import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class AlyOss {
  static final _channel = MethodChannel('jitao.tech/aly_oss')..setMethodCallHandler(_handler);
  static final _instances = Map<String, AlyOss>();
  static final _uuid = Uuid();
  String _instanceId;

  AlyOss() {
    _instanceId = _uuid.v4();
    _instances[_instanceId] = this;

    print('AlyOss: ' + _instanceId);
  }

  StreamController<ProgressResponse> _onProgressController = StreamController<ProgressResponse>.broadcast();

  Stream<ProgressResponse> get onProgress => _onProgressController.stream;

  StreamController<UploadResponse> _onUploadController = StreamController<UploadResponse>.broadcast();

  Stream<UploadResponse> get onUpload => _onUploadController.stream;

  //todo: Android暂未实现下载模块.
  /// Download.
  StreamController<ProgressResponse> _onDownloadProgressController = StreamController<ProgressResponse>.broadcast();

  Stream<ProgressResponse> get onDownloadProgress => _onDownloadProgressController.stream;

  StreamController<DownloadResponse> _onDownloadController = StreamController<DownloadResponse>.broadcast();

  Stream<DownloadResponse> get onDownload => _onDownloadController.stream;

  static Future<dynamic> _handler(MethodCall methodCall) async {
    String instanceId = methodCall.arguments['instanceId'];
    AlyOss instance = _instances[instanceId];

    switch (methodCall.method) {
      case 'onProgress':
        instance._onProgressController.add(ProgressResponse.fromMap(methodCall.arguments));
        break;
      case 'onUpload':
        instance._onUploadController.add(UploadResponse.fromMap(methodCall.arguments));
        break;
      case 'onDownloadProgress':
        instance._onDownloadProgressController.add(ProgressResponse.fromMap(methodCall.arguments));
        break;
      case 'onDownload':
        instance._onDownloadController.add(DownloadResponse.fromMap(methodCall.arguments));
        break;
      default:
        print('Call ${methodCall.method} from platform, arguments=${methodCall.arguments}');
    }

    return Future.value(true);
  }

  /// Initialize plugin with [request]
  Future<Map<String, dynamic>> init(InitRequest request) async {
    return await _invokeMethod('init', request.toMap());
  }

  /// Shutdown plugin
  void shutdown() {
    _onProgressController.close();
    _onUploadController.close();
    _onDownloadProgressController.close();
    _onDownloadController.close();
  }

  Future<Map<String, dynamic>> upload(UploadRequest request) async {
    return await _invokeMethod('upload', request.toMap());
  }

  Future<Map<String, dynamic>> download(DownloadRequest request) async {
    return await _invokeMethod('download', request.toMap());
  }

  Future<Map<String, dynamic>> exist(KeyRequest request) async {
    return await _invokeMethod('exist', request.toMap());
  }

  Future<Map<String, dynamic>> delete(KeyRequest request) async {
    return await _invokeMethod('delete', request.toMap());
  }

  Future<Map<String, dynamic>> resignUrl(ResignUrlRequest request) async {
    return await _invokeMethod('resign', request.toMap());
  }

  Future<Map<String, dynamic>> _invokeMethod(String method, [Map<String, dynamic> arguments = const {}]) {
    Map<String, dynamic> withId = Map.of(arguments);
    withId['instanceId'] = _instanceId;

    return _channel.invokeMapMethod(method, withId);
  }
}

abstract class Request {
  final String requestId;

  Request(this.requestId);

  Map<String, dynamic> toMap() {
    return {'requestId': requestId};
  }
}

class InitRequest extends Request {
  final String endpoint;
  final String tokenJson;

  InitRequest(requestId, this.endpoint, this.tokenJson) : super(requestId);

  Map<String, dynamic> toMap() {
    var m = Map.of(super.toMap());
    m['endpoint'] = endpoint;
    m['tokenJson'] = tokenJson;

    return m;
  }
}

class KeyRequest extends Request {
  final String bucket;
  final String key;

  KeyRequest(requestId, this.bucket, this.key) : super(requestId);

  Map<String, dynamic> toMap() {
    var m = Map.of(super.toMap());
    m['bucket'] = bucket;
    m['key'] = key;

    return m;
  }
}

class UploadRequest extends KeyRequest {
  final String file;

  UploadRequest(requestId, bucket, key, this.file) : super(requestId, bucket, key);

  Map<String, dynamic> toMap() {
    var m = Map.of(super.toMap());
    m['file'] = file;

    return m;
  }
}

class DownloadRequest extends KeyRequest {

  DownloadRequest(requestId, bucket, key) : super(requestId, bucket, key);

  Map<String, dynamic> toMap() {
    var m = Map.of(super.toMap());
    return m;
  }
}

class ResignUrlRequest extends KeyRequest {
  final String expireSeconds;

  ResignUrlRequest(requestId, bucket, key, this.expireSeconds) : super(requestId, bucket, key);

  Map<String, dynamic> toMap() {
    var m = Map.of(super.toMap());
    m['expireSeconds'] = expireSeconds;

    return m;
  }
}

abstract class Response {
  final bool success;
  final String requestId;

  Response({this.success, this.requestId});
}

class KeyResponse extends Response {
  final String bucket;
  final String key;

  KeyResponse({success, requestId, this.bucket, this.key}) : super(success: success, requestId: requestId);
}

class UploadResponse extends KeyResponse {
  UploadResponse({success, requestId, bucket, key}) : super(success: success, requestId: requestId, bucket: bucket, key: key);

  UploadResponse.fromMap(Map map)
      : super(
          success: "true" == map['success'],
          requestId: map['requestId'],
          bucket: map['bucket'],
          key: map['key'],
        );

  String toString() {
    return '{success:$success, requestId:$requestId, bucket:$bucket, key:$key}';
  }
}

class DownloadResponse extends KeyResponse {
 final String data;

  DownloadResponse({success, requestId, bucket, key, this.data}) : super(success: success, requestId: requestId, bucket: bucket, key: key);

  static DownloadResponse fromMap(Map map) {
    DownloadResponse response = DownloadResponse(
      success: "true" == map['success'],
      requestId: map['requestId'],
      bucket: map['bucket'],
      key: map['key'],
      data: map['data'],
    );
    return response;
  }

  String toString() {
    return '{success:$success, requestId:$requestId, bucket:$bucket, key:$key}';
  }
}

class ProgressResponse extends KeyResponse {
  int currentSize;
  int totalSize;

  ProgressResponse({success, requestId, bucket, key, this.currentSize, this.totalSize})
      : super(success: success, requestId: requestId, bucket: bucket, key: key);

  ProgressResponse.fromMap(Map map)
      : super(
          success: "true" == map['success'],
          requestId: map['requestId'],
          bucket: map['bucket'],
          key: map['key'],
        ) {
    currentSize = int.tryParse(map['currentSize']) ?? 0;
    totalSize = int.tryParse(map['totalSize']) ?? 0;
  }

  String toString() {
    return '{success:$success, requestId:$requestId, bucket:$bucket, key:$key}, currentSize:$currentSize, totalSize:$totalSize';
  }
}
