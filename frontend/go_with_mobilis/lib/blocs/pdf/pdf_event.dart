part of 'pdf_bloc.dart';

abstract class PdfEvent {}

class LoadPdfEvent extends PdfEvent {
  final String lineShortName;

  LoadPdfEvent(this.lineShortName);
}
