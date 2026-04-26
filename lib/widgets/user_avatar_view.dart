import 'dart:convert';

import 'package:flutter/material.dart';

class UserAvatarView extends StatelessWidget {
  const UserAvatarView({
    super.key,
    this.avatarBase64,
    this.radius = 40,
  });

  final String? avatarBase64;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final a = avatarBase64;
    if (a != null && a.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: ClipOval(
          child: Image.memory(
            base64Decode(a),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => _fallback(context),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(Icons.person, size: radius, color: Theme.of(context).colorScheme.primary),
    );
  }

  Widget _fallback(BuildContext context) {
    return Icon(Icons.person, size: radius, color: Theme.of(context).colorScheme.primary);
  }
}
