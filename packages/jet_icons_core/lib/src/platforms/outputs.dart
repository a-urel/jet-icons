import '../model/document.dart';
import '../model/override.dart';
import 'android.dart';
import 'ios.dart';
import 'linux.dart';
import 'macos.dart';
import 'output.dart';
import 'web.dart';
import 'windows.dart';

/// Every file [platform] needs for [doc].
List<OutputFile> outputsFor(IconPlatform platform, IconDocument doc) =>
    switch (platform) {
      IconPlatform.ios => iosOutputs(doc),
      IconPlatform.android => androidOutputs(doc),
      IconPlatform.macos => macosOutputs(doc),
      IconPlatform.windows => windowsOutputs(doc),
      IconPlatform.web => webOutputs(doc),
      IconPlatform.linux => linuxOutputs(doc),
    };
