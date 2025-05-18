import 'dart:convert';
import 'package:app/pages/deliver_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DriverPage extends StatefulWidget {
  final int userId;
  const DriverPage({super.key, required this.userId});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  List<dynamic> orders = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://localhost:3000/api/orders',
        ), // use 10.0.2.2 for emulator
      );

      if (response.statusCode == 200) {
        setState(() {
          orders = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load orders';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(error!));

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Orders')),
      body: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final itemCount = (order['items'] as List).length;

          return ListTile(
            title: Text('Order #${order['id']}'),
            subtitle: Text('Items: $itemCount  •  Status: ${order['status']}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => DeliveryDetailPage(
                        userId: widget.userId,
                        delivery: order,
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
