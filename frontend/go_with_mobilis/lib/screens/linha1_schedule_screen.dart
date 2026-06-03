import 'package:flutter/material.dart';
import 'pdf_viewer_screen.dart';

class Linha1ScheduleScreen extends StatelessWidget {
  const Linha1ScheduleScreen({super.key});

  /// Função auxiliar que adiciona minutos a uma hora no formato HH:MM
  String _addMinutes(String time, int minutesToAdd) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length != 2) return time;
    
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    
    m += minutesToAdd;
    h += m ~/ 60; // Divisão inteira para adicionar horas
    m = m % 60;   // Resto para obter minutos restantes
    h = h % 24;   // Rodar à meia-noite
    
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Widget _buildScheduleTable(List<String> stops, List<int> offsets, List<String> starts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 0,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 50,
              columnSpacing: 24,
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
              ),
              columns: [
                const DataColumn(label: Text('')),
                ...List.generate(starts.length, (index) => const DataColumn(label: Text(''))),
              ],
              rows: List<DataRow>.generate(stops.length, (rowIndex) {
                final stopName = stops[rowIndex];
                final offset = offsets[rowIndex];
                
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        stopName, 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      )
                    ),
                    ...starts.map((start) {
                      return DataCell(
                        Text(
                          _addMinutes(start, offset),
                          style: const TextStyle(fontSize: 14),
                        )
                      );
                    })
                  ],
                );
              }),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Horários Baseados na Imagem Fornecida
    final diasUteisManha = [
      '06:40','07:10','07:40','08:10','08:40','09:10','09:40',
      '10:10','10:40','11:10','11:40','12:10','12:40','13:10',
      '13:40','14:10'
    ];
    
    final diasUteisTarde = [
      '14:40','15:10','15:40','16:10','16:40',
      '17:10','17:40','18:10','18:40','19:10','19:40','21:00',
      '22:00','23:00','00:00'
    ];
    
    final sabadosStarts = [
      '07:00','08:00','09:00','10:00','11:00','12:00','13:00',
      '19:00','20:00','21:00','22:00','23:00','00:00'
    ];
    
    final domingosStarts = [
      '07:00','09:00','11:00','13:00','18:00','19:00','20:00'
    ];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Horário: Linha 1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF156A40),
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'Ver Guia Oficial (PDF)',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PdfViewerScreen(
                      lineShortName: 'Linha 1',
                      themeColor: Color(0xFF156A40),
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'Dias úteis', icon: Icon(Icons.work)),
              Tab(text: 'Sábados', icon: Icon(Icons.weekend)),
              Tab(text: 'Domingos/Feriados', icon: Icon(Icons.event)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Dias Úteis
            Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('manhã\nmorning', style: TextStyle(color: Color(0xFFa1c436), fontSize: 16, height: 1.2)),
                  ),
                  _buildScheduleTable(
                    ['Lg. José Lúcio', 'Afonso Lopes Vieira', 'Campus 2 IPL', 'Hospital', 'Lg. José Lúcio '],
                    [0, 15, 40, 67, 77],
                    diasUteisManha
                  ),
                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('tarde / noite\nafternoon / night', style: TextStyle(color: Color(0xFFa1c436), fontSize: 16, height: 1.2)),
                  ),
                  _buildScheduleTable(
                    ['Lg. José Lúcio', 'Afonso Lopes Vieira', 'Campus 2 IPL', 'Hospital', 'Lg. José Lúcio '],
                    [0, 15, 40, 67, 77],
                    diasUteisTarde
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // Tab 2: Sábados
            Container(
              color: Colors.white,
              child: _buildScheduleTable(
                ['Lg. José Lúcio', 'Campus 2 IPL', 'Hospital', 'Lg. José Lúcio (Chegada)'],
                [0, 30, 53, 60],
                sabadosStarts
              ),
            ),
            
            // Tab 3: Domingos
            Container(
              color: Colors.white,
              child: _buildScheduleTable(
                 ['Lg. José Lúcio', 'Campus 2 IPL', 'Hospital', 'Lg. José Lúcio (Chegada)'],
                 [0, 30, 53, 60],
                 domingosStarts
              ),
            ),
          ],
        ),
      ),
    );
  }
}
