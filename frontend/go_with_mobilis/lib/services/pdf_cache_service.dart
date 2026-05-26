import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class PdfCacheService {
  /// Retorna o caminho local onde o PDF da linha deve ser armazenado.
  static Future<String> _getLocalPath(String lineShortName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/linha_$lineShortName.pdf';
  }

  /// Verifica se o PDF da linha já existe localmente na cache.
  static Future<bool> isPdfCached(String lineShortName) async {
    try {
      final path = await _getLocalPath(lineShortName);
      final file = File(path);
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  /// Retorna a instância File do PDF guardado localmente.
  static Future<File> getCachedPdfFile(String lineShortName) async {
    final path = await _getLocalPath(lineShortName);
    return File(path);
  }

  /// Faz o download do PDF a partir do backend e guarda-o localmente.
  /// Retorna o caminho absoluto do ficheiro guardado localmente.
  static Future<String> downloadAndCachePdf(String lineShortName) async {
    final path = await _getLocalPath(lineShortName);
    final file = File(path);

    final url = Uri.parse('${ApiService.baseUrl}/pdf/$lineShortName.pdf');
    final response = await http.get(url).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      // Garantir que a pasta existe antes de escrever
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await file.writeAsBytes(response.bodyBytes);
      return path;
    } else {
      throw HttpException(
        'Falha ao descarregar PDF da linha $lineShortName. Status: ${response.statusCode}',
      );
    }
  }
}
