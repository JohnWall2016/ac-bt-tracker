import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:process_run/cmd_run.dart';

class BTTrackerCache {

  BTTrackerCache() {
    var dir = Directory(_cachedDir);
    if (!dir.existsSync()) {
      dir.createSync();
    }
  }

  static final String _uri = 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt';

  static String _cachedDir = (() {
    if (Platform.environment.containsKey('BTL_CACHE')) {
      return Platform.environment['BTL_CACHE'];
    } else if (Platform.isWindows) {
      var appData = Platform.environment['APPDATA'];
      return path.join(appData, 'btl-cache');
    } else {
      return '${Platform.environment['HOME']}/.btl-cache';
    }
  })();

  String get _cachedFile {
    var currentDate = DateFormat('yyyyMMdd').format(DateTime.now());
    return path.join(_cachedDir, 'btl-$currentDate.txt');
  }

  Future<void> downloadTrackerList({String seperator = ','}) async {
    var httpClient = HttpClient();
    var request = await httpClient.getUrl(Uri.parse(_uri));
    var response = await request.close();
    var list = StringBuffer();
    await for (var line in response
                             .transform(utf8.decoder)
                             .transform(LineSplitter())) {
      if (line != "") {
        if (!list.isEmpty) list.write(seperator);
        list.write(line);
      }
    };
    httpClient.close();
    //print(list);

    var file = File(_cachedFile);
    file.writeAsStringSync(list.toString());
  }

  Future<String> getTrackerList({bool update = false}) async {
    var file = File(_cachedFile);
    if (!file.existsSync() || update) {
      await downloadTrackerList();
    }
    return file.readAsStringSync();
  }

}

void main(List<String> args) async {
  var parser = ArgParser()
    ..addFlag('update-trackers',
              abbr: 'u',
              negatable: false,
              help: 'Update bittorrent tracker list.')
    ..addFlag('help', 
              abbr: 'h',
              negatable: false,
              help: 'Display help informations.');
  var results = parser.parse(args);

  if (results['help']) {
    print('''
ac_bt_tracker.dart [options] torrent
${parser.usage}
    ''');
    return;
  }
  
  var btList = await BTTrackerCache().getTrackerList(update: results['update-trackers']);
  
  var aria2c = path.join(File(Platform.script.toFilePath()).parent.path, 'aria2c');
  var cmd = ProcessCmd(aria2c, ['--bt-tracker=$btList']..addAll(results.rest), 
                       runInShell: Platform.isWindows);
  await runCmd(cmd, stdout: stdout, verbose: true);
}