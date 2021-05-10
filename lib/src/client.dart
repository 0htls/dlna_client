import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'action.dart';
import 'device.dart';
import 'discovery.dart';

class DLNAClient {
  DLNAClient() {
    _deviceDiscoverer = DeviceDiscoverer(_httpClient);
    _deviceDiscoverer.deviceEvents.listen(_deviceEventListener);
  }

  final _httpClient = HttpClient();

  final _devicesController = StreamController<List<UPnPDevice>>.broadcast();

  Stream<List<UPnPDevice>> get devicesEvent => _devicesController.stream;

  Stream<List<UPnPDevice>> get canControlDevicesEvent =>
      devicesEvent.map((list) => list
          .where((device) => device.aVTransportService != null)
          .toList(growable: false));

  late final DeviceDiscoverer _deviceDiscoverer;

  final _deviceMap = <String, UPnPDevice>{};

  Iterable<UPnPDevice> get devices => _deviceMap.values;

  Iterable<UPnPDevice> get canControlDevices =>
      _deviceMap.values.where((el) => el.aVTransportService != null);

  Future<void> start() => _deviceDiscoverer.init();

  void _deviceEventListener(DeviceEventData data) {
    bool shouldNotify = false;
    if (data.isRemoved) {
      shouldNotify = _deviceMap.remove(data.uuid) != null;
    } else {
      if (_deviceMap[data.uuid] == null) {
        _deviceMap[data.uuid] = data.device!;
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      _devicesController.add(_deviceMap.values.toList(growable: false));
    }
  }

  void refresh() {
    _deviceMap.clear();
    _devicesController.add(List.empty());
    search();
  }

  void search() {
    _deviceDiscoverer.search();
  }

  Future<R> executeAction<R>({
    required UPnPDevice device,
    required SoapAction<R> action,
  }) async {
    if (device.aVTransportService == null) {
      return action.errorResult;
    }
    final urlBuffer = StringBuffer();
    urlBuffer.write('http://');
    urlBuffer.write(device.uri.authority);
    if (!device.aVTransportService!.controlURL.startsWith('/')) {
      urlBuffer.write('/');
    }
    urlBuffer.write(device.aVTransportService!.controlURL);

    final url = Uri.parse(urlBuffer.toString());
    final data = utf8.encode(action.xmlData);
    final request = await _httpClient.postUrl(url);
    request
      ..headers.contentType = ContentType('text', 'xml', charset: 'utf-8')
      ..headers.add('Soapaction', action.soapAction)
      ..contentLength = data.length
      ..add(data);

    await request.flush();
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      return action.errorResult;
    }
    try {
      final data = await response.transform(utf8.decoder).join('');
      final xmlData = XmlDocument.parse(data);
      return action.parseResult(xmlData);
    } catch (e) {
      return action.errorResult;
    }
  }

  void destroy() {
    _deviceDiscoverer.close();
    _httpClient.close(force: true);
    _devicesController.close();
  }
}
