import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/hive_box.dart';
import 'package:immich_mobile/modules/asset_viewer/providers/image_viewer_page_state.provider.dart';
import 'package:immich_mobile/modules/asset_viewer/ui/exif_bottom_sheet.dart';
import 'package:immich_mobile/modules/asset_viewer/ui/top_control_app_bar.dart';
import 'package:immich_mobile/modules/asset_viewer/views/image_viewer_page.dart';
import 'package:immich_mobile/modules/asset_viewer/views/video_viewer_page.dart';
import 'package:immich_mobile/modules/home/services/asset.service.dart';
import 'package:immich_mobile/modules/settings/providers/app_settings.provider.dart';
import 'package:immich_mobile/modules/settings/services/app_settings.service.dart';
import 'package:immich_mobile/shared/models/asset.dart';

// ignore: must_be_immutable
class GalleryViewerPage extends HookConsumerWidget {
  late List<Asset> assetList;
  final Asset asset;

  GalleryViewerPage({
    Key? key,
    required this.assetList,
    required this.asset,
  }) : super(key: key);

  Asset? assetDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Box<dynamic> box = Hive.box(userInfoBox);
    final appSettingService = ref.watch(appSettingsServiceProvider);
    final threeStageLoading = useState(false);
    final loading = useState(false);
    final isZoomed = useState<bool>(false);
    ValueNotifier<bool> isZoomedListener = ValueNotifier<bool>(false);
    final indexOfAsset = useState(assetList.indexOf(asset));

    PageController controller =
        PageController(initialPage: assetList.indexOf(asset));

    useEffect(
      () {
        threeStageLoading.value = appSettingService
            .getSetting<bool>(AppSettingsEnum.threeStageLoading);
        return null;
      },
      [],
    );

    getAssetExif() async {
      if (assetList[indexOfAsset.value].isRemote) {
        assetDetail = await ref
            .watch(assetServiceProvider)
            .getAssetById(assetList[indexOfAsset.value].id);
      } else {
        // TODO local exif parsing?
        assetDetail = assetList[indexOfAsset.value];
      }
    }

    void showInfo() {
      showModalBottomSheet(
        backgroundColor: Colors.black,
        barrierColor: Colors.transparent,
        isScrollControlled: false,
        context: context,
        builder: (context) {
          return ExifBottomSheet(assetDetail: assetDetail!);
        },
      );
    }

    //make isZoomed listener call instead
    void isZoomedMethod() {
      if (isZoomedListener.value) {
        isZoomed.value = true;
      } else {
        isZoomed.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: TopControlAppBar(
        loading: loading.value,
        asset: assetList[indexOfAsset.value],
        onMoreInfoPressed: () {
          showInfo();
        },
        onDownloadPressed: assetList[indexOfAsset.value].isLocal
            ? null
            : () {
                ref.watch(imageViewerStateProvider.notifier).downloadAsset(
                    assetList[indexOfAsset.value].remote!, context);
              },
        onSharePressed: () {
          ref
              .watch(imageViewerStateProvider.notifier)
              .shareAsset(assetList[indexOfAsset.value], context);
        },
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: controller,
          pageSnapping: true,
          physics: isZoomed.value
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: assetList.length,
          scrollDirection: Axis.horizontal,
          onPageChanged: (value) {
            indexOfAsset.value = value;
            HapticFeedback.selectionClick();
          },
          itemBuilder: (context, index) {
            getAssetExif();

            if (assetList[index].isImage) {
              return ImageViewerPage(
                authToken: 'Bearer ${box.get(accessTokenKey)}',
                isZoomedFunction: isZoomedMethod,
                isZoomedListener: isZoomedListener,
                asset: assetList[index],
                heroTag: assetList[index].id,
                threeStageLoading: threeStageLoading.value,
              );
            } else {
              return GestureDetector(
                onVerticalDragUpdate: (details) {
                  const int sensitivity = 10;
                  if (details.delta.dy > sensitivity) {
                    // swipe down
                    AutoRouter.of(context).pop();
                  } else if (details.delta.dy < -sensitivity) {
                    // swipe up
                    showInfo();
                  }
                },
                child: Hero(
                  tag: assetList[index].id,
                  child: VideoViewerPage(asset: assetList[index]),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
