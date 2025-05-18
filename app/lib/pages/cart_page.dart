import 'dart:convert';
import 'package:app/pages/place_order.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CartPage extends StatefulWidget {
  final int userId;
  const CartPage({super.key, required this.userId});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List cartItems = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchCartItems();
  }

  Future<void> fetchCartItems() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = Uri.parse('http://localhost:3000/api/cart/${widget.userId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          cartItems = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load cart items';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });
    }
  }

  Widget buildCartItem(Map item) {
    return ListTile(
      leading:
          item['photo_base64'] != null
              ? Image.memory(
                base64Decode(item['photo_base64']),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
              : const Icon(Icons.image_not_supported),
      title: Text(item['title'] ?? 'No title'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item['description'] ?? ''),
          Text('Quantity: ${item['quantity']}'),
        ],
      ),
      trailing: Text('\$${item['price'] ?? '0.00'}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Cart")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : cartItems.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        return buildCartItem(cartItems[index]);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => PlaceOrderPage(userId: widget.userId),
                          ),
                        );
                      },
                      child: const Text("Checkout"),
                    ),
                  ),
                ],
              ),
    );
  }
}
