import 'package:xml/xml.dart';

abstract class SoapAction<R> {
  const SoapAction();

  static SoapAction<bool> setAVTransportURI(String url) => _SetAVTransportURIAction(url);

  static SoapAction<bool> play() => const _PlayAction();

  static SoapAction<bool> pause() => const _PauseAction();

  static SoapAction<bool> seek(Duration position) => _SeekAction(position);

  static SoapAction<bool> stop() => const _StopAction();

  static SoapAction<GetPositionInfoResult?> getPositionInfo() => const _GetPositionInfoAction();

  String get soapAction;

  String get xmlData;

  R get errorResult;

  R parseResult(XmlDocument document);
}

class _SetAVTransportURIAction implements SoapAction<bool> {
  const _SetAVTransportURIAction(this.url);

  final String url;

  @override
  String get soapAction =>
      '\"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI\"';

  @override
  String get xmlData =>
      """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
<s:Body>
<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<InstanceID>0</InstanceID>
<CurrentURI>$url</CurrentURI>
<CurrentURIMetaData/>
</u:SetAVTransportURI>
</s:Body>
</s:Envelope>""";

  @override
  bool parseResult(XmlDocument document) => true;

  @override
  bool get errorResult => false;
}

class _PlayAction implements SoapAction<bool> {
  const _PlayAction();

  @override
  String get soapAction =>
      '\"urn:schemas-upnp-org:service:AVTransport:1#Play\"';

  @override
  String get xmlData =>
      """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
	<s:Body>
		<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
			<Speed>1</Speed>
		</u:Play>
	</s:Body>
</s:Envelope>""";

  @override
  bool get errorResult => false;

  @override
  bool parseResult(XmlDocument document) => true;
}

class _PauseAction implements SoapAction<bool> {
  const _PauseAction();

  @override
  String get soapAction =>
      '\"urn:schemas-upnp-org:service:AVTransport:1#Pause\"';

  @override
  String get xmlData =>
      """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
	<s:Body>
		<u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
		</u:Pause>
	</s:Body>
</s:Envelope>""";

  @override
  bool get errorResult => false;

  @override
  bool parseResult(XmlDocument document) => true;
}

class _SeekAction implements SoapAction<bool> {
  const _SeekAction(this.position);

  final Duration position;

  String get _positionString {
    String twoDigits(int n) {
      if (n >= 10)
       return '$n';
      return '0$n';
    }

    if (position.inMicroseconds <= 0) {
      return '00:00:00';
    }
    final twoDigitMinutes =
        twoDigits(position.inMinutes.remainder(Duration.minutesPerHour));
    final twoDigitSeconds =
        twoDigits(position.inSeconds.remainder(Duration.secondsPerMinute));
    return '${position.inHours}:$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  String get soapAction =>
      '\"urn:schemas-upnp-org:service:AVTransport:1#Seek\"';

  @override
  String get xmlData =>
      """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
	<s:Body>
		<u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
			<Unit>REL_TIME</Unit>
			<Target>$_positionString</Target>
		</u:Seek>
	</s:Body>
</s:Envelope>""";

  @override
  bool get errorResult => false;

  @override
  bool parseResult(XmlDocument document) => true;
}

class _StopAction implements SoapAction<bool> {
  const _StopAction();

  @override
  String get soapAction =>
      '\"urn:schemas-upnp-org:service:AVTransport:1#Stop\"';

  @override
  String get xmlData =>
      """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
	<s:Body>
		<u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
		</u:Stop>
	</s:Body>
</s:Envelope>""";

  @override
  bool get errorResult => false;

  @override
  bool parseResult(XmlDocument document) => true;
}

class _GetPositionInfoAction implements SoapAction<GetPositionInfoResult?> {

  const _GetPositionInfoAction();

  @override
  String get soapAction =>
      '\"urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo\"';

  @override
  String get xmlData =>
      """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
	<s:Body>
		<u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
		</u:GetPositionInfo>
	</s:Body>
</s:Envelope>""";

  @override
  GetPositionInfoResult? get errorResult => null;

  @override
  GetPositionInfoResult? parseResult(XmlDocument document) {
    try {
      final infoElement =
          document.rootElement.firstElementChild!.firstElementChild!;
      final realTime = infoElement.getElement('RelTime')!.text;
      final duration = infoElement.getElement('TrackDuration')!.text;
      return GetPositionInfoResult(
        position: _parseTime(realTime),
        duration: _parseTime(duration),
      );
    } catch (e) {
      print('GetPositionInfoAction => $e');
      return errorResult;
    }
  }

  /// 00:00:00
  Duration _parseTime(String timeString) {
    final list = timeString.split(':');
    if (list.length != 3) {
      throw const FormatException();
    }

    final h = int.parse(list[0]);
    final m = int.parse(list[1]);
    final s = int.parse(list[2]);

    return Duration(seconds: h * 3600 + m * 60 + s);
  }
}

class GetPositionInfoResult {
  const GetPositionInfoResult({
    required this.position,
    required this.duration,
  });

  final Duration position;
  final Duration duration;

  @override
  String toString() => 'Position: $position, Duration$duration';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetPositionInfoResult &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          duration == other.duration;

  @override
  int get hashCode => position.hashCode ^ duration.hashCode;
}
