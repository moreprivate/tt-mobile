import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/router/app_routes.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_card.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_empty_placeholder.dart';
import 'package:trusttunnel/widgets/buttons/custom_floating_action_button.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class ServersScreenView extends StatefulWidget {
  final ServerData? deepLinkData;

  const ServersScreenView({
    super.key,
    this.deepLinkData,
  });

  @override
  State<ServersScreenView> createState() => _ServersScreenViewState();
}

class _ServersScreenViewState extends State<ServersScreenView> {
  late List<Server> _servers;
  late final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;

  @override
  void initState() {
    super.initState();
    final initialController = ServersScope.controllerOf(context, listen: false);
    _servers = initialController.servers;
    _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
    if (widget.deepLinkData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pushServerDetailsScreen(
          context,
          preloadedData: widget.deepLinkData,
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _servers = ServersScope.controllerOf(
      context,
      aspect: ServersScopeAspect.servers,
    ).servers;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.servers,
        ),
        body: _servers.isEmpty
            ? const ServersEmptyPlaceholder()
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _servers.length,
                itemBuilder: (_, index) => Column(
                  children: [
                    ServersCard(
                      server: _servers[index],
                    ),

                    if (index != _servers.length - 1) const Divider(),
                  ],
                ),
              ),
        floatingActionButton: _servers.isEmpty
            ? null
            : Builder(
                builder: (context) => CustomFloatingActionButton.extended(
                  icon: AssetIcons.add,
                  onPressed: () => _showAddServerActions(context),
                  label: context.ln.addServer,
                ),
              ),
      ),
    ),
  );

  Future<void> _showAddServerActions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(context.ln.importConfig),
              subtitle: Text(context.ln.importConfigDescription),
              onTap: () => Navigator.of(sheetContext).pop('import'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.ln.create),
              onTap: () => Navigator.of(sheetContext).pop('create'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || choice == null) {
      return;
    }
    if (choice == 'import') {
      await _importConfig(context);
    } else {
      await _pushServerDetailsScreen(context);
    }
  }

  Future<void> _importConfig(BuildContext context) async {
    final controller = ServersScope.controllerOf(context, listen: false);
    try {
      final data = await controller.importConfigFile();
      if (data == null || !context.mounted) {
        return;
      }
      await _pushServerDetailsScreen(context, preloadedData: data);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      context.showInfoSnackBar(message: context.ln.importConfigFailed);
    }
  }

  Future<void> _pushServerDetailsScreen(
    BuildContext context, {
    ServerData? preloadedData,
  }) async {
    final controller = ServersScope.controllerOf(context, listen: false);
    final Widget serverDetailsScreen;

    if (preloadedData != null) {
      serverDetailsScreen = ServerDetailsPopUp.preloaded(
        preloadedData: preloadedData,
      );
    } else {
      serverDetailsScreen = const ServerDetailsPopUp();
    }

    await context.push(
      ScaffoldMessengerProvider(
        value: _scaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context),
        child: serverDetailsScreen,
      ),
      route: AppRoutes.serverDetails,
    );

    controller.fetchServers();
  }
}
