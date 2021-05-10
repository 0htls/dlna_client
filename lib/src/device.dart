import 'package:xml/xml.dart';


class _UPnPServiceType {
  _UPnPServiceType._();
  static const avTransport = 'urn:schemas-upnp-org:service:AVTransport:1';

  // ignore: unused_field
  static const renderingControl = 'urn:schemas-upnp-org:service:RenderingControl:1';

  // ignore: unused_field
  static const connectionManager = 'urn:schemas-upnp-org:service:ConnectionManager:1';
}

class UPnPDevice {
  const UPnPDevice({
    required this.uri,
    required this.deviceElement,
    required this.deviceType,
    required this.friendlyName,
    this.manufacturer,
    required this.udn,
    this.presentationUrl,
    this.modelType,
    this.modelName,
    this.modelDescription,
    this.modelNumber,
    this.modelUrl,
    this.manufacturerUrl,
    this.serialNumber,
    required this.icons,
    required this.services,
    this.aVTransportService,
  });

  static UPnPDevice? parseXml(Uri uri, XmlElement element) {
    final deviceNode = element.getElement('device');
    if (deviceNode == null) {
      return null;
    }

    final icons = <UPnPIcon>[];
    final services = <UPnPService>[];

    final iconListNodes = deviceNode.getElement('iconList')?.children ?? List<XmlNode>.empty();
    final serviceListNodes = deviceNode.getElement('serviceList')?.children ?? List<XmlNode>.empty();

    for (final iconNode in iconListNodes) {
      if (iconNode is XmlElement) {
        final icon = UPnPIcon.parseXml(iconNode);
        if (icon != null)
          icons.add(icon);
      }
    }

    UPnPService? aVTransportService;

    for (final serviceNode in serviceListNodes) {
      if (serviceNode is XmlElement) {
        final service = UPnPService.parseXml(serviceNode);
        if (service == null) {
          continue;
        }
        if (service.serviceType == _UPnPServiceType.avTransport) {
          aVTransportService = service;
        }
        services.add(service);
      }
    }

    try {
      return UPnPDevice(
        uri: uri,
        deviceElement: deviceNode,
        deviceType: deviceNode.getElement('deviceType')!.text,
        udn: deviceNode.getElement('UDN')!.text,
        friendlyName: deviceNode.getElement('friendlyName')!.text,
        manufacturer: deviceNode.getElement('manufacturer')?.text,
        manufacturerUrl: deviceNode.getElement('manufacturerURL')?.text,
        modelName: deviceNode.getElement('modelName')?.text,
        modelType: deviceNode.getElement('modelType')?.text,
        modelNumber: deviceNode.getElement('modelNumber')?.text,
        modelDescription: deviceNode.getElement('modelDescription')?.text,
        modelUrl: deviceNode.getElement('modelURL')?.text,
        serialNumber: deviceNode.getElement('serialNumber')?.text,
        presentationUrl: deviceNode.getElement('presentationURL')?.text,
        icons: icons,
        services: services,
        aVTransportService: aVTransportService,
      );
    } catch(e) {
      return null;
    }
  }

  final Uri uri;
  final XmlElement deviceElement;
  final String deviceType;
  final String udn;
  final String friendlyName;
  final String? manufacturer;
  final String? presentationUrl;
  final String? modelType;
  final String? modelName;
  final String? modelDescription;
  final String? modelNumber;
  final String? modelUrl;
  final String? manufacturerUrl;
  final String? serialNumber;

  final List<UPnPIcon> icons;
  final List<UPnPService> services;

  final UPnPService? aVTransportService;

  String get uuid => udn.substring('uuid:'.length);

  String get url => uri.toString();

  @override
  String toString() {
    return deviceElement.toString();
  }
}

class UPnPIcon {

  const UPnPIcon({
    required this.mimetype,
    required this.width,
    required this.height,
    required this.depth,
    required this.url,
  });

  static UPnPIcon? parseXml(XmlElement iconNode) {
    try {
      final widthString = iconNode.getElement('width')!.text;
      final heightString = iconNode.getElement('height')!.text;
      final depthString = iconNode.getElement('depth')!.text;

      final width = int.parse(widthString);
      final height = int.parse(heightString);
      final depth = int.parse(depthString);
      return UPnPIcon(
        mimetype: iconNode.getElement('mimetype')!.text,
        width: width,
        height: height,
        depth: depth,
        url: iconNode.getElement('url')!.text,
      );
    } catch(e) {
      return null;
    }
  }

  final String mimetype;
  final int width;
  final int height;
  final int depth;
  final String url;

  @override
  String toString() {
    return '''
    mimeType => $mimetype
    width => $width
    height => $height
    depth => $depth
    url => $url
    ''';
  }
}

class UPnPService {

  const UPnPService({
    required this.serviceType,
    required this.serviceId,
    required this.controlURL,
    required this.eventSubURL,
    required this.SCPDURL,
  });

  static UPnPService? parseXml(XmlElement serviceNode) {
    try {
      return UPnPService(
        serviceType: serviceNode.getElement('serviceType')!.text,
        serviceId: serviceNode.getElement('serviceId')!.text,
        controlURL: serviceNode.getElement('controlURL')!.text,
        eventSubURL: serviceNode.getElement('eventSubURL')!.text,
        SCPDURL: serviceNode.getElement('SCPDURL')!.text,
      );
    } catch(e) {
      return null;
    }
  }

  final String serviceType;
  final String serviceId;
  final String controlURL;
  final String eventSubURL;
  final String SCPDURL;

  @override
  String toString() {
    return '''
    serviceType => $serviceType
    serviceId => $serviceId
    controlURL => $controlURL
    eventSubURL => $eventSubURL
    SCPDURL => $SCPDURL
    ''';
  }
}
