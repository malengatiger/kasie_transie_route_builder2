import 'package:flutter/material.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/providers/kasie_providers.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/initializer.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;

import '../intro/kasie_intro.dart';
import 'assoc_routes.dart';

class LandingPage extends StatefulWidget {
  const LandingPage(
      {Key? key,
      required this.listApiDog,
      required this.dataApiDog,
      required this.prefs})
      : super(key: key);

  final ListApiDog listApiDog;
  final DataApiDog dataApiDog;
  final Prefs prefs;
  @override
  LandingPageState createState() => LandingPageState();
}
class LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const mm = '🥬🥬🥬🥬🥬🥬 LandingPage  🔵🔵';
  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _initialize();
  }

  void _initialize() async {
    pp('$mm ..... check settings and fix if needed!');
    final user = await prefs.getUser();
    if (user != null) {
      var sett = await prefs.getSettings();
      if (sett == null) {
        final settList = await listApiDog.getSettings(user.associationId!, false);
        if (settList.isNotEmpty) {
          sett = settList.first;
          await prefs.saveSettings(sett);
        }
        pp('$mm ..... settings fixed!');
      }
    }
    initializer.initialize();
  }

  onRouteSelected(lib.Route p1) {
    pp('$mm onRouteSelected .... ${p1.name}');
  }

  onSuccessfulSignIn(lib.User p1) {
    pp('$mm onSuccessfulSignIn .... ${p1.name} - navigating to RouteList ...');

    navigateWithScale(
         AssociationRoutes(AssociationParameter(p1.associationId!, true), p1.associationName!),
        context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(),
      body: ScreenTypeLayout.builder(
        mobile: (ctx) {
          return KasieIntro(
            dataApiDog: widget.dataApiDog,
          );
        },
      ),
    ));
  }
}
