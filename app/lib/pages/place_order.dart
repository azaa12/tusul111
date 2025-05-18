import 'dart:convert';
import 'package:app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceOrderPage extends StatefulWidget {
  final int userId;
  const PlaceOrderPage({super.key, required this.userId});

  @override
  State<PlaceOrderPage> createState() => _PlaceOrderPageState();
}

class _PlaceOrderPageState extends State<PlaceOrderPage> {
  LatLng? selectedLocation;
  bool _isPlacingOrder = false;
  String? _message;

  static const CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(47.918873, 106.917701),
    zoom: 12,
  );

  Future<void> placeOrder() async {
    if (selectedLocation == null) {
      setState(() {
        _message = "Please select a delivery location on the map.";
      });
      return;
    }

    final url = Uri.parse('http://localhost:3000/api/orders/place');

    setState(() {
      _isPlacingOrder = true;
      _message = null;
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'latitude': selectedLocation!.latitude,
          'longitude': selectedLocation!.longitude,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() {
          _message =
              "✅ Order placed successfully! Order ID: ${data['orderId']}";
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(userId: widget.userId)),
        );
      } else {
        setState(() {
          _message = "❌ ${data['error'] ?? 'Failed to place order'}";
        });
      }
    } catch (e) {
      setState(() {
        _message = '❌ Error placing order: $e';
      });
    } finally {
      setState(() {
        _isPlacingOrder = false;
      });
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      selectedLocation = position;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Delivery Location")),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: initialCameraPosition,
              onTap: _onMapTap,
              markers:
                  selectedLocation == null
                      ? {}
                      : {
                        Marker(
                          markerId: const MarkerId('selected-location'),
                          position: selectedLocation!,
                        ),
                      },
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                _isPlacingOrder
                    ? const CircularProgressIndicator()
                    : Column(
                      children: [
                        if (selectedLocation != null)
                          Text(
                            'Selected Location: (${selectedLocation!.latitude.toStringAsFixed(6)}, '
                            '${selectedLocation!.longitude.toStringAsFixed(6)})',
                          ),
                        if (_message != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _message!,
                            style: TextStyle(
                              color:
                                  _message!.startsWith('✅')
                                      ? Colors.green
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: placeOrder,
                          child: const Text('Place Order'),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
