import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class DeliveryDetailPage extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final int userId;
  const DeliveryDetailPage({
    super.key,
    required this.userId,
    required this.delivery,
  });

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  late GoogleMapController _mapController;
  final Location _locationService = Location();

  LatLng? _currentLocation;
  late LatLng _deliveryLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _showRoute = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final double latitude = double.parse(
      widget.delivery['latitude'].toString(),
    );
    final double longitude = double.parse(
      widget.delivery['longitude'].toString(),
    );
    _deliveryLocation = LatLng(latitude, longitude);

    _markers.add(
      Marker(
        markerId: const MarkerId('delivery_location'),
        position: _deliveryLocation,
        infoWindow: const InfoWindow(title: 'Delivery Location'),
      ),
    );

    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLoading = true;
    });

    if (kIsWeb) {
      try {
        // Web-specific geolocation API handling
        await _getLocationForWeb();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    } else {
      // Mobile location handling
      await _getLocationForMobile();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getLocationForWeb() async {
    final geolocation = html.window.navigator.geolocation;

    try {
      await geolocation.getCurrentPosition().then((position) {
        setState(() {
          _currentLocation = LatLng(
            position.coords!.latitude!.toDouble(),
            position.coords!.longitude!.toDouble(),
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: _currentLocation!,
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
            ),
          );
        });
      });
    } catch (e) {
      throw Exception('Browser location permission denied or error: $e');
    }
  }

  Future<void> _getLocationForMobile() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    final locationData = await _locationService.getLocation();
    setState(() {
      _currentLocation = LatLng(
        locationData.latitude!,
        locationData.longitude!,
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  void _toggleRoute() {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available yet')),
      );
      return;
    }

    if (_showRoute) {
      setState(() {
        _polylines.clear();
        _showRoute = false;
      });
    } else {
      // For demo: Just draw a straight line between two points (no real route)
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_currentLocation!, _deliveryLocation],
            color: Colors.blue,
            width: 5,
          ),
        );
        _showRoute = true;
      });

      // Optionally move camera to show both points
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentLocation!.latitude < _deliveryLocation.latitude
              ? _currentLocation!.latitude
              : _deliveryLocation.latitude,
          _currentLocation!.longitude < _deliveryLocation.longitude
              ? _currentLocation!.longitude
              : _deliveryLocation.longitude,
        ),
        northeast: LatLng(
          _currentLocation!.latitude > _deliveryLocation.latitude
              ? _currentLocation!.latitude
              : _deliveryLocation.latitude,
          _currentLocation!.longitude > _deliveryLocation.longitude
              ? _currentLocation!.longitude
              : _deliveryLocation.longitude,
        ),
      );
      _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  Future<void> _acceptDelivery() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location is not available')),
      );
      return;
    }

    final int orderId = int.parse(widget.delivery['id'].toString());
    final double driverLatitude = _currentLocation!.latitude;
    final double driverLongitude = _currentLocation!.longitude;

    final url = Uri.parse('http://localhost:3000/api/orders/$orderId');

    final body = jsonEncode({
      'driver_latitude': driverLatitude,
      'driver_longitude': driverLongitude,
    });

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver location updated for order!')),
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
    final delivery = widget.delivery;

    return Scaffold(
      appBar: AppBar(title: Text('Order #${delivery['id']}')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${delivery['status']}'),
              Text('Total: \$${delivery['total']}'),
              Text('Latitude: ${_deliveryLocation.latitude}'),
              Text('Longitude: ${_deliveryLocation.longitude}'),
              const SizedBox(height: 16),
              Text(
                'Items:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(delivery['items'] as List<dynamic>).map((item) {
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
                      },
                      initialCameraPosition: CameraPosition(
                        target: _deliveryLocation,
                        zoom: 15,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
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
              Center(
                child: ElevatedButton.icon(
                  onPressed: _toggleRoute,
                  icon: const Icon(Icons.directions),
                  label: Text(_showRoute ? 'Hide Route' : 'Show Route'),
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
                      onPressed: _acceptDelivery,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Accept Delivery'),
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
