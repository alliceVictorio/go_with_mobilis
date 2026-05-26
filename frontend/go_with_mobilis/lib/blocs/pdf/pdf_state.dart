part of 'pdf_bloc.dart';

abstract class PdfState {}

class PdfInitial extends PdfState {}

class PdfLoading extends PdfState {}

class PdfLoadedLocal extends PdfState {
  final String filePath;
  final String lineShortName;

  PdfLoadedLocal(this.filePath, this.lineShortName);
}

class PdfError extends PdfState {
  final String message;

  PdfError(this.message);
}
