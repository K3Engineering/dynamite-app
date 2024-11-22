import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:graphic/graphic.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// const BT_DEVICE_UUID = "E4:B0:63:81:5B:19";
const BT_GATT_ID = "a659ee73-460b-45d5-8e63-ab6bf0825942";
const BT_SERVICE_ID = "e331016b-6618-4f8f-8997-1a2c7c9e5fa3";
const BT_CHARACTERISTIC_ID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const BT_S2 = "00001800-0000-1000-8000-00805f9b34fb";
const BT_S3 = "00001801-0000-1000-8000-00805f9b34fb";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BluetoothHandling _bluetoothHandler = BluetoothHandling();
  List<Map<String, int>> adcReadings = [ 
    {'x': 1, 'y': 0},
    {'x': 3, 'y': 1},
    {'x': 3, 'y': 2},
    {'x': 4, 'y': 3},
    {'x': 10, 'y': 4}];

  @override
  void initState() {
    super.initState();

    _bluetoothHandler.initializeBluetooth();

    // Listen to receivedData changes
    _bluetoothHandler.receivedData.addListener(() {
      final value = _bluetoothHandler.receivedData.value;
      if (value != null) {
        processReceivedData(value);
      }
    });
  }

  void processReceivedData(Uint8List value) {
    // Decode 24-bit values into integers
    List<int> intValues = [];
    for (int i = 0; i < value.length; i += 3) {
      if (i + 2 < value.length) {
        int intValue = (value[i + 2] << 16) | (value[i + 1] << 8) | value[i];
        intValues.add(intValue);
      }
    }

    // Update adcReadings and refresh the chart
    setState(() {
      for (int i = 0; i < intValues.length; i++) {
        adcReadings.add({'x': adcReadings.length + 1, 'y': intValues[i]});
      }

      // Optional: Limit the number of points on the chart
      if (adcReadings.length > 1000) {
        adcReadings.removeRange(0, adcReadings.length - 100);
      }
    });
  }

  @override
  void dispose() {
    _bluetoothHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          BluetoothIndicator(bluetoothService: _bluetoothHandler),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh BT Icon',
            onPressed: _bluetoothHandler.toggleScan,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: BluetoothDeviceList(bluetoothService: _bluetoothHandler)),
          Expanded(
            child: Chart(
              data: adcReadings,
              variables: {
                  'Y': Variable(
                    accessor: (Map map) =>
                        (map['y'] ?? double.nan) as int,
                  ),
                  'X': Variable(
                    accessor: (Map map) => map['x'] as int,
                    scale: LinearScale(tickCount: 5),
                  ),
              },
              marks: [
                LineMark(
                  shape: ShapeEncode(value: BasicLineShape()), //dash: [5, 2]
                  selected: {
                    'touchMove': {1}
                  },
                )
              ],
              coord: RectCoord(color: const Color(0xffdddddd)),
              axes: [
                Defaults.horizontalAxis,
                Defaults.verticalAxis,
              ],
              selections: {
                'touchMove': PointSelection(
                  on: {
                    GestureType.scaleUpdate,
                    GestureType.tapDown,
                    GestureType.longPressMoveUpdate
                  },
                  dim: Dim.x,
                )
              },
              tooltip: TooltipGuide(
                followPointer: [false, true],
                align: Alignment.topLeft,
                offset: const Offset(-20, -20),
              ),
              crosshair: CrosshairGuide(followPointer: [false, true]),
              )),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _bluetoothHandler.isScanning,
        builder: (context, isScanning, child) {
          return FloatingActionButton(
            onPressed: _bluetoothHandler.toggleScan,
            tooltip: isScanning ? 'Stop scanning' : 'Start scanning',
            child: Icon(isScanning ? Icons.stop : Icons.search),
          );
        },
      ),
    );
  }
}

// class BluetoothDevice {
//   final BluetoothHandling _bluetoothHanlder = BluetoothHandling();
//   // const BT_DEVICE_UUID = "E4:B0:63:81:5B:19";
//   static const BT_GATT_ID = "a659ee73-460b-45d5-8e63-ab6bf0825942";
//   static const BT_SERVICE_ID = "e331016b-6618-4f8f-8997-1a2c7c9e5fa3";
//   static const BT_CHARACTERISTIC_ID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
//   static const BT_S2 = "00001800-0000-1000-8000-00805f9b34fb";
//   static const BT_S3 = "00001801-0000-1000-8000-00805f9b34fb";

//   void init() {
//     _bluetoothHanlder.initializeBluetooth();
//   }
// }

