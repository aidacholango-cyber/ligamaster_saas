import 'package:flutter/material.dart';

class SeccionInicio extends StatelessWidget {
  const SeccionInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF0F2F5),
            child: const TabBar(
              labelColor: Color(0xFF1A3160),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF1A3160),
              tabs: [
                Tab(text: 'AUSPICIANTES'),
                Tab(text: 'NOTICIAS'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.red, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              '¡Aquí se mostrarán los anuncios del campeonato!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1A3160),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Center(child: Text('Sección de Noticias de la Liga')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
