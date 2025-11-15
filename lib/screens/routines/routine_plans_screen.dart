import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../utils/general_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/empty_states/no_list_empty_state.dart';
import '../../widgets/routine/preview/routine_plan_grid_item.dart';

class RoutinePlansScreen extends StatefulWidget {
  static const routeName = '/routine_plans_screen';

  const RoutinePlansScreen({super.key});

  @override
  State<RoutinePlansScreen> createState() => _RoutinePlansScreenState();
}

class _RoutinePlansScreenState extends State<RoutinePlansScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    return Consumer<SupabaseExerciseAndRoutineController>(
        builder: (_, provider, __) {
      final plans = List<RoutinePlanDto>.from(provider.plans);

      final children = [
        ...plans.map((plan) => RoutinePlanGridItemWidget(plan: plan))
      ];

      return Scaffold(
          appBar: AppBar(
            backgroundColor: appBarBackgroundColor(context: context),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
              onPressed: context.pop,
            ),
            actions: [
              IconButton(
                  onPressed: _showMenuBottomSheet,
                  icon:
                      const FaIcon(FontAwesomeIcons.solidSquarePlus, size: 28))
            ],
          ),
          body: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: themeGradient(context: context),
            ),
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 10, right: 10, left: 10),
              bottom: false,
              child: Column(
                  spacing: 16,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plans nudge moved to the plan screen
                    children.isNotEmpty
                        ? Expanded(
                            child: GridView.count(
                                crossAxisCount: 2,
                                childAspectRatio: 1,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                children: children),
                          )
                        : Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: const NoListEmptyState(
                                  message:
                                      "It might feel quiet now, but tap the + button to create a plan or ask trainware coach for help."),
                            ),
                          ),
                  ]),
            ),
          ));
    });
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showMenuBottomSheet() {
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const FaIcon(
                    FontAwesomeIcons.plus,
                    size: 18,
                  ),
                  horizontalTitleGap: 6,
                  title: Text("Create new workout plan",
                      style: Theme.of(context).textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToRoutinePlanEditor(context: context);
                  },
                ),
              ]),
        ));
  }
}
