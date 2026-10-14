import 'package:flutter/material.dart';

class RealWebMap extends StatelessWidget {
  final double courierLat;
  final double courierLng;
  final String courierName;

  const RealWebMap({
    super.key,
    this.courierLat = -22.5298,
    this.courierLng = -55.7275,
    this.courierName = 'Marcos Silva (Moto 01)',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Mapa base ilustrativo das ruas de Ponta Porã / PJC
            Positioned.fill(
              child: Image.network(
                'https://staticmap.openstreetmap.de/staticmap.php?center=-22.5350,-55.7250&zoom=14&size=600x400&maptype=mapnik',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: Icon(Icons.map_rounded, size: 48, color: Colors.blueGrey),
                  ),
                ),
              ),
            ),

            // Linha simulada de rota
            Center(
              child: Container(
                width: 140,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
              ),
            ),

            // Marcador da Loja
            const Positioned(
              left: 40,
              top: 70,
              child: Column(
                children: [
                  Icon(Icons.store_mall_directory_rounded, color: Colors.black, size: 28),
                  Text('Pit Stop V8', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white70)),
                ],
              ),
            ),

            // Marcador do Motoboy em movimento
            Positioned(
              right: 80,
              bottom: 60,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFCC00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, size: 20, color: Colors.black),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      courierName,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Marcador de Destino do Cliente
            const Positioned(
              right: 30,
              bottom: 40,
              child: Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}