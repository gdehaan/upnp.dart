import "dart:async";

import 'package:args/args.dart';

import "package:upnp/upnp.dart";
import "package:upnp/src/utils.dart";

Future printDevice(Device device) async {
  void prelude() {
    print("- ${device.modelName} by ${device.manufacturer} (uuid: ${device.uuid})");
    print("- URL: ${device.url}");
  }

  if (device.services == null) {
    prelude();
    print("-----");
    return;
  }

  var svcs = <Service?>[];

  for (var svc in device.services) {
    if (svc == null) {
      continue;
    }

    var service = await svc.getService();
    svcs.add(service);
  }

  prelude();

  for (var service in svcs) {
    if (service != null) {
      print("  - Type: ${service.type}");
      print("  - ID: ${service.id}");
      print("  - Control URL: ${service.controlUrl}");

      if (service.actions.isNotEmpty) {
        print("  - Actions:");
      }

      for (var action in service.actions) {
        print("    - Name: ${action.name}");
        print("    - Arguments: ${action.arguments
          .where((it) => it.direction == "in")
          .map((it) => it.name)
          .toList()}");
        print("    - Results: ${action.arguments
          .where((it) => it.direction == "out")
          .map((it) => it.name)
          .toList()}");

        print("");
      }

      if (service.stateVariables.isNotEmpty) {
        print("  - State Variables:");
      } else {
        print("");
      }

      for (var variable in service.stateVariables) {
        print("    - Name: ${variable.name}");
        print("    - Data Type: ${variable.dataType}");
        if (variable.defaultValue != null) {
          print("    - Default Value: ${variable.defaultValue}");
        }

        print("");
      }

      if (service.actions.isEmpty) {
        print("");
      }
    }
  }

  print("-----");
}

main(List<String> args) async {
  var parser = ArgParser();
  parser.addOption('port', abbr: 'p', defaultsTo: '0',
    help: 'port number to listen on, default is 0, override to 1900 on strict networks'
  );
  parser.addOption('timeout', abbr: 't', defaultsTo: '5',
    help: 'time to wait for UPnP UDP replies'
  );
  var results = parser.parse(args);
  var rest = results.rest;
  
  var discoverer = new DeviceDiscoverer();
  await discoverer.start(ipv6: false, port: int.parse(results['port']));
  await discoverer
    .quickDiscoverClients(timeout: Duration(seconds: int.parse(results['timeout'])))
    .listen((DiscoveredClient client) async {
    Device? device;

    try {
      device = await client.getDevice();
    } catch (e) {
      assert(() {
        print(e);
        return true;
      }());
    }

    if (device == null || (rest.isNotEmpty && !rest.contains(device.uuid))) {
      return;
    }

    if (device != null) {
      await printDevice(device);
    }
  }).asFuture();

  UpnpCommon.httpClient.close();
}