class BluetoothHandling {
  AvailabilityState bluetoothState = AvailabilityState.unknown;
  ValueNotifier<List<BleDevice>> devices = ValueNotifier<List<BleDevice>>([]);
  ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);
  ValueNotifier<BleDevice?> selectedDevice = ValueNotifier<BleDevice?>(null);
  ValueNotifier<List<BleService>> services = ValueNotifier<List<BleService>>([]);
  ValueNotifier<Uint8List?> receivedData = ValueNotifier<Uint8List?>(null);

  void initializeBluetooth() {
    _updateBluetoothState();
    
    if (!kIsWeb) {
      UniversalBle.enableBluetooth(); // this isn't implemented on web
    }
    
    UniversalBle.onScanResult = _onScanResult;
    UniversalBle.onAvailabilityChange = _onBluetoothAvailabilityChanged;
    UniversalBle.onPairingStateChange = _onPairingStateChange;
  }

  Future<void> _updateBluetoothState() async {
    bluetoothState = await UniversalBle.getBluetoothAvailabilityState();
  }

  void _onScanResult(BleDevice device) {
    for (var deviceListDevice in devices.value) {
      if (deviceListDevice.deviceId == device.deviceId) {
        if (deviceListDevice.name == device.name) {
          return;
        }
      }
    }
    devices.value = [...devices.value, device];
  }

  void _onBluetoothAvailabilityChanged(AvailabilityState state) {
    bluetoothState = state;
  }

  void stopScan() async {
    UniversalBle.stopScan();
    isScanning.value = false;
  }

  void startScan() async {
    if (bluetoothState != AvailabilityState.poweredOn) {
      return;
    }
    devices.value.clear();
    services.value.clear();
    isScanning.value = true;
    await UniversalBle.startScan(
      platformConfig: PlatformConfig(
        web: WebOptions(optionalServices: [
          BT_SERVICE_ID, BT_CHARACTERISTIC_ID, BT_S2, BT_S3
          ]),
      ),
    );
  }

  void toggleScan() async {
    if (isScanning.value) {
      stopScan();
    } else {
      startScan();
    }
  }

  void _onPairingStateChange(String deviceId, bool isPaired) {
    debugPrint('isPaired $deviceId, $isPaired');
    // _addLog("PairingStateChange - isPaired", isPaired);
  }

  Future<void> connectToDevice(BleDevice device) async {
    if (isScanning.value) {
      stopScan();
    }
    try {
      await UniversalBle.connect(device.deviceId);
      services.value = await UniversalBle.discoverServices(device.deviceId);
      selectedDevice.value = device;
    } catch (e) {
      // Error handling can be implemented here
    }
  }

  void dispose() {
    UniversalBle.onScanResult = null;
    UniversalBle.onAvailabilityChange = null;
  }

  void subscribeToService(BleService service) async {
    final deviceId = selectedDevice.value?.deviceId;
    if (deviceId == null) return;
    
    // TODO can only subscribe once, otherwise I get "DartError: Exception: Already listening to this characteristic"
    for (var characteristic in service.characteristics) {
      if ((characteristic.uuid == BT_CHARACTERISTIC_ID) &&
          characteristic.properties.contains(CharacteristicProperty.notify)) {
        await UniversalBle.setNotifiable(deviceId, service.uuid, characteristic.uuid, BleInputProperty.notification);

        UniversalBle.onValueChange = (String deviceId, String characteristicId, Uint8List value) {
          debugPrint('onValueChange $deviceId, $characteristicId, ${hex.encode(value)}');
          receivedData.value = value; // Notify the UI layer of new data
        };
        return;
      }
    }
  }
}


class BluetoothDeviceList extends StatelessWidget {
  final BluetoothHandling bluetoothService;

  const BluetoothDeviceList({super.key, required this.bluetoothService});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (bluetoothService.isScanning.value) 
          const CircularProgressIndicator(),
        Expanded(
          child: ValueListenableBuilder<List<BleDevice>>(
            valueListenable: bluetoothService.devices,
            builder: (context, devices, _) {
              return ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.name ?? "Unknown Device"),
                    subtitle: Text('Device ID: ${device.deviceId}'),
                    onTap: () => bluetoothService.connectToDevice(device),
                  );
                },
              );
            },
          ),
        ),
        Flexible( 
          // Use Flexible instead of Expanded here to ensure layout stability
          child: ValueListenableBuilder<BleDevice?>(
            valueListenable: bluetoothService.selectedDevice,
            builder: (context, selectedDevice, _) {
              return selectedDevice != null
                  ? BluetoothServiceDetails(bluetoothService: bluetoothService)
                  : SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

class BluetoothServiceDetails extends StatelessWidget {
  final BluetoothHandling bluetoothService;

  const BluetoothServiceDetails({super.key, required this.bluetoothService});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        Text(
          'Connected to: ${bluetoothService.selectedDevice.value?.name ?? "Unknown Device"}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Expanded(
          child: ValueListenableBuilder<List<BleService>>(
            valueListenable: bluetoothService.services,
            builder: (context, services, _) {
              if (services.isNotEmpty) {
                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return ListTile(
                      title: Text('Service: ${service.uuid}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: service.characteristics
                            .map((char) => Text('Characteristic: ${char.uuid}'))
                            .toList(),
                      ),
                      onTap: () => bluetoothService.subscribeToService(service),
                    );
                  },
                );
              } else {
                return const Text('No services found for this device.');
              }
            },
          ),
        ),
      ],
    );
  }
}

class BluetoothIndicator extends StatelessWidget {
  final BluetoothHandling bluetoothService;

  const BluetoothIndicator({super.key, required this.bluetoothService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: bluetoothService.isScanning,
      builder: (context, isScanning, child) {
        IconData iconData;
        Color color;

        // Determine icon based on Bluetooth and scanning states
        if (isScanning) {
          iconData = Icons.bluetooth_searching;
          color = Colors.blueAccent;
        } else {
          switch (bluetoothService.bluetoothState) {
            case AvailabilityState.poweredOn:
              iconData = Icons.bluetooth;
              color = Colors.blue;
              break;
            case AvailabilityState.poweredOff:
              iconData = Icons.bluetooth_disabled;
              color = Colors.red;
              break;
            case AvailabilityState.unknown:
              iconData = Icons.question_mark;
              color = Colors.red;
              break;
            case AvailabilityState.resetting:
              iconData = Icons.question_mark;
              color = Colors.green;
              break;
            case AvailabilityState.unsupported:
              iconData = Icons.stop;
              color = Colors.red;
              break;
            case AvailabilityState.unauthorized:
              iconData = Icons.stop;
              color = Colors.blue;
              break;
            default:
              iconData = Icons.question_mark;
              color = Colors.grey;
              break;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(iconData, color: color),
        );
      },
    );
  }
}
