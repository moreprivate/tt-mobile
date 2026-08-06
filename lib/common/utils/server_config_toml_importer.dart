import 'package:trusttunnel/data/model/certificate.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:vpn_plugin/models/ini_document.dart';

/// Parses server-exported client config (flat TOML or full client.toml with
/// `[endpoint]`) into [ServerData].
///
/// Maps only endpoint/connection keys. Listener / kill-switch / OpenWrt knobs
/// are ignored. Does not invent values for missing optional keys beyond
/// product defaults already on [ServerData].
class ServerConfigTomlImporter {
  const ServerConfigTomlImporter();

  ServerData import({
    required String toml,
    required String routingProfileId,
  }) {
    final document = IniDocument.parse(toml);
    final top = document.section(null);
    final hasEndpointSection = document.section('endpoint').getRaw('hostname') != null ||
        document.section('endpoint').getRaw('addresses') != null;
    final endpoint = document.section('endpoint');

    String? getString(String key) {
      if (hasEndpointSection) {
        return endpoint.getString(key) ?? top.getString(key);
      }
      return top.getString(key);
    }

    bool? getBool(String key) {
      if (hasEndpointSection) {
        return endpoint.getBool(key) ?? top.getBool(key);
      }
      return top.getBool(key);
    }

    int? getInt(String key) {
      if (hasEndpointSection) {
        return endpoint.getInt(key) ?? top.getInt(key);
      }
      return top.getInt(key);
    }

    List<String>? getStringList(String key) {
      if (hasEndpointSection) {
        return endpoint.getStringList(key) ?? top.getStringList(key);
      }
      return top.getStringList(key);
    }

    final hostname = (getString('hostname') ?? '').trim();
    final addresses = getStringList('addresses') ?? const <String>[];
    final address = addresses.isNotEmpty ? addresses.first.trim() : '';
    final username = (getString('username') ?? '').trim();
    final password = (getString('password') ?? '').trim();

    if (hostname.isEmpty || address.isEmpty || username.isEmpty || password.isEmpty) {
      throw const FormatException(
        'Config must include hostname, addresses, username, and password',
      );
    }

    final nameRaw = (getString('name') ?? '').trim();
    final name = nameRaw.isNotEmpty ? nameRaw : hostname;

    final protocolRaw = (getString('upstream_protocol') ?? 'http2').trim().toLowerCase();
    final vpnProtocol = switch (protocolRaw) {
      'http3' || 'quic' => VpnProtocol.quic,
      _ => VpnProtocol.http2,
    };

    final customSni = (getString('custom_sni') ?? '').trim();
    final clientRandom = (getString('client_random') ?? getString('client_random_prefix') ?? '').trim();
    final certificatePem = (getString('certificate') ?? '').trim();
    // Never maps listener.tun excluded_routes (app-wide Android routes are separate).
    final dnsServers = (getStringList('dns_upstreams') ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final ipv6 = getBool('has_ipv6') ?? true;
    final antiDpi = getBool('anti_dpi') ?? false;

    var httpConnectionsNum = ServerData.defaultHttpConnectionsNum;
    final connections = getInt('http_connections_num');
    if (connections != null) {
      httpConnectionsNum =
          connections <= 0 ? ServerData.defaultHttpConnectionsNum : connections.clamp(0, 8);
    }

    return ServerData(
      name: name,
      ipAddress: address,
      domain: hostname,
      username: username,
      password: password,
      vpnProtocol: vpnProtocol, // defaults to H2 when missing / unknown
      dnsServers: dnsServers.isEmpty ? ServerData.defaultDnsServers : dnsServers,
      routingProfileId: routingProfileId,
      ipv6: ipv6,
      tlsPrefix: clientRandom.isEmpty ? null : clientRandom,
      customSni: customSni.isEmpty ? null : customSni,
      certificate: certificatePem.isEmpty
          ? null
          : Certificate(name: 'certificate.pem', data: certificatePem),
      httpConnectionsNum: httpConnectionsNum,
      antiDpi: antiDpi,
    );
  }
}
