import 'dart:io';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../services/pdf_cache_service.dart';
import '../../services/api_service.dart';

part 'pdf_event.dart';
part 'pdf_state.dart';

class PdfBloc extends Bloc<PdfEvent, PdfState> {
  PdfBloc() : super(PdfInitial()) {
    on<LoadPdfEvent>((event, emit) async {
      emit(PdfLoading());
      try {
        // Extrai apenas o número da linha se vier formatado como "Linha 1" -> "1"
        final lineName = event.lineShortName.replaceAll(RegExp(r'[a-zA-Z\s]'), '').trim();

        if (kIsWeb) {
          // No navegador (Web), o sistema de ficheiros local do dispositivo não está disponível.
          // Tentamos verificar se o ficheiro PDF está acessível online no backend.
          final url = Uri.parse('${ApiService.baseUrl}/pdf/$lineName.pdf');
          final response = await http.head(url).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            emit(PdfLoadedLocal(url.toString(), event.lineShortName));
          } else {
            throw HttpException('Horário não disponível no servidor.');
          }
          return;
        }

        final isCached = await PdfCacheService.isPdfCached(lineName);
        if (isCached) {
          final file = await PdfCacheService.getCachedPdfFile(lineName);
          emit(PdfLoadedLocal(file.path, event.lineShortName));
        } else {
          // Não existe localmente. Tenta descarregar do backend.
          final path = await PdfCacheService.downloadAndCachePdf(lineName);
          emit(PdfLoadedLocal(path, event.lineShortName));
        }
      } on SocketException catch (_) {
        emit(PdfError(
          kIsWeb
              ? 'A consulta de PDFs offline está otimizada para a aplicação móvel (Android/iOS). No navegador, ligue-se à internet para visualizar o PDF online.'
              : 'Sem ligação à Internet. É necessária ligação de rede para efetuar o primeiro download deste horário.',
        ));
      } catch (e) {
        emit(PdfError(
          kIsWeb
              ? 'A consulta de PDFs offline está otimizada para a aplicação móvel (Android/iOS). No navegador, ligue-se à internet para visualizar o PDF online.'
              : 'Erro ao carregar o horário. Verifique a sua ligação e tente novamente.',
        ));
      }
    });
  }
}

