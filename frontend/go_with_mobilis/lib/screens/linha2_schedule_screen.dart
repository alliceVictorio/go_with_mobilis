import 'package:flutter/material.dart';

class Linha2ScheduleScreen extends StatelessWidget {
  const Linha2ScheduleScreen({super.key});

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
    // Horários da Linha 2 - Dias úteis
    final diasUteisManha = [
      '06:50','07:20','07:50','08:20','08:50','09:20','09:50','10:20',
      '10:50','11:20','11:50','12:20','12:50'
    ];
    
    final diasUteisTarde = [
      '13:20','13:50','14:20','14:50','15:20','15:50','16:20','16:50',
      '17:20','17:50','18:20','18:50','19:20','19:50'
    ];
    
    final sabadosStarts = [
      '07:30','08:30','09:30','10:30','11:30','12:30','13:30',
      '14:30','15:30','16:30','17:30','18:30','19:30','20:30'
    ];

    // Ordem inversa da linha 1
    final paragensDiasUteis = ['Lg. José Lúcio', 'Hospital', 'Campus 2 IPL', 'Afonso Lopes Vieira', 'Lg. José Lúcio (Chegada)'];
    final offsetsDiasUteis = [0, 10, 37, 62, 77];
    
    final paragensSabados = ['Lg. José Lúcio', 'Hospital', 'Campus 2 IPL', 'Lg. José Lúcio (Chegada)'];
    final offsetsSabados = [0, 8, 30, 60];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Horário: Linha 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red, // Linha 2 is Red
          elevation: 0,
          leading: const BackButton(color: Colors.white),
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
                    child: Text('manhã\nmorning', style: TextStyle(color: Color(0xFFE31C39), fontSize: 16, height: 1.2)),
                  ),
                  _buildScheduleTable(paragensDiasUteis, offsetsDiasUteis, diasUteisManha),
                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('tarde\nafternoon', style: TextStyle(color: Color(0xFFE31C39), fontSize: 16, height: 1.2)),
                  ),
                  _buildScheduleTable(paragensDiasUteis, offsetsDiasUteis, diasUteisTarde),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // Tab 2: Sábados
            Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Sábados\nsaturdays', style: TextStyle(color: Color(0xFFE31C39), fontSize: 16, height: 1.2)),
                  ),
                  _buildScheduleTable(paragensSabados, offsetsSabados, sabadosStarts),
                ],
              ),
            ),
            
            // Tab 3: Domingos
            Container(
              color: Colors.white,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'A Linha 2 não efetua serviço aos Domingos e Feriados.', 
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
