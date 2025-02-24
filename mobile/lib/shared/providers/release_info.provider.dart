import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart';
import 'package:immich_mobile/constants/hive_box.dart';
import 'package:immich_mobile/shared/views/version_announcement_overlay.dart';

class ReleaseInfoNotifier extends StateNotifier<String> {
  ReleaseInfoNotifier() : super("");

  void checkGithubReleaseInfo() async {
    final Client client = Client();
    var box = Hive.box(hiveGithubReleaseInfoBox);

    try {
      String? localReleaseVersion = box.get(githubReleaseInfoKey);
      final res = await client.get(
          Uri.parse(
            "https://api.github.com/repos/alextran1502/immich/releases/latest",
          ),
          headers: {"Accept": "application/vnd.github.v3+json"});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String latestTagVersion = data["tag_name"];
        state = latestTagVersion;

        debugPrint("Local release version $localReleaseVersion");
        debugPrint("Remote release veresion $latestTagVersion");

        if (localReleaseVersion == null && latestTagVersion.isNotEmpty) {
          VersionAnnouncementOverlayController.appLoader.show();
          return;
        }

        if (latestTagVersion.isNotEmpty &&
            localReleaseVersion != latestTagVersion) {
          VersionAnnouncementOverlayController.appLoader.show();
          return;
        }
      }
    } catch (e) {
      debugPrint("Error gettting latest release version");

      state = "";
    }
  }

  void acknowledgeNewVersion() {
    var box = Hive.box(hiveGithubReleaseInfoBox);

    box.put(githubReleaseInfoKey, state);
    VersionAnnouncementOverlayController.appLoader.hide();
  }
}

final releaseInfoProvider = StateNotifierProvider<ReleaseInfoNotifier, String>(
  (ref) => ReleaseInfoNotifier(),
);
