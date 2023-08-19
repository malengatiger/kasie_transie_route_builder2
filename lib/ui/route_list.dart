import 'package:flutter/material.dart';
import 'package:focused_menu/focused_menu.dart';
import 'package:focused_menu/modals.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:badges/badges.dart' as bd;

class RouteList extends StatelessWidget {
  const RouteList(
      {Key? key,
        required this.navigateToMapViewer,
        required this.navigateToLandmarks,
        required this.navigateToCreatorMap,
        required this.routes,
        this.currentRoute,
        required this.onSendRouteUpdateMessage,
        required this.onCalculateDistances, required this.showRouteDetails})
      : super(key: key);

  final Function(lib.Route) navigateToMapViewer;
  final Function(lib.Route) navigateToLandmarks;
  final Function(lib.Route) navigateToCreatorMap;
  final Function(lib.Route) onSendRouteUpdateMessage;
  final Function(lib.Route) onCalculateDistances;
  final Function(lib.Route) showRouteDetails;

  final List<lib.Route> routes;
  final lib.Route? currentRoute;

  List<FocusedMenuItem> _getMenuItems(lib.Route route, BuildContext context) {
    List<FocusedMenuItem> list = [];

    list.add(FocusedMenuItem(
        title: Text('Display Route Details', style: myTextStyleMediumBlack(context)),
        // backgroundColor: Theme.of(context).primaryColor,
        trailingIcon: Icon(
          Icons.map,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          showRouteDetails(route);
        }));
    //
    list.add(FocusedMenuItem(
        title: Text('View Route Map', style: myTextStyleMediumBlack(context)),
        // backgroundColor: Theme.of(context).primaryColor,
        trailingIcon: Icon(
          Icons.map,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          navigateToMapViewer(route);
        }));
    //
    list.add(FocusedMenuItem(
        title: Text('Route Landmarks', style: myTextStyleMediumBlack(context)),
        trailingIcon: Icon(
          Icons.water_damage_outlined,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          navigateToLandmarks(route);
        }));
    //
    list.add(FocusedMenuItem(
        title: Text('Update Route', style: myTextStyleMediumBlack(context)),
        // backgroundColor: Theme.of(context).primaryColor,
        trailingIcon: Icon(
          Icons.edit,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          navigateToCreatorMap(route);
        }));

    list.add(FocusedMenuItem(
        title: Text('Calculate Route Distances',
            style: myTextStyleMediumBlack(context)),
        // backgroundColor: Theme.of(context).primaryColor,
        trailingIcon: Icon(
          Icons.calculate,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          onCalculateDistances(route);
        }));
    list.add(FocusedMenuItem(
        title: Text('Send Route Update Message',
            style: myTextStyleMediumBlack(context)),
        // backgroundColor: Theme.of(context).primaryColor,
        trailingIcon: Icon(
          Icons.send,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          onSendRouteUpdateMessage(route);
        }));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Card(
        elevation: 2,
        shape: getRoundedBorder(radius: 16),
        child: Column(
          children: [
            const SizedBox(height: 64,),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: bd.Badge(
                  position: bd.BadgePosition.topEnd(end: 12, top: -20),
                  badgeContent: Text('${routes.length}'),
                  badgeStyle: const bd.BadgeStyle(padding: EdgeInsets.all(16)),
                  child: ListView.builder(
                      itemCount: routes.length,
                      itemBuilder: (ctx, index) {
                        var elevation = 6.0;
                        final rt = routes.elementAt(index);

                        return FocusedMenuHolder(
                          menuOffset: 24,
                          duration: const Duration(milliseconds: 300),
                          menuItems: _getMenuItems(rt, context),
                          animateMenuItems: true,
                          openWithTap: true,
                          onPressed: () {
                            pp('💛️️ tapped FocusedMenuHolder ...');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 1.0),
                            child: Card(
                              shape: getRoundedBorder(radius: 16),
                              elevation: elevation,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('${rt.name}', style: myTextStyleSmall(context),),
                              ),
                            ),
                          ),
                        );
                      }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
