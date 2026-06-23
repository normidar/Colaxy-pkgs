import 'package:args/args.dart';
import 'package:colaxy_icons_launcher/cli_commands.dart';
import 'package:colaxy_icons_launcher/utils/cli_logger.dart';
import 'package:colaxy_icons_launcher/utils/constants.dart';

/// Run to create icons launcher
Future<void> main(List<String> arguments) async {
  print(START_MESSAGE);
  final parser = ArgParser();

  parser.addOption('path');
  parser.addOption('flavor');
  parser.addOption('flavors');

  final parsedArgs = parser.parse(arguments);

  if (parsedArgs['flavor'] != null && parsedArgs['flavors'] != null) {
    throw Exception('Cannot use both flavor and flavors arguments');
  }

  final path = parsedArgs['path'] as String?;

  if (parsedArgs['flavor'] != null) {
    await createIconsLauncher(
      path: path,
      flavor: parsedArgs['flavor'] as String?,
    );
  } else if (parsedArgs['flavors'] != null) {
    final flavors = parsedArgs['flavors'].toString().split(',');
    for (final flavor in flavors) {
      await createIconsLauncher(path: path, flavor: flavor);
    }
  } else {
    await createIconsLauncher(path: path, flavor: null);
  }

  CliLogger.success(
    '\n\n==> 🎉 ICONS LAUNCHER GENERATED SUCCESSFULLY 🎉 <==',
    emoji: '',
  );

  print(END_MESSAGE);
}
