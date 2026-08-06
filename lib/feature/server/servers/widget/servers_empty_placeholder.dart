import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/assets_images.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/widgets/default_page.dart';

class ServersEmptyPlaceholder extends StatelessWidget {
  const ServersEmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => DefaultPage(
    title: context.ln.serversEmptyTitle,
    descriptionText: context.ln.importConfigDescription,
    imagePath: AssetImages.server,
    imageSize: const Size.square(248),
    alignment: Alignment.center,
    button: Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: context.isMobileBreakpoint ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            style: context.theme.filledButtonTheme.style?.copyWith(
              minimumSize: WidgetStateProperty.all(
                const Size(double.infinity, 40),
              ),
            ),
            onPressed: () => _importConfig(context),
            child: Text(context.ln.importConfig),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pushServerDetailsScreen(context),
            child: Text(context.ln.create),
          ),
        ],
      ),
    ),
  );

  Future<void> _importConfig(BuildContext context) async {
    final controller = ServersScope.controllerOf(context, listen: false);
    try {
      final data = await controller.importConfigFile();
      if (data == null || !context.mounted) {
        return;
      }
      await context.push(
        ServerDetailsPopUp.preloaded(preloadedData: data),
      );
      controller.fetchServers();
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      context.showInfoSnackBar(message: context.ln.importConfigFailed);
    }
  }

  Future<void> _pushServerDetailsScreen(BuildContext context) async {
    final controller = ServersScope.controllerOf(context, listen: false);
    await context.push(const ServerDetailsPopUp());
    controller.fetchServers();
  }
}
