import 'dart:convert';

import 'package:app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final int userId;
  const OrderDetailPage({super.key, required this.userId, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late GoogleMapController _mapController;

  late LatLng _deliveryLocation;
  LatLng? _driverLocation;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _showRoute = false;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    print(widget.order['driver_latitude']);
    // Delivery location
    final double latitude = double.parse(widget.order['latitude'].toString());
    final double longitude = double.parse(widget.order['longitude'].toString());
    _deliveryLocation = LatLng(latitude, longitude);

    // Add delivery marker
    _markers.add(
      Marker(
        markerId: const MarkerId('delivery_location'),
        position: _deliveryLocation,
        infoWindow: const InfoWindow(title: 'Delivery Location'),
      ),
    );

    // Parse driver location if available
    if (widget.order['driver_latitude'] != null &&
        widget.order['driver_longitude'] != null) {
      final double driverLat = double.parse(
        widget.order['driver_latitude'].toString(),
      );
      final double driverLng = double.parse(
        widget.order['driver_longitude'].toString(),
      );
      _driverLocation = LatLng(driverLat, driverLng);

      // Add driver marker with blue color and info "Жолоочийн байршил"
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _driverLocation!,
          infoWindow: const InfoWindow(title: 'Жолоочийн байршил'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _toggleRoute() {
    if (_driverLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver location not available yet')),
      );
      return;
    }

    if (_showRoute) {
      setState(() {
        _polylines.clear();
        _showRoute = false;
      });
    } else {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_driverLocation!, _deliveryLocation],
            color: Colors.blue,
            width: 5,
          ),
        );
        _showRoute = true;
      });

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _driverLocation!.latitude < _deliveryLocation.latitude
              ? _driverLocation!.latitude
              : _deliveryLocation.latitude,
          _driverLocation!.longitude < _deliveryLocation.longitude
              ? _driverLocation!.longitude
              : _deliveryLocation.longitude,
        ),
        northeast: LatLng(
          _driverLocation!.latitude > _deliveryLocation.latitude
              ? _driverLocation!.latitude
              : _deliveryLocation.latitude,
          _driverLocation!.longitude > _deliveryLocation.longitude
              ? _driverLocation!.longitude
              : _deliveryLocation.longitude,
        ),
      );
      _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  Future<void> _acceptOrder() async {
    final int orderId = int.parse(widget.order['id'].toString());

    final url = Uri.parse('http://localhost:3000/api/orders1/$orderId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order status updated to accepted!')),
        );

        setState(() {
          widget.order['status'] = 'accepted';
        });

        await Future.delayed(const Duration(milliseconds: 300));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(userId: widget.userId)),
        );
      } else {
        final responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${responseData['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(title: Text('Order #${order['id']}')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${order['status']}'),
              Text('Total: \$${order['total']}'),
              if (_driverLocation != null) ...[
                Text('Driver Latitude: ${_driverLocation!.latitude}'),
                Text('Driver Longitude: ${_driverLocation!.longitude}'),
              ],
              Text('Delivery Latitude: ${_deliveryLocation.latitude}'),
              Text('Delivery Longitude: ${_deliveryLocation.longitude}'),
              const SizedBox(height: 16),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(order['items'] as List<dynamic>).map((item) {
                return ListTile(
                  title: Text(item['title']),
                  subtitle: Text(
                    'Qty: ${item['quantity']} - \$${item['price']}',
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
              const Text(
                'Delivery Location on Map:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  SizedBox(
                    height: 300,
                    child: GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;

                        // Move camera to driver location if available, else delivery location
                        if (_driverLocation != null) {
                          _mapController.moveCamera(
                            CameraUpdate.newLatLngZoom(_driverLocation!, 13),
                          );
                        } else {
                          _mapController.moveCamera(
                            CameraUpdate.newLatLngZoom(_deliveryLocation, 13),
                          );
                        }
                      },
                      initialCameraPosition: CameraPosition(
                        target: _driverLocation ?? _deliveryLocation,
                        zoom: 13,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                    ),
                  ),
                  if (_isLoading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              if (_driverLocation == null)
                const Center(
                  child: Text(
                    'Жолооч таны захиасыг хараахан аваагүй байна.',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),

              Center(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleRoute,
                      icon: const Icon(Icons.directions),
                      label: Text(_showRoute ? 'Hide Route' : 'Show Route'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _acceptOrder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Accept Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
