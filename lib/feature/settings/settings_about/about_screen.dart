import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trusttunnel/common/assets/assets_images.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/default_page.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // The mobile build injects the exact tt-client AAR release tag.  Keeping
  // this compile-time value separate from the app package version prevents
  // the About screen from accidentally reporting the Flutter app version as
  // the native client version.
  static const _ttClientVersion = String.fromEnvironment(
    'TT_CLIENT_VERSION',
    defaultValue: 'not injected',
  );

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(
        title: context.ln.about,
      ),
      body: FutureBuilder<String>(
        future: _getPackageVersion(),
        builder: (context, snapshot) => DefaultPage(
          title: 'TrustTunnel',
          descriptionText: snapshot.data,
          imagePath: AssetImages.about,
          imageSize: const Size.square(248),
          alignment: Alignment.center,
        ),
      ),
    ),
  );

  Future<String> _getPackageVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();

    return 'tt-mobile ${packageInfo.version}\n\ntt-client $_ttClientVersion';
  }
}
