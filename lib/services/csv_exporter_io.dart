import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> exportCsvText(String fileName, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  return file.path;
}
