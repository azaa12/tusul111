import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProductDetailPage extends StatelessWidget {
  final Map product;
  final int userId;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.userId,
  });

  Future<void> addToCart(BuildContext context) async {
    final url = Uri.parse('http://localhost:3000/api/cart/add');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'productId': product['id'],
          'quantity': 1,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to cart')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add to cart')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoBase64 = product['photo_base64'];
    return Scaffold(
      appBar: AppBar(title: Text(product['title'] ?? 'Product Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            photoBase64 != null
                ? Image.memory(
                  base64Decode(photoBase64),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                )
                : const Icon(Icons.image_not_supported, size: 100),
            const SizedBox(height: 16),
            Text(
              product['title'] ?? '',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(product['description'] ?? ''),
            const SizedBox(height: 8),
            Text(
              '\$${product['price'] ?? '0.00'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => addToCart(context),
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }
}
