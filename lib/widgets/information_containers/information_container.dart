import 'package:flutter/cupertino.dart';


class InformationContainer extends StatelessWidget {
  final Widget leadingIcon;
  final String title;
  final Widget? richDescription;
  final String description;
  final Widget? trailingIcon;
  final Color color;

  const InformationContainer(
      {super.key,
      required this.leadingIcon,
      required this.title,
      this.trailingIcon,
      this.description = "",
      required this.color,
      this.richDescription});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      width: double.infinity,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        richDescription ??
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(description, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 2)),
            ),
      ]),
    );
  }
}
