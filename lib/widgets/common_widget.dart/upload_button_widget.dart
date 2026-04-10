  import 'package:flutter/material.dart';

Widget uploadButton() {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text(
          "Upload Potato Photo",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

