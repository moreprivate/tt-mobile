import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/common/utils/server_config_toml_importer.dart';
import 'package:trusttunnel/data/datasources/certificate_datasource.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/model/certificate.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/server_data.dart';

abstract class ServerRepository {
  Future<Server> addNewServer({required ServerData request});

  Future<List<Server>> getAllServers();

  Future<Server?> getServerById({required String id});

  Future<void> setSelectedServerId({required String? id});

  Future<void> setNewServer({required String id, required ServerData request});

  Future<Certificate?> pickCertificate();

  /// Pick a server-generated client config (`.toml`) and parse into [ServerData].
  /// Returns `null` if the user cancels.
  Future<ServerData?> pickAndImportConfigFile({String? routingProfileId});

  Future<void> removeServer({required String serverId});
}

class ServerRepositoryImpl implements ServerRepository {
  final ServerDataSource _serverDataSource;
  final CertificateDataSource _certificateDataSource;
  final FilePicker _filePicker;
  final ServerConfigTomlImporter _configImporter;

  ServerRepositoryImpl({
    required ServerDataSource serverDataSource,
    required CertificateDataSource certificateDataSource,
    FilePicker? filePicker,
    ServerConfigTomlImporter configImporter = const ServerConfigTomlImporter(),
  }) : _serverDataSource = serverDataSource,
       _certificateDataSource = certificateDataSource,
       _filePicker = filePicker ?? FilePicker.platform,
       _configImporter = configImporter;

  @override
  Future<Server> addNewServer({required ServerData request}) async {
    final server = await _serverDataSource.addNewServer(
      request: request,
    );

    return server;
  }

  @override
  Future<List<Server>> getAllServers() async {
    final servers = await _serverDataSource.getAllServers();

    return servers;
  }

  @override
  Future<void> setNewServer({required String id, required ServerData request}) =>
      _serverDataSource.setNewServer(id: id, request: request);

  @override
  Future<void> setSelectedServerId({required String? id}) => _serverDataSource.setSelectedServerId(id: id);

  @override
  Future<void> removeServer({required String serverId}) => _serverDataSource.removeServer(serverId: serverId);

  @override
  Future<Server?> getServerById({required String id}) => _serverDataSource.getServerById(id: id);

  @override
  Future<Certificate?> pickCertificate() => _certificateDataSource.pickCertificate();

  @override
  Future<ServerData?> pickAndImportConfigFile({String? routingProfileId}) async {
    final result = await _filePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['toml', 'txt', 'conf'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null) {
      return null;
    }

    String? content;
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    }
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('Config file is empty');
    }

    return _configImporter.import(
      toml: content,
      routingProfileId: routingProfileId ?? RoutingProfileUtils.defaultRoutingProfileId,
    );
  }
}
