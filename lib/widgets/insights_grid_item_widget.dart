import 'package:flutter/material.dart';


import '../colors.dart';

class InsightsGridItemWidget extends StatelessWidget {
  final String title;
  final void Function()? onTap;
  final String image;

  const InsightsGridItemWidget({super.key, required this.title, this.onTap, required this.image});

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          height: 200,
          child: Stack(children: [
            Positioned.fill(
                child: Image.asset(
             image,
              fit: BoxFit.cover,
            )),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    sapphireDark.withValues(alpha: 0.3),
                    sapphireDark.withValues(alpha: 0.9),
                    sapphireDark,
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 20.0, left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 14, )),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
