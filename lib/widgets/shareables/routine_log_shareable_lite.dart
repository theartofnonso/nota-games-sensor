import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/extensions/duration_extension.dart';

import '../../colors.dart';
import '../../enums/muscle_group_enums.dart';
import '../../utils/string_utils.dart';

GlobalKey routineLogGlobalKey = GlobalKey();

class RoutineLogShareableLite extends StatelessWidget {
  final RoutineLogDto log;
  final Map<MuscleGroup, double> frequencyData;
  final int pbs;
  final Image? image;

  const RoutineLogShareableLite({super.key, required this.log, required this.frequencyData, this.pbs = 0, this.image});

  @override
  Widget build(BuildContext context) {
    final imageFile = image;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: RepaintBoundary(
          key: routineLogGlobalKey,
          child: Container(
            decoration: BoxDecoration(
              image: imageFile != null
                  ? DecorationImage(
                      image: imageFile.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : null,
              gradient: imageFile == null
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        sapphireDark80,
                        sapphireDark,
                      ],
                    )
                  : null,
            ),
            child: Stack(alignment: Alignment.center, children: [
              if (imageFile != null)
                Positioned.fill(
                    child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      sapphireDark.withValues(alpha: 0.4),
                      sapphireDark,
                    ],
                  )),
                )),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(log.name,
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
                        subtitle: _DateDurationPBWidget(dateTime: log.createdAt, duration: log.duration(), pbs: pbs),
                      ),
                      RichText(
                          text: TextSpan(
                              text:
                                  "${log.exerciseLogs.length} ${pluralize(word: "Exercise", count: log.exerciseLogs.length)}",
                              style: TextStyle(fontWeight: FontWeight.w500),
                              children: [
                            const TextSpan(text: " "),
                            TextSpan(
                                text:
                                    "x${log.exerciseLogs.fold(0, (sum, e) => sum + e.sets.length)} ${pluralize(word: "Set", count: log.exerciseLogs.fold(0, (sum, e) => sum + e.sets.length))}",
                                style: TextStyle(
                                    fontWeight: FontWeight.w500, color: Colors.white70, fontSize: 12)),
                          ])),
                    ]),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0, bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Image.asset(
                        'images/framer_logo.png',
                        fit: BoxFit.cover,
                        height: 30, // Adjust the height as needed
                      )
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DateDurationPBWidget extends StatelessWidget {
  final DateTime dateTime;
  final Duration duration;
  final int pbs;

  const _DateDurationPBWidget({
    required this.dateTime,
    required this.duration,
    required this.pbs,
  });

  @override
  Widget build(BuildContext context) {
    final datetimeSummary = dateTime.formattedDayAndMonth();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.calendarDay,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(datetimeSummary,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w500, fontSize: 12)),
          ],
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.solidClock,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(duration.hmsAnalog(),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w500, fontSize: 12)),
          ],
        ),
        const SizedBox(width: 10),
        pbs > 0
            ? Row(children: [
                const FaIcon(FontAwesomeIcons.solidStar, color: vibrantGreen, size: 14),
                const SizedBox(width: 6),
                Text("$pbs", style: TextStyle(fontSize: 12, color: Colors.white))
              ])
            : const SizedBox.shrink(),
      ],
    );
  }
}
