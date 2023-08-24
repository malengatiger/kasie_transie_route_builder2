import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/color_and_locale.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/isolates/routes_isolate.dart';
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/maps/association_route_maps.dart';
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
import 'package:kasie_transie_library/widgets/route_info_widget.dart';
import 'package:kasie_transie_library/widgets/tiny_bloc.dart';
import 'package:kasie_transie_route_builder2/ui/route_editor.dart';
import 'package:kasie_transie_route_builder2/ui/route_list.dart';
import 'package:responsive_builder/responsive_builder.dart';

class AssociationRoutes extends ConsumerStatefulWidget {
  final AssociationParameter parameter;
  final String associationName;

  const AssociationRoutes(
    this.parameter,
    this.associationName, {
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<AssociationRoutes> createState() => AssociationRoutesState();
}

class AssociationRoutesState extends ConsumerState<AssociationRoutes> {
  final mm = '🔆🔆🔆🔆🔆 AssociationRoutes 🔵🔵 ';
  bool busy = false;
  var routes = <lib.Route>[];
  late StreamSubscription<List<lib.Route>> _sub;
  lib.User? user;
  final StreamController<String> _streamController =
      StreamController.broadcast();

  Stream<String> get routeIdStream => _streamController.stream;
  late StreamSubscription<String> routeChangesSub;

  @override
  void initState() {
    super.initState();
    _listen();
    _setTexts();
    _getInitialData(false);
    initialize();
  }

  String? routeId;
  lib.Association? association;
  late ColorAndLocale colorAndLocale;
  Future _setTexts() async {
    colorAndLocale = await prefs.getColorAndLocale();
    final loc = colorAndLocale.locale;

    routesText = await translator.translate('routes', loc);
  }

  Future<void> initialize() async {
    fcmBloc.subscribeForRouteBuilder('RouteBuilder');
  }

  void _listen() {
    _sub = listApiDog.routeStream.listen((routesFromStream) {
      pp('$mm ... listApiDog.routeStream delivered: ${routesFromStream.length}');
      routes = routesFromStream;
      if (mounted) {
        setState(() {});
      }
    });
    routeChangesSub = fcmBloc.routeChangesStream.listen((event) {
      pp('$mm routeChangesStream delivered a routeId: $event');
      routeId = event;
      setState(() {});
      if (mounted) {
        showSnackBar(
            message:
                "A Route update has been issued. The download will happen automatically.",
            context: context);
      }
    });
  }

  void _getInitialData(bool refresh) async {
    setState(() {
      busy = true;
    });
    try {
      user = await prefs.getUser();
      association = await prefs.getAssociation();
      selectedRoute = await prefs.getRoute();
      if (selectedRoute != null) {
        selectedRouteId = selectedRoute!.routeId!;
      }
      routes = await listApiDog
          .getRoutes(AssociationParameter(user!.associationId!, refresh));
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  lib.Route? selectedRoute;
  String? selectedRouteId, routesText = 'Routes';

  @override
  void dispose() {
    routeChangesSub.cancel();
    super.dispose();
  }

  void navigateToLandmarks(lib.Route route) async {
    pp('$mm navigateToLandmarksEditor .....  route: ${route.name}');
    tinyBloc.setRouteId(route.routeId!);
    prefs.saveRoute(route);
    setState(() {
      selectedRoute = route;
      selectedRouteId = route.routeId;
    });

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

    if (mounted) {
      //route = await listApiDog.
      navigateWithScale(
          RouteMapViewer(
            routeId: route.routeId!,
            onRouteUpdated: () {
              pp('\n\n$mm onRouteUpdated ... do something Boss!');
              _refresh(true);
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

    if (mounted) {
      navigateWithScale(
          RouteCreatorMap2(
            route: route,
          ),
          context);
    }
  }

  void navigateToAssocMaps() {
    navigateWithScale(const AssociationRouteMaps(), context);
  }

  void navigateToRouteInfo(lib.Route route) {
    navigateWithScale(
        RouteInfoWidget(
            routeId: route.routeId,
            onClose: () {
              Navigator.of(context).pop();
            },
            onNavigateToMapViewer: () {
              navigateToMapViewer(selectedRoute!);
            }, onColorChanged: (color , string ) {
              _sendColorChange(color, string);
        },),
        context);
  }
  
  void _sendColorChange(Color color, stringColor) async {
    pp('$mm ................... send color change to : $stringColor');
    setState(() {
      busy = true;
    });
    try {
      selectedRoute = await dataApiDog.updateRouteColor(routeId: selectedRoute!.routeId!, color: stringColor);
    } catch (e) {
      pp(e);
      if (mounted) {
        showSnackBar(message: 'Colour update failed\n$e', context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  void _navigateToCityCreator() {
    navigateWithScale(const CityCreatorMap(), context);
  }

  void _refresh(bool refresh) async {
    setState(() {
      busy = true;
    });
    user = await prefs.getUser();
    if (user != null) {
    routes = await listApiDog
        .getRoutes(AssociationParameter(user!.associationId!, refresh));
    }

    setState(() {
      busy = false;
    });
  }

  void updateAssociationRouteLandmarks() async {
    pp('$mm updateAssociationRouteLandmarks requested.... ');
    setState(() {
      busy = true;
    });
    await dataApiDog.updateAssociationRouteLandmarks(user!.associationId!);
    setState(() {
      busy = false;
    });
  }

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
      if (mounted) {
        showToast(
                  duration: const Duration(seconds: 5),
                  padding: 20,
                  textStyle: myTextStyleMedium(context),
                  backgroundColor: Colors.amber,
                  message: 'Route Update message sent OK',
                  context: context);
      };
    }
    setState(() {
      sendingRouteUpdateMessage = false;
    });
  }

  void calculateDistances(lib.Route route) async {
    pp('$mm ... calculateDistances for: ${route.name}');

    tinyBloc.setRouteId(route.routeId!);
    prefs.saveRoute(route);
    final type = getThisDeviceType();
    try {
      setState(() {
        busy = true;
      });
      final dist = await routeDistanceCalculator.calculateRouteDistances(
          route.routeId!, route.associationId!);
      pp('$mm ... distances calculated: ${dist.length}, are we mounted? $mounted');
      if (mounted) {
        showToast(
            backgroundColor: Colors.black,
            textStyle: myTextStyleSmallWithColor(context, Colors.white),
            padding: 20.0,
            duration: const Duration(seconds: 2),
            message: 'Distances calculated',
            context: context);
        if (type == 'phone') {
          navigateToRouteInfo(route);
        }
      }
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (user != null) {
      final k = ref.watch(
          routesProvider(AssociationParameter(user!.associationId!, false)));
      if (k.hasValue) {
        routes = k.value!;
      }
    }
    final width = MediaQuery.of(context).size.width;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            routesText!,
            style: myTextStyleLarge(context),
          ),
          bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Column(
                children: [
                  Text(
                    widget.associationName,
                    style: myTextStyleMediumBold(context),
                  ),
                  const SizedBox(
                    height: 16,
                  )
                ],
              )),
          actions: [
            IconButton(
                onPressed: () async {
                  pp('$mm refresh routes from backend .......');
                  selectedRoute = null;
                  _refresh(true);
                },
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context).primaryColor,
                )),
            IconButton(
                onPressed: () async {
                  pp('$mm navigateToAssocMaps .......');
                  navigateToAssocMaps();
                },
                icon: Icon(
                  Icons.map,
                  color: Theme.of(context).primaryColor,
                )),
            IconButton(
                onPressed: () async {
                  _navigateToCityCreator();
                },
                icon: Icon(
                  Icons.edit,
                  color: Theme.of(context).primaryColor,
                )),
            IconButton(
                onPressed: () async {
                  if (mounted) {
                    if (association != null) {
                      navigateWithScale(
                          RouteEditor(
                            dataApiDog: dataApiDog,
                            prefs: prefs,
                            association: association!,
                          ),
                          context);
                    }
                  }
                },
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).primaryColor,
                )),
          ],
        ),
        body: Stack(
          children: [
            StreamBuilder<List<lib.Route>>(
                stream: listApiDog.routeStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    routes = snapshot.data!;
                  }
                  return Stack(children: [
                    routes.isEmpty
                        ? const WaitingForGodot()
                        : ScreenTypeLayout.builder(
                            mobile: (ctx) {
                              return RouteList(
                                navigateToMapViewer: navigateToMapViewer,
                                navigateToLandmarks: navigateToLandmarks,
                                navigateToCreatorMap: navigateToCreatorMap,
                                routes: routes,
                                onSendRouteUpdateMessage: (route) {
                                  onSendRouteUpdateMessage(route);
                                },
                                onCalculateDistances: (r) {
                                  calculateDistances(r);
                                },
                                showRouteDetails: (r) {
                                  setState(() {
                                    selectedRoute = r;
                                  });
                                  navigateToRouteInfo(r);
                                },
                              );
                            },
                            tablet: (ctx) {
                              return OrientationLayoutBuilder(landscape: (ctx) {
                                return Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    SizedBox(
                                      width: (width / 2) - 60,
                                      child: RouteList(
                                        navigateToMapViewer:
                                            navigateToMapViewer,
                                        navigateToLandmarks:
                                            navigateToLandmarks,
                                        navigateToCreatorMap:
                                            navigateToCreatorMap,
                                        routes: routes,
                                        onSendRouteUpdateMessage: (route) {
                                          onSendRouteUpdateMessage(route);
                                        },
                                        onCalculateDistances: (r) {
                                          calculateDistances(r);
                                        },
                                        showRouteDetails: (r) {},
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 32,
                                    ),
                                    SizedBox(
                                      width: (width / 2),
                                      child: RouteInfoWidget(
                                        routeId: selectedRouteId,
                                        onClose: () {},
                                        onColorChanged: (color , string ) {
                                          _sendColorChange(color, string);
                                        },
                                        onNavigateToMapViewer: () {
                                          navigateToMapViewer(selectedRoute!);
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }, portrait: (ctx) {
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: (width / 2) - 24,
                                      child: RouteList(
                                        navigateToMapViewer:
                                            navigateToMapViewer,
                                        navigateToLandmarks:
                                            navigateToLandmarks,
                                        navigateToCreatorMap:
                                            navigateToCreatorMap,
                                        currentRoute: selectedRoute,
                                        routes: routes,
                                        onSendRouteUpdateMessage: (route) {
                                          onSendRouteUpdateMessage(route);
                                        },
                                        onCalculateDistances: (r) {
                                          calculateDistances(r);
                                        },
                                        showRouteDetails: (route) {},
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    SizedBox(
                                      width: (width / 2),
                                      child: RouteInfoWidget(
                                        routeId: selectedRouteId,
                                        onClose: () {},
                                        onNavigateToMapViewer: () {
                                          navigateToMapViewer(selectedRoute!);
                                        }, onColorChanged: (color , string ) { 
                                          _sendColorChange(color, string);
                                      },
                                      ),
                                    ),
                                  ],
                                );
                              });
                            },
                          )
                  ]);
                }),
            busy
                ? const Positioned(
                    child: Center(
                    child: SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 8,
                        backgroundColor: Colors.amber,
                      ),
                    ),
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
                            RouteEditor(
                              dataApiDog: dataApiDog,
                              prefs: prefs,
                              association: association!,
                            ),
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
                      _refresh(true);
                    },
                  ),
                  ListTile(
                    title: const Text('Navigate to Dashboard'),
                    leading: Icon(Icons.dashboard,
                        color: Theme.of(context).primaryColor),
                    subtitle: Text(
                      'View Totals',
                      style: myTextStyleSmall(context),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
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

class WaitingForGodot extends StatelessWidget {
  const WaitingForGodot({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Card(
          elevation: 8,
          shape: getRoundedBorder(radius: 16),
          child: SizedBox(
              height: 160,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 20,
                    ),
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 8,
                        backgroundColor: Colors.teal,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Text(
                      'Finding the Association taxi routes ...',
                      style: myTextStyleSmallWithColor(
                          context, Theme.of(context).primaryColor),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    Text(
                      'Tap the + icon at top right!',
                      style: myTextStyleMedium(context),
                    ),
                  ],
                ),
              )),
        ),
      ),
    );
  }
}
