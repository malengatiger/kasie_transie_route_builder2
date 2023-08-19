import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/color_and_locale.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/isolates/country_cities_isolate.dart';
import 'package:kasie_transie_library/isolates/routes_isolate.dart';
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/maps/city_creator_map.dart';
import 'package:kasie_transie_library/maps/landmark_creator_map.dart';
import 'package:kasie_transie_library/maps/route_creator_map2.dart';
import 'package:kasie_transie_library/maps/route_map_viewer.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/providers/kasie_providers.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/utils/route_distance_calculator.dart';
import 'package:kasie_transie_library/widgets/auth/cell_auth_signin.dart';
import 'package:kasie_transie_library/widgets/dash_widgets/generic.dart';
import 'package:kasie_transie_library/widgets/language_and_color_chooser.dart';
import 'package:kasie_transie_library/widgets/route_info_widget.dart';
import 'package:kasie_transie_library/widgets/tiny_bloc.dart';
import 'package:kasie_transie_route_builder2/ui/route_editor.dart';
import 'package:kasie_transie_route_builder2/ui/route_list.dart';
import 'package:responsive_builder/responsive_builder.dart';

import 'assoc_routes.dart';

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => DashboardState();
}

class DashboardState extends ConsumerState<Dashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const mm = '😡😡😡😡Ambassador Dashboard: 💪 ';

  lib.User? user;
  var cars = <lib.Vehicle>[];
  var routes = <lib.Route>[];
  var routeLandmarks = <lib.RouteLandmark>[];
  var dispatchRecords = <lib.DispatchRecord>[];
  bool busy = false;
  late ColorAndLocale colorAndLocale;
  bool authed = false;
  var totalPassengers = 0;
  late StreamSubscription<lib.RouteUpdateRequest> _routeUpdateSubscription;

  bool _showVerifier = false;
  bool _showDashboard = false;
  int routePointsTotal = 0;
  String? dispatchWithScan,
      manualDispatch,
      routePointsText,
      routesText = 'Routes',
      landmarksText,
      days,
      citiesText = 'Cities',
      passengerCount,
      dispatchesText,
      passengers,
      workWithRoutes,
      ambassadorText;
  String notRegistered =
      'You are not registered yet. Please call your administrator';
  String emailNotFound = 'emailNotFound';
  String welcome = 'Welcome';
  String firstTime =
      'This is the first time that you have opened the app and you '
      'need to sign in to your Taxi Association.';

  String changeLanguage = 'Change Language or Color';
  String startEmailLinkSignin = 'Start Email Link Sign In';
  String signInWithPhone = 'Start Phone Sign In';

  Future _setTexts() async {
    colorAndLocale = await prefs.getColorAndLocale();
    final loc = colorAndLocale.locale;

    routePointsText = await translator.translate('routePoints', loc);

    routesText = await translator.translate('taxiRoutes', loc);
    landmarksText = await translator.translate('landmarks', loc);

    workWithRoutes = await translator.translate('workWithRoutes', loc);
    notRegistered = await translator.translate('notRegistered', loc);
    firstTime = await translator.translate('firstTime', loc);
    changeLanguage = await translator.translate('changeLanguage', loc);
    welcome = await translator.translate('welcome', loc);
    signInWithPhone = await translator.translate('signInWithPhone', loc);
    citiesText = await translator.translate('cities', loc);

    setState(() {});
  }

  lib.Association? association;
  int daysForData = 1;
  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _listen();
    _setTexts();
    _control();
  }

  void _control() async {
    user = await prefs.getUser();
    association = await prefs.getAssociation();
    if (user == null) {
      setState(() {
        _showVerifier = true;
        _showDashboard = false;
      });
      return;
    }
    setState(() {
      _showVerifier = false;
      _showDashboard = true;
    });
    fcmBloc.subscribeForRouteBuilder('RouteBuilder');
    _getData(false);
  }

  void _listen() async {
    _routeUpdateSubscription = fcmBloc.routeUpdateRequestStream.listen((event) {
      pp('$mm fcmBloc.routeUpdateRequestStream delivered: ${event.routeName}');
      _noteRouteUpdate(event);
    });
  }

  void _noteRouteUpdate(lib.RouteUpdateRequest request) async {
    pp('$mm route update started in isolate for ${request.routeName} ...  ');
    if (mounted) {
      showSnackBar(
          duration: const Duration(seconds: 10),
          message: 'Route ${request.routeName} has been refreshed! Thanks',
          context: context);
    }
  }

  int citiesTotal = 0;

  Future _getData(bool refresh) async {
    pp('$mm ................... get data for ambassador dashboard ...');
    user = await prefs.getUser();
    setState(() {
      busy = true;
    });
    try {
      if (user != null) {
        await _getRoutes(refresh);
        await _getLandmarks(refresh);
        await _countRoutePoints();
        citiesTotal =
            await listApiDog.countCountryCities(user!.countryId!, false);
      }
    } catch (e) {
      pp(e);
      if (mounted) {
        showSnackBar(
            padding: 16, message: 'Error getting data', context: context);
      }
      ;
    }
    //
    if (mounted) {
      setState(() {
        busy = false;
      });
    }
  }

  Future _getRoutes(bool refresh) async {
    pp('$mm ... ambassador dashboard; getting routes: ${routes.length} ...');

    routes = await listApiDog
        .getRoutes(AssociationParameter(user!.associationId!, refresh));
    if (refresh) {
      routesIsolate.getRoutes(user!.associationId!);
    }
    pp('$mm ... ambassador dashboard; routes: ${routes.length} ...');
  }

  Future _getLandmarks(bool refresh) async {
    routeLandmarks = await listApiDog.getAssociationRouteLandmarks(
        user!.associationId!, false);
    pp('$mm ... ambassador dashboard; routeLandmarks: ${routeLandmarks.length} ...');
  }

  Future _countRoutePoints() async {
    routePointsTotal = await listApiDog.countAssociationRoutePoints();
    pp('$mm ... ambassador dashboard; routePointsTotal: $routePointsTotal ...');
  }

  bool popDetails = false;
  lib.Route? route;
  void popupDetails(lib.Route route) {
    this.route = route;
    setState(() {
      popDetails = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _routeUpdateSubscription.cancel();
    super.dispose();
  }

  Future _navigateToColor() async {
    pp('$mm _navigateToColor ......');
    await navigateWithScale(LanguageAndColorChooser(
      onLanguageChosen: () {
        _setTexts();
      },
    ), context);
    colorAndLocale = await prefs.getColorAndLocale();
    await _setTexts();
  }

  int routeLandmarksTotal = 0;
  int routesTotal = 0;
  bool sendingRouteUpdateMessage = false;

  void onSendRouteUpdateMessage(lib.Route route) async {
    pp("$mm onSendRouteUpdateMessage .........");
    tinyBloc.setRouteId(route.routeId!);
    prefs.saveRoute(route);

    setState(() {
      sendingRouteUpdateMessage = true;
    });
    try {
      await dataApiDog.sendRouteUpdateMessage(
          route.associationId!, route.routeId!);
      pp('$mm onSendRouteUpdateMessage happened OK! ${E.nice}');
    } catch (e) {
      pp(e);
      showToast(
          duration: const Duration(seconds: 5),
          padding: 20,
          textStyle: myTextStyleMedium(context),
          backgroundColor: Colors.amber,
          message: 'Route Update message sent OK',
          context: context);
    }
    setState(() {
      sendingRouteUpdateMessage = false;
    });
  }

  void calculateDistances(lib.Route route) async {
    tinyBloc.setRouteId(route.routeId!);
    prefs.saveRoute(route);

    routeDistanceCalculator.calculateRouteDistances(
        route.routeId!, route.associationId!);
  }

  lib.Route? selectedRoute;
  String? selectedRouteId;

  void navigateToLandmarks(lib.Route route) async {
    pp('$mm navigateToLandmarksEditor .....  route: ${route.name}');
    tinyBloc.setRouteId(route.routeId!);
    prefs.saveRoute(route);
    setState(() {
      selectedRoute = route;
      selectedRouteId = route.routeId;
    });
    pp('$mm Future.delayed(const Duration(seconds: 2) .....  ');

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      navigateWithScale(
          LandmarkCreatorMap(
            route: route,
          ),
          context);
    }
  }

  void navigateToMapViewer(lib.Route route) async {
    pp('$mm navigateToMapViewer .....  route: ${route.name}');
    tinyBloc.setRouteId(route.routeId!);
    prefs.saveRoute(route);

    setState(() {
      selectedRoute = route;
      selectedRouteId = route.routeId;
    });
    pp('$mm Future.delayed(const Duration(seconds: 2) .....  ');

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      //route = await listApiDog.
      navigateWithScale(
          RouteMapViewer(
            routeId: route.routeId!,
            onRouteUpdated: () {
              pp('\n\n$mm onRouteUpdated ... do something Boss!');
              // _refresh(true);
            },
          ),
          context);
    }
  }

  void navigateToCreatorMap(lib.Route route) async {
    pp('$mm navigateToCreatorMap .....  route: ${route.name}');
    tinyBloc.setRouteId(route.routeId!);
    prefs.saveRoute(route);
    setState(() {
      selectedRoute = route;
      selectedRouteId = route.routeId;
    });
    pp('$mm Future.delayed(const Duration(seconds: 2) .....  ');

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      navigateWithScale(
          RouteCreatorMap2(
            route: route,
          ),
          context);
    }
  }

  void navigateToAssocMaps() {
    navigateWithScale(
        AssociationRoutes(AssociationParameter(user!.associationId!, false),
            user!.associationName!),
        context);
  }

  void navigateToRoutes() {
    pp('$mm ............... navigateToRoutes');
    final w = AssociationRoutes(
        AssociationParameter(user!.associationId!, false),
        user!.associationName!);
    navigateWithScale(w, context);
  }

  void _navigateToCityCreator() {
    navigateWithScale(const CityCreatorMap(), context);
  }

  @override
  Widget build(BuildContext context) {
    final type = getThisDeviceType();
    var padding = 16.0;
    var fontSize = 32.0;
    var centerTitle = true;
    if (type == 'phone') {
      padding = 12.0;
      fontSize = 16;
      centerTitle = false;
    }
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          leading: const SizedBox(),
          centerTitle: centerTitle,
          title: Text(
            routesText == null ? 'Routes' : routesText!,
            style: myTextStyleMediumLargeWithColor(
                context, Theme.of(context).primaryColor, fontSize),
          ),
          actions: [
            _showDashboard
                ? IconButton(
                onPressed: () {
                  _navigateToCityCreator();
                },
                icon: Icon(
                  Icons.edit,
                  color: Theme.of(context).primaryColor,
                ))
                : const SizedBox(),
            _showDashboard
                ? IconButton(
                    onPressed: () {
                      _navigateToColor();
                    },
                    icon: Icon(
                      Icons.color_lens,
                      color: Theme.of(context).primaryColor,
                    ))
                : const SizedBox(),
            _showDashboard
                ? IconButton(
                    onPressed: () {
                      _getData(true);
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: Theme.of(context).primaryColor,
                    ))
                : const SizedBox(),
            _showDashboard
                ? IconButton(
                    onPressed: () {
                      navigateToRoutes();
                    },
                    icon: Icon(
                      Icons.route,
                      color: Theme.of(context).primaryColor,
                    ))
                : const SizedBox(),
          ],
        ),
        body: Stack(
          children: [
            ScreenTypeLayout.builder(
              mobile: (ctx) {
                return Stack(
                  children: [
                    _showDashboard
                        ? DashContent(
                            user: user!,
                            routesText: routesText!,
                            workWithRoutes: workWithRoutes!,
                            landmarksText: landmarksText!,
                            routePointsText: routePointsText!,
                            routePointsTotal: routePointsTotal,
                            routeLandmarksTotal: routeLandmarks.length,
                            routesTotal: routes.length,
                            heightPadding: 52,
                            crossAxisCount: 2,
                            onNavigateToRoutes: () {
                              navigateToRoutes();
                            },
                            citiesText: citiesText!,
                            citiesTotal: citiesTotal,
                          )
                        : const SizedBox(),
                    _showVerifier
                        ? CustomPhoneVerification(
                            onUserAuthenticated: (u) {
                              setState(() {
                                user = u;
                                _showVerifier = false;
                                _showDashboard = true;
                              });
                              _getData(true);
                            },
                            onError: () {},
                            onCancel: () {},
                            onLanguageChosen: () {
                              _setTexts();
                            },
                          )
                        : const SizedBox(),
                  ],
                );
              },
              tablet: (ctx) {
                return OrientationLayoutBuilder(landscape: (ctx) {
                  final width = MediaQuery.of(context).size.width;
                  return _showDashboard
                      ? Row(
                          children: [
                            SizedBox(
                              width: (width / 2) + 60,
                              child: DashContent(
                                  user: user!,
                                  routesText: routesText!,
                                  workWithRoutes: workWithRoutes!,
                                  landmarksText: landmarksText!,
                                  routePointsText: routePointsText!,
                                  routePointsTotal: routePointsTotal,
                                  routeLandmarksTotal: routeLandmarks.length,
                                  routesTotal: routes.length,
                                  crossAxisCount: 3,
                                  heightPadding: 60,
                                  citiesText: citiesText!,
                                  citiesTotal: citiesTotal,
                                  onNavigateToRoutes: () {
                                    navigateToRoutes();
                                  }),
                            ),
                            SizedBox(
                              width: (width / 2) - 60,
                              child: RouteList(
                                navigateToMapViewer: (r) {
                                  navigateToMapViewer(r);
                                },
                                navigateToLandmarks: (r) {
                                  navigateToLandmarks(r);
                                },
                                navigateToCreatorMap: (r) {
                                  navigateToCreatorMap(r);
                                },
                                routes: routes,
                                onSendRouteUpdateMessage: (r) {
                                  onSendRouteUpdateMessage(r);
                                },
                                onCalculateDistances: (r) {
                                  calculateDistances(r);
                                },
                                showRouteDetails: (r) {
                                  popupDetails(r);
                                },
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: SizedBox(
                            width: 600,
                            height: 600,
                            child: CustomPhoneVerification(
                              onUserAuthenticated: (u) {
                                setState(() {
                                  user = u;
                                  _showVerifier = false;
                                  _showDashboard = true;
                                });
                                _getData(false);
                              },
                              onError: () {},
                              onCancel: () {},
                              onLanguageChosen: () {
                                _setTexts();
                              },
                            ),
                          ),
                        );
                }, portrait: (ctx) {
                  final width = MediaQuery.of(context).size.width;
                  return _showDashboard
                      ? Row(
                          children: [
                            SizedBox(
                              width: (width / 2) + 40,
                              child: DashContent(
                                  user: user!,
                                  routesText: routesText!,
                                  workWithRoutes: workWithRoutes!,
                                  landmarksText: landmarksText!,
                                  routePointsText: routePointsText!,
                                  routePointsTotal: routePointsTotal,
                                  routeLandmarksTotal: routeLandmarks.length,
                                  routesTotal: routes.length,
                                  crossAxisCount: 2,
                                  citiesText: citiesText!,
                                  citiesTotal: citiesTotal,
                                  heightPadding: 60,
                                  onNavigateToRoutes: () {
                                    navigateToRoutes();
                                  }),
                            ),
                            SizedBox(
                              width: (width / 2) - 40,
                              child: RouteList(
                                navigateToMapViewer: (r) {
                                  navigateToMapViewer(r);
                                },
                                navigateToLandmarks: (r) {
                                  navigateToLandmarks(r);
                                },
                                navigateToCreatorMap: (r) {
                                  navigateToCreatorMap(r);
                                },
                                routes: routes,
                                onSendRouteUpdateMessage: (r) {
                                  onSendRouteUpdateMessage(r);
                                },
                                onCalculateDistances: (r) {
                                  calculateDistances(r);
                                },
                                showRouteDetails: (r) {
                                  popupDetails(r);
                                },
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: SizedBox(
                            width: 600,
                            height: 600,
                            child: CustomPhoneVerification(
                              onUserAuthenticated: (u) {
                                setState(() {
                                  user = u;
                                  _showVerifier = false;
                                  _showDashboard = true;
                                });
                                _getData(false);
                              },
                              onError: () {},
                              onCancel: () {},
                              onLanguageChosen: () {
                                _setTexts();
                              },
                            ),
                          ),
                        );
                });
              },
            ),
            popDetails
                ? Positioned(
                    top: 0,
                    bottom: 0,
                    left: padding,
                    right: padding,
                    child: RouteInfoWidget(
                      routeId: route!.routeId,
                      onClose: () {
                        setState(() {
                          popDetails = false;
                        });
                      },
                      onNavigateToMapViewer: () {
                        navigateToMapViewer(route!);
                      },
                    ))
                : const SizedBox(),
          ],
        ),
        drawer: SizedBox(
          width: 400,
          child: Drawer(
            child: Card(
              elevation: 8,
              child: ListView(
                children: [
                  DrawerHeader(
                      decoration: const BoxDecoration(
                          color: Colors.black12,
                          image: DecorationImage(
                              image: AssetImage('assets/gio.png'),
                              scale: 0.1,
                              opacity: 0.1)),
                      child: SizedBox(
                          height: 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(routesText!,
                                  style: myTextStyleMediumLargeWithColor(
                                      context, Colors.grey, 32)),
                              const SizedBox(
                                height: 48,
                              )
                            ],
                          ))),
                  const SizedBox(
                    height: 64,
                  ),
                  ListTile(
                    title: const Text('Add Place/Town/City'),
                    leading: Icon(
                      Icons.account_balance,
                      color: Theme.of(context).primaryColor,
                    ),
                    subtitle: Text(
                        'Create a new place that wil be used in your routes',
                        style: myTextStyleSmall(context)),
                    onTap: () {
                      pp('$mm navigate to city creator map .......');
                      navigateWithFade(const CityCreatorMap(), context);
                    },
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  ListTile(
                    title: const Text('Add New Route'),
                    leading: Icon(Icons.directions_bus,
                        color: Theme.of(context).primaryColor),
                    subtitle: Text('Create a new route',
                        style: myTextStyleSmall(context)),
                    onTap: () {
                      if (association != null) {
                      navigateWithScale(
                          RouteEditor(dataApiDog: dataApiDog, prefs: prefs, association: association!,),
                          context);
                      }
                    },
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  ListTile(
                    title: const Text('Calculate Route Distances'),
                    leading: Icon(Icons.calculate,
                        color: Theme.of(context).primaryColor),
                    subtitle: Text(
                      'Calculate distances between landmarks in the route',
                      style: myTextStyleSmall(context),
                    ),
                    onTap: () {
                      pp('$mm starting distance calculation ...');
                      routeDistanceCalculator
                          .calculateAssociationRouteDistances();
                    },
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  ListTile(
                    title: const Text('Refresh Route Data'),
                    leading: Icon(Icons.refresh,
                        color: Theme.of(context).primaryColor),
                    subtitle: Text(
                      'Fetch refreshed route data from the Mother Ship',
                      style: myTextStyleSmall(context),
                    ),
                    onTap: () {
                      _getData(true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashContent extends StatelessWidget {
  const DashContent(
      {Key? key,
      required this.user,
      required this.routesText,
      required this.workWithRoutes,
      required this.landmarksText,
      required this.routePointsText,
      required this.routePointsTotal,
      required this.routeLandmarksTotal,
      required this.routesTotal,
      required this.onNavigateToRoutes,
      this.height,
      required this.crossAxisCount,
      required this.heightPadding,
      required this.citiesText,
      required this.citiesTotal})
      : super(key: key);

  final lib.User user;
  final String routesText,
      workWithRoutes,
      landmarksText,
      routePointsText,
      citiesText;
  final int routePointsTotal, routeLandmarksTotal, routesTotal, citiesTotal;
  final Function onNavigateToRoutes;
  final double? height;
  final int crossAxisCount;
  final double heightPadding;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        shape: getRoundedBorder(radius: 16),
        elevation: 4,
        child: SizedBox(
          height: height == null ? 800 : height!,
          child: Column(
            children: [
              SizedBox(
                height: heightPadding,
              ),
              Text(
                user.associationName!,
                style: myTextStyleMediumLargeWithColor(
                    context, Theme.of(context).primaryColor, 18),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                user.name,
                style: myTextStyleSmall(context),
              ),
              SizedBox(
                height: heightPadding,
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                    width: 400,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.roundabout_left),
                      style: ButtonStyle(
                          elevation: const MaterialStatePropertyAll(8.0),
                          shape: MaterialStatePropertyAll(
                              getRoundedBorder(radius: 16))),
                      onPressed: () {
                        onNavigateToRoutes();
                      },
                      label: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(workWithRoutes),
                      ),
                    )),
              ),
              SizedBox(
                height: heightPadding,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 600,
                    child: GridView(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        crossAxisCount: crossAxisCount,
                      ),
                      children: [
                        TotalWidget(
                            caption: routesText,
                            number: routesTotal,
                            color: Theme.of(context).primaryColor,
                            fontSize: 28,
                            onTapped: () {}),
                        TotalWidget(
                            caption: landmarksText,
                            number: routeLandmarksTotal,
                            color: Theme.of(context).primaryColor,
                            fontSize: 28,
                            onTapped: () {}),
                        TotalWidget(
                            caption: routePointsText,
                            number: routePointsTotal,
                            color: Colors.grey.shade600,
                            fontSize: 28,
                            onTapped: () {}),
                        TotalWidget(
                            caption: citiesText,
                            number: citiesTotal,
                            color: Colors.grey.shade600,
                            fontSize: 28,
                            onTapped: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
