import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'device.dart';

const _UPNP_PORT = 1900;

class _MessageType {
  const _MessageType._();

  static const OK = 'HTTP/1.1 200 OK';

  static const NOTIFY = 'NOTIFY * HTTP/1.1';
}

class DeviceEventData {
  const DeviceEventData({
    required this.isRemoved,
    required this.uuid,
    this.device,
  });

  final bool isRemoved;

  final String uuid;

  final UPnPDevice? device;
}

class DeviceDiscoverer {
  DeviceDiscoverer(this.httpClient);

  final HttpClient httpClient;

  final _sockets = <RawDatagramSocket>[];

  final _deviceController = StreamController<DeviceEventData>();

  final _ipv4Address = InternetAddress('239.255.255.250');

  final _ipv6Address = InternetAddress('FF02::FB');

  Stream<DeviceEventData> get deviceEvents => _deviceController.stream;

  late List<NetworkInterface> _interfaces;

  Future<void> _createSocket(InternetAddress address, int port) async {
    final socket = await RawDatagramSocket.bind(address, port);
    socket.broadcastEnabled = true;
    socket.readEventsEnabled = true;
    socket.multicastHops = 50;
    socket.listen((event) => _eventListener(event, socket));

    try {
      socket.joinMulticast(_ipv4Address);
    // ignore: empty_catches
    } on OSError {}

    try {
      socket.joinMulticast(_ipv6Address);
    // ignore: empty_catches
    } on OSError {}

    for (final interface in _interfaces) {
      try {
        socket.joinMulticast(_ipv4Address, interface);
      // ignore: empty_catches
      } on OSError {}

      try {
        socket.joinMulticast(_ipv6Address, interface);
      // ignore: empty_catches
      } on OSError {}
    }

    _sockets.add(socket);
  }

  String? _parseUsn(String usn) {
    var list = usn.split('::');
    if (list.isEmpty) {
      return null;
    }
    list = list[0].split(':');
    if (list.length != 2) {
      return null;
    }
    return list[1];
  }

  Future<void> _eventListener(
    RawSocketEvent event,
    RawDatagramSocket socket,
  ) async {
    if (event != RawSocketEvent.read) {
      return;
    }
    final packet = socket.receive();
    if (packet == null) {
      return;
    }
    final data = utf8.decode(packet.data);
    final messages = data.split('\r\n');
    messages.removeWhere((x) => x.trim().isEmpty);
    final firstLine = messages.removeAt(0);
    final isMatch = firstLine.toLowerCase() == _MessageType.OK.toLowerCase() ||
        firstLine.toLowerCase() == _MessageType.NOTIFY.toLowerCase();
    if (!isMatch) {
      return;
    }
    final header = <String, String>{};

    for (final message in messages) {
      final list = message.split(':');
      final key = list.removeAt(0).trim().toUpperCase();
      final value = list.join(':').trim();
      header[key] = value;
    }
    final usn = header['USN'];
    if (usn == null) {
      return;
    }

    final uuid = _parseUsn(usn);
    if (uuid == null) {
      return;
    }

    if (header['NTS'] == 'ssdp:byebye') {
      _deviceController.add(DeviceEventData(
        isRemoved: true,
        uuid: uuid,
      ));
      return;
    }

    final DiscoveredClient client;
    try {
      client = DiscoveredClient(
        headers: header,
        st: header['ST'],
        usn: usn,
        server: header['SERVER']!,
        location: header['LOCATION']!,
      );
    } catch (e) {
      return;
    }
    final device = await client.getDevice(httpClient);
    if (device != null) {
      _deviceController.add(DeviceEventData(
        isRemoved: false,
        uuid: uuid,
        device: device,
      ));
    }
  }

  Future<void> init({
    bool ipv4 = true,
    bool ipv6 = false,
  }) async {
    _interfaces = await NetworkInterface.list();

    if (ipv4) {
      await _createSocket(InternetAddress.anyIPv4, 0);
      await _createSocket(InternetAddress.anyIPv4, _UPNP_PORT);
    }

    if (ipv6) {
      await _createSocket(InternetAddress.anyIPv6, 0);
      await _createSocket(InternetAddress.anyIPv4, _UPNP_PORT);
    }
  }

  void search({
    String searchType = 'urn:schemas-upnp-org:service:AVTransport:1',
  }) {
    final buffer = StringBuffer()
      ..write('M-SEARCH * HTTP/1.1\r\n')
      ..write('HOST: 239.255.255.250:1900\r\n')
      ..write('MAN: "ssdp:discover"\r\n')
      ..write('MX: 5\r\n')
      ..write('ST: $searchType\r\n')
      ..write('USER-AGENT: rx_upnp => UPnP/1.1 crash/1.0\r\n\r\n');
    final data = utf8.encode(buffer.toString());

    for (final socket in _sockets) {
      if (socket.address.type == _ipv4Address.type) {
        try {
          socket.send(data, _ipv4Address, _UPNP_PORT);
        // ignore: empty_catches
        } catch (e) {}
      }

      if (socket.address.type == _ipv6Address.type) {
        try {
          socket.send(data, _ipv6Address, _UPNP_PORT);
        // ignore: empty_catches
        } catch (e) {}
      }
    }
  }

  void close() {
    for (final socket in _sockets) {
      socket.close();
    }
    _sockets.clear();
    _deviceController.close();
  }
}

class DiscoveredClient {
  const DiscoveredClient({
    this.st,
    required this.usn,
    required this.server,
    required this.location,
    required this.headers,
  });

  final String? st;
  final String usn;
  final String server;
  final String location;
  final Map<String, String> headers;

  Future<UPnPDevice?> getDevice(HttpClient client) async {
    final uri = Uri.tryParse(location);
    if (uri == null) {
      return null;
    }
    final request =
        await client.getUrl(uri).timeout(const Duration(seconds: 5));
    final response = await request.close();
    if (response.statusCode != 200) {
      return null;
    }

    XmlDocument document;
    try {
      final responseBody = await response.transform(utf8.decoder).join();
      document = XmlDocument.parse(responseBody);
      return UPnPDevice.parseXml(uri, document.rootElement);
    } catch (e) {
      return null;
    }
  }
}
