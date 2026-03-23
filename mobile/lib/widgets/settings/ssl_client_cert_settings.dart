import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/platform/network_api.g.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:logging/logging.dart';

class SslClientCertSettings extends StatefulWidget {
  const SslClientCertSettings({super.key});

  @override
  State<StatefulWidget> createState() => _SslClientCertSettingsState();
}

class _SslClientCertSettingsState extends State<SslClientCertSettings> {
  final _log = Logger("SslClientCertSettings");

  bool isCertExist = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkCertificate());
  }

  Future<void> _checkCertificate() async {
    try {
      final exists = await networkApi.hasCertificate();
      if (mounted && exists != isCertExist) {
        setState(() => isCertExist = exists);
      }
    } catch (e) {
      _log.warning("Failed to check certificate existence", e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      horizontalTitleGap: 20,
      isThreeLine: true,
      title: Text("client_cert_title".tr(), style: context.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "client_cert_subtitle".tr(),
            style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.onSurfaceSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(onPressed: importCert, child: Text("client_cert_import".tr())),
              ElevatedButton(onPressed: !isCertExist ? null : removeCert, child: Text("remove".tr())),
            ],
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    context.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(message, style: context.textTheme.bodyLarge?.copyWith(color: context.primaryColor)),
      ),
    );
  }

  Future<void> importCert() async {
    try {
      final styling = ClientCertPrompt(
        title: "client_cert_password_title".tr(),
        message: "client_cert_password_message".tr(),
        cancel: "cancel".tr(),
        confirm: "confirm".tr(),
      );
      final cert = await networkApi.selectCertificate(styling);

      if (!Platform.isAndroid) {
        if (cert.data.isEmpty) {
          throw StateError("Certificate data is empty");
        }

        var password = cert.password;
        if (password.isEmpty) {
          final entered = await _promptForPassword(styling);
          if (entered == null) {
            return;
          }
          password = entered;
        }

        await networkApi.addCertificate(ClientCertData(data: cert.data, password: password));
      }

      await SSLClientCertStoreVal.delete();
      setState(() => isCertExist = true);
      showMessage("client_cert_import_success_msg".tr());
    } catch (e) {
      if (_isCancellation(e)) {
        return;
      }
      _log.severe("Error importing client cert", e);
      showMessage("client_cert_invalid_msg".tr());
    }
  }

  Future<void> removeCert() async {
    try {
      await networkApi.removeCertificate();
      await SSLClientCertStoreVal.delete();
      setState(() => isCertExist = false);
      showMessage("client_cert_remove_msg".tr());
    } catch (e) {
      if (_isCancellation(e)) {
        return;
      }
      _log.severe("Error removing client cert", e);
      showMessage("client_cert_invalid_msg".tr());
    }
  }

  bool _isCancellation(Object e) => e is PlatformException && e.code.toLowerCase().contains("cancel");

  Future<String?> _promptForPassword(ClientCertPrompt promptText) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(promptText.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(promptText.message),
              const SizedBox(height: 12),
              TextField(controller: controller, obscureText: true, autofocus: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(promptText.cancel)),
            TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text(promptText.confirm)),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
