import 'dart:io';

import 'package:collection/collection.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:tint/tint.dart';

import 'package:rush_cli/commands/migrate/old_config/old_config.dart' as old;
import 'package:rush_cli/commands/rush_command.dart';
import 'package:rush_cli/config/config.dart';
import 'package:rush_cli/services/file_service.dart';
import 'package:rush_cli/services/logger.dart';

class MigrateCommand extends RushCommand {
  final _fs = GetIt.I<FileService>();
  final _lgr = GetIt.I<Logger>();

  @override
  String get description =>
      'Migrates extension projects built with Rush v1.*.* to Rush v2.*.*';

  @override
  String get name => 'migrate';

  @override
  Future<int> run() async {
    final oldConfig = await old.OldConfig.load(_fs.configFile, _lgr);
    if (oldConfig == null) {
      _lgr.err('Failed to load old config');
      return 1;
    }

    final newConfig = Config(
      version: oldConfig.version.name.toString(),
      assets: oldConfig.assets.other ?? [],
      desugar: oldConfig.build?.desugar?.enable ?? false,
      runtimeDeps: oldConfig.deps ?? [],
      license: oldConfig.license ?? '',
      homepage: oldConfig.homepage ?? '',
      android: Android(minSdk: oldConfig.minSdk),
      kotlin: Kotlin(
        compilerVersion: '1.7.10',
      ),
    );

    final srcFile = _fs.srcDir.listSync(recursive: true).firstWhereOrNull(
        (el) => p.basenameWithoutExtension(el.path) == oldConfig.name);
    if (srcFile == null || srcFile is! File) {
      _lgr
        ..err('Unable to find the main extension source file.')
        ..log(
            'Make sure that the name of the main source file matches with `name` field in rush.yml: `${oldConfig.name}`',
            'help '.green());
      return 1;
    }

    _editSourceFile(srcFile, oldConfig);
    _updateConfig(newConfig, oldConfig.build?.kotlin?.enable ?? false);
    _deleteOldHiveBoxes();

    return 0;
  }

  void _editSourceFile(File srcFile, old.OldConfig oldConfig) {
    final RegExp regex;
    if (p.extension(srcFile.path) == '.java') {
      regex =
          RegExp(r'public\s+class.+\s+extends\s+AndroidNonvisibleComponent.*');
    } else {
      regex = RegExp(
          r'class\s+.+\s*\((.|\n)*\)\s+:\s+AndroidNonvisibleComponent.*');
    }

    final fileContent = srcFile.readAsStringSync();
    final match = regex.firstMatch(fileContent);
    final matchedStr = match?.group(0);

    if (match == null || matchedStr == null) {
      _lgr
        ..err('Unable to process src file: ${srcFile.path}')
        ..log('Are you sure that it is a valid extension source file?',
            'help '.green());
      throw Exception();
    }

    final annotation = '''
// You might want to shorten this annotation name by importing `com.google.appinventor.components.annotations.ExtensionComponent`
@com.google.appinventor.components.annotations.ExtensionComponent(
    name = "${oldConfig.name}",
    description = "Extension component for ${oldConfig.name}. Built with <3 and Rush.",
    icon = "${oldConfig.assets.icon}"
)
''';

    final newContent =
        fileContent.replaceFirst(matchedStr, annotation + matchedStr);
    srcFile.writeAsStringSync(newContent);
  }

  void _deleteOldHiveBoxes() {
    _fs.dotRushDir
        .listSync()
        .where((el) =>
            p.extension(el.path) == '.hive' || p.extension(el.path) == '.lock')
        .forEach((el) {
      el.deleteSync();
    });
  }

  void _updateConfig(Config config, bool enableKotlin) {
    var contents = 'version: \'${config.version}\'\n\n';
    contents += '''
android:
  min_sdk: ${config.android?.minSdk ?? 7}
  compile_sdk: ${config.android?.compileSdk ?? 31}

''';

    if (config.homepage.isNotEmpty) {
      contents += '${config.homepage}\n\n';
    }

    if (config.license.isNotEmpty) {
      contents += '${config.license}\n\n';
    }

    if (config.assets.isNotEmpty) {
      contents += '''
assets:
${config.assets.map((el) => '- $el').join('\n')}

''';
    }

    if (config.desugar) {
      contents += 'desugar: true\n\n';
    }

    if (enableKotlin) {
      contents += '''
kotlin:
  compiler_version: ${config.kotlin!.compilerVersion}

''';
    }

    if (config.runtimeDeps.isNotEmpty) {
      contents += '''
# Runtime dependencies of your extension. These can be local JARs or AARs stored in the deps/ directory or coordinates
# of remote Maven artifacts in <groupId>:<artifactId>:<version> format.
dependencies:
${enableKotlin ? 'org.jetbrains.kotlin:kotlin-stdlib:${config.kotlin!.compilerVersion}' : ''}
${config.runtimeDeps.map((el) => '- $el').join('\n')}
''';
    }

    _fs.configFile.writeAsStringSync(contents);
  }
}