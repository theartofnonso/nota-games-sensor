import 'package:flutter/material.dart';
import 'glass_container.dart';

/// Example usage of TRNR Theme Glassmorphism components
/// 
/// This file demonstrates how to use GlassContainer, GlassButton, and StatusIndicator
/// widgets in your app.
class GlassContainerExamples extends StatelessWidget {
  const GlassContainerExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(title: const Text('TRNR Theme Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 24,
          children: [
            // Glass Card Example
            const Text(
              'Glass Cards',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            GlassContainer(
              style: GlassStyle.light,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Light Glass Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'backdrop-blur-xl bg-white/5 border-white/10',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            GlassContainer(
              style: GlassStyle.medium,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medium Glass Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'backdrop-blur-xl bg-white/10 border-white/20',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            GlassContainer(
              style: GlassStyle.dark,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dark Glass Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'backdrop-blur-xl bg-zinc-900/30 border-white/5',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Glass Buttons Example
            const Text(
              'Glass Buttons',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            GlassButton(
              onPressed: () {},
              glowState: GlowState.idle,
              child: const Text('Success Glow (Green)'),
            ),
            GlassButton(
              onPressed: () {},
              glowState: GlowState.active,
              child: const Text('Active Glow (Blue)'),
            ),
            GlassButton(
              onPressed: () {},
              glowState: GlowState.error,
              child: const Text('Error Glow (Red)'),
            ),
            GlassButton(
              onPressed: () {},
              glowState: GlowState.none,
              child: const Text('No Glow'),
            ),

            const SizedBox(height: 16),

            // Status Indicators Example
            const Text(
              'Status Indicators',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatusIndicator(
                  label: 'Active',
                  type: StatusType.success,
                ),
                StatusIndicator(
                  label: 'Processing',
                  type: StatusType.info,
                ),
                StatusIndicator(
                  label: 'Error',
                  type: StatusType.error,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Combined Example
            const Text(
              'Combined Example',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            GlassContainer(
              style: GlassStyle.medium,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Workout Session',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      StatusIndicator(
                        label: 'Active',
                        type: StatusType.success,
                      ),
                    ],
                  ),
                  Text(
                    '45 minutes • Upper Body',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassButton(
                    onPressed: () {},
                    glowState: GlowState.active,
                    child: const Text('Start Workout'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

