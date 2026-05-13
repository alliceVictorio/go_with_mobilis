import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Testar se os serviços de GPS do telemóvel estão ligados
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Pedir para ligar o GPS (dependendo do Sistema Operativo fará um prompt nativo)
      return null;
    }

    // Verificar se o utilizador já permitiu esta app de usar a localização
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Se negar pela 1ª vez
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Se tiver negado para sempre e selecionado "Não perguntar novamente"
      return null;
    } 

    // Se chegar aqui é porque está tudo autorizado
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    
    return LatLng(position.latitude, position.longitude);
  }
}
