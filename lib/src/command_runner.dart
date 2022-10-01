import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_console/dart_console.dart';
import 'package:get_it/get_it.dart';
import 'package:tint/tint.dart';

import 'package:rush_cli/src/commands/build/build.dart';
import 'package:rush_cli/src/commands/clean.dart';
import 'package:rush_cli/src/commands/create/create.dart';
import 'package:rush_cli/src/commands/deps/deps.dart';
import 'package:rush_cli/src/commands/migrate/migrate.dart';
import 'package:rush_cli/src/commands/upgrade/upgrade.dart';
import 'package:rush_cli/src/services/logger.dart';
import 'package:rush_cli/src/version.dart';

class RushCommandRunner extends CommandRunner<int> {
  RushCommandRunner()
      : super('rush',
            'Rush is a fast and feature rich extension builder for MIT App Inventor 2.') {
    _printAsciiArt();

    argParser.addFlag('version',
        abbr: 'v',
        negatable: false,
        help: 'Prints the current version name.', callback: (v) {
      if (v) {
        Console().writeLine('Running on version ${packageVersion.cyan()}');
        exit(0);
      }
    });

    addCommand(BuildCommand());
    addCommand(CleanCommand());
    addCommand(CreateCommand());
    addCommand(DepsCommand());
    addCommand(MigrateCommand());
    addCommand(UpgradeCommand());
  }

  void _printAsciiArt() {
    final art = r'''
                    __
   _______  _______/ /_
  / ___/ / / / ___/ __ \
 / /  / /_/ (__  / / / /
/_/   \__,_/____/_/ /_/
'''
        .blue();
    Console().writeLine(art);
  }
}

abstract class RushCommand extends Command<int> {
  RushCommand() {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Turns on verbose logging.',
      callback: (v) {
        if (v) {
          GetIt.I<Logger>().debug = true;
        }
      },
    );
  }
}