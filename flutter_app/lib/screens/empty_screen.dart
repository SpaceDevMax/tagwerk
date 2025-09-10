import 'package:flutter/material.dart';

class EmptyScreen extends StatelessWidget {
  const EmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empty Screen'), // Optional: Add a title for context
      ),
      body: const Center(
        child: Placeholder(
          fallbackHeight: 200, // Customize height (optional)
          fallbackWidth: 200,  // Customize width (optional)
          color: Colors.grey,  // Customize color (optional)
          strokeWidth: 2.0,    // Customize line thickness (optional)
        ),
      ),
    );
  }
}