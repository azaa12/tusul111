import 'dart:convert';
import 'package:app/pages/order_detail.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OrderPage extends StatefulWidget {
  final int userId;
  const OrderPage({super.key, required this.userId});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
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
        Uri.parse('http://localhost:3000/api/orders/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          orders = jsonDecode(response.body);
          print(orders);
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

    if (orders.isEmpty) return const Center(child: Text('No orders found.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final items = order['items'] as List;

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Order #${order['id']}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text("Status: ${order['status']}"),
                Text("Total: \$${order['total']}"),
                Text("Date: ${order['order_date']}"),
                const SizedBox(height: 8),
                const Text(
                  "Items:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...items.map(
                  (item) => ListTile(
                    leading:
                        item['photo_base64'] != null
                            ? Image.memory(
                              base64Decode(item['photo_base64']),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                            : const Icon(Icons.book),
                    title: Text(item['title']),
                    subtitle: Text("Author: ${item['author']}"),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Qty: ${item['quantity']}"),
                        Text("\$${item['price']}"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => OrderDetailPage(
                                userId: widget.userId,
                                order: order,
                              ),
                        ),
                      );
                    },
                    child: const Text("View Details"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
