import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter/services.dart';

import '../../../dtos/set_dtos/set_dto.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class SetCheckButton extends StatelessWidget {
  final SetDto setDto;
  final void Function() onCheck;

  const SetCheckButton({super.key, required this.setDto, required this.onCheck});

  void _handleOnCheck() {
    HapticFeedback.heavyImpact();
    onCheck();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleOnCheck,
      child: Center(
        child: FaIcon(
          setDto.checked ? FontAwesomeIcons.solidSquareCheck : FontAwesomeIcons.solidSquareCheck,
          color: setDto.checked ? Theme.of(context).colors.vibrantAccent : Theme.of(context).colors.sapphireDark,
          size: 30,
        ),
      ),
    );
  }
}
