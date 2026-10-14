import 'package:flutter/material.dart';
import '../core/theme.dart';

class ChamaeOfficialLogo extends StatelessWidget {
  final double size;
  const ChamaeOfficialLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryGold, width: size * 0.04),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.25),
            blurRadius: size * 0.2,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.lightGold,
            alignment: Alignment.center,
            child: Icon(
              Icons.local_fire_department_rounded,
              size: size * 0.55,
              color: AppColors.primaryGold,
            ),
          ),
        ),
      ),
    );
  }
}