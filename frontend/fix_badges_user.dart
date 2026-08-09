import 'dart:io';

void main() {
  final dir = Directory('lib/features/dashboard/screens');
  if (!dir.existsSync()) return;

  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('NotificationsScreen(userId: _currentUser.id ?? \'\')')) {
      content = content.replaceAll(
        'NotificationsScreen(userId: _currentUser.id ?? \'\')', 
        'NotificationsScreen(userId: \'\')'
      );
      file.writeAsStringSync(content);
      print('Fixed \${file.path}');
    }
  }
}
