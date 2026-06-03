import 'package:flutter/material.dart';
import 'pdf_viewer_screen.dart';

class Linha9ScheduleScreen extends StatelessWidget {
  const Linha9ScheduleScreen({super.key});

  /// Função auxiliar que adiciona minutos a uma hora no formato HH:MM
  String _addMinutes(String time, int minutesToAdd) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length != 2) return time;
    
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    
    m += minutesToAdd;
    h += m ~/ 60;
    m = m % 60;
    h = h % 24;
    
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
    // Horários da Linha 9 - Dias úteis
    final diasUteisManha = [
      '08:00','08:40','09:20','12:00','12:40'
    ];
    
    final diasUteisTarde = [
      '13:20','14:00','16:45','17:25','18:05','18:45','19:25'
    ];

    final paragensDiasUteis = ['Lg. José Lúcio', 'Campus 2 IPL', 'Lg. José Lúcio (Chegada)'];
    final offsetsDiasUteis = [0, 25, 40];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Horário: Linha 9', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black87, // Linha 9 is Black
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
                      lineShortName: 'Linha 9',
                      themeColor: Colors.black87,
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
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF475569)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Serviço só se realiza de 1 de Setembro a 30 de Junho.\nOnly from 1 September to 30 June.',
                            style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('manhã\nmorning', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
                  ),
                  _buildScheduleTable(paragensDiasUteis, offsetsDiasUteis, diasUteisManha),
                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('tarde\nafternoon', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
                  ),
                  _buildScheduleTable(paragensDiasUteis, offsetsDiasUteis, diasUteisTarde),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // Tab 2: Sábados
            Container(
              color: Colors.white,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'A Linha 9 não efetua serviço aos Sábados.', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16)
                  ),
                ),
              ),
            ),
            
            // Tab 3: Domingos
            Container(
              color: Colors.white,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'A Linha 9 não efetua serviço aos Domingos e Feriados.', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16)
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
