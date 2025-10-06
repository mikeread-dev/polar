import CoreBluetooth
import Flutter
import PolarBleSdk
import RxSwift
import UIKit

private let encoder = JSONEncoder()
private let decoder = JSONDecoder()

// Remove type aliases that might be causing issues
// typealias PolarHrFeature = Int
// typealias PolarFtpFeature = Int

private func jsonEncode(_ value: Encodable) -> String? {
  guard let data = try? encoder.encode(value),
    let data = String(data: data, encoding: .utf8)
  else {
    return nil
  }

  return data
}

// Remove our custom enum and use the real PolarBleSdk errors instead
// These are the commonly used error types from PolarBleSdk

private enum PolarErrorCode {
    static let deviceDisconnected = "device_disconnected"
    static let notSupported = "not_supported"
    static let invalidArgument = "invalid_argument"
    static let operationNotAllowed = "operation_not_allowed"
    static let timeout = "timeout"
    static let bluetoothError = "bluetooth_error"
}

// Wrapper structure to match Flutter's expected PolarSleepData format
private struct PolarSleepDataWrapper: Encodable {
    let date: String
    let result: PolarSleepData.PolarSleepAnalysisResult
}

public class SwiftPolarPlugin:
  NSObject,
  FlutterPlugin,
  PolarBleApiObserver,
  PolarBleApiPowerStateObserver,
  PolarBleApiDeviceFeaturesObserver,
  PolarBleApiDeviceInfoObserver
{
  /// Binary messenger for dynamic EventChannel registration
  let messenger: FlutterBinaryMessenger

  /// Method channel
  let channel: FlutterMethodChannel

  /// Search channel
  let searchChannel: FlutterEventChannel

  /// Firmware update channel
  let firmwareUpdateChannel: FlutterEventChannel

  /// Streaming channels
  var streamingChannels = [String: StreamingChannel]()

  var api: PolarBleApi!
  
  /// Disposable bag for RxSwift subscriptions
  let disposeBag = DisposeBag()

  init(
    messenger: FlutterBinaryMessenger,
    channel: FlutterMethodChannel,
    searchChannel: FlutterEventChannel,
    firmwareUpdateChannel: FlutterEventChannel
  ) {
    self.messenger = messenger
    self.channel = channel
    self.searchChannel = searchChannel
    self.firmwareUpdateChannel = firmwareUpdateChannel
  }

  // Add the method back to conform to FlutterPlugin protocol
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "polar", binaryMessenger: registrar.messenger())
    let searchChannel = FlutterEventChannel(name: "polar/search", binaryMessenger: registrar.messenger())
    let firmwareUpdateChannel = FlutterEventChannel(name: "polar/firmware_update", binaryMessenger: registrar.messenger())
    
    let instance = SwiftPolarPlugin(
        messenger: registrar.messenger(),
        channel: channel,
        searchChannel: searchChannel,
        firmwareUpdateChannel: firmwareUpdateChannel
    )
    
    registrar.addMethodCallDelegate(instance, channel: channel)
    searchChannel.setStreamHandler(instance.searchHandler)
    firmwareUpdateChannel.setStreamHandler(instance.firmwareUpdateHandler)
  }

  private func initApi() {
    guard api == nil else { return }
    api = PolarBleApiDefaultImpl.polarImplementation(
      DispatchQueue.main, features: Set(PolarBleSdkFeature.allCases))

    api.observer = self
    api.powerStateObserver = self
    api.deviceFeaturesObserver = self
    api.deviceInfoObserver = self
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    initApi()

    do {
      switch call.method {
      case "connectToDevice":
        try api.connectToDevice(call.arguments as! String)
        result(nil)
      case "disconnectFromDevice":
        try api.disconnectFromDevice(call.arguments as! String)
        result(nil)
      case "getAvailableOnlineStreamDataTypes":
        getAvailableOnlineStreamDataTypes(call, result)
      case "requestStreamSettings":
        try requestStreamSettings(call, result)
      case "createStreamingChannel":
        createStreamingChannel(call, result)
      case "startRecording":
        startRecording(call, result)
      case "stopRecording":
        stopRecording(call, result)
      case "requestRecordingStatus":
        requestRecordingStatus(call, result)
      case "listExercises":
        listExercises(call, result)
      case "fetchExercise":
        fetchExercise(call, result)
      case "removeExercise":
        removeExercise(call, result)
      case "setLedConfig":
        setLedConfig(call, result)
      case "doFactoryReset":
        doFactoryReset(call, result)
      case "enableSdkMode":
        enableSdkMode(call, result)
      case "disableSdkMode":
        disableSdkMode(call, result)
      case "isSdkModeEnabled":
        isSdkModeEnabled(call, result)
      case "getAvailableOfflineRecordingDataTypes":
        getAvailableOfflineRecordingDataTypes(call, result)
      case "requestOfflineRecordingSettings":
        requestOfflineRecordingSettings(call, result)
      case "startOfflineRecording":
        startOfflineRecording(call, result)
      case "stopOfflineRecording":
        stopOfflineRecording(call, result)
      case "getOfflineRecordingStatus":
        getOfflineRecordingStatus(call, result)
      case "listOfflineRecordings":
        listOfflineRecordings(call, result)
      case "getOfflineRecord":
        getOfflineRecord(call, result)
      case "removeOfflineRecord":
        removeOfflineRecord(call, result)
      case "getDiskSpace":
        getDiskSpace(call, result)
      case "getLocalTime":
        getLocalTime(call, result)
      case "setLocalTime":
        setLocalTime(call, result)
      case "doFirstTimeUse":
        doFirstTimeUse(call, result)
      case "isFtuDone":
        isFtuDone(call, result)
      case "getSleep":
        getSleep(call, result)
      case "stopSleepRecording":
        stopSleepRecording(call, result)
      case "getSleepRecordingState":
        getSleepRecordingState(call, result)
      case "setupSleepStateObservation":
        setupSleepStateObservation(call, result)

      case "deleteDeviceDateFolders":
        deleteDeviceDateFolders(call, result)
      case "deleteStoredDeviceData":
        deleteStoredDeviceData(call, result)
      case "setOfflineRecordingTrigger":
        setOfflineRecordingTrigger(call, result)
      case "doRestart":
        doRestart(call, result)
      case "updateFirmware":
        updateFirmware(call, result)
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      result(
        FlutterError(
          code: "Error in Polar plugin", message: error.localizedDescription, details: nil))
    }
  }

  var searchSubscription: Disposable?
  lazy var searchHandler = StreamHandler(
    onListen: { _, events in
      self.initApi()

      self.searchSubscription = self.api.searchForDevice().subscribe(
        onNext: { data in
          guard let data = jsonEncode(PolarDeviceInfoCodable(data))
          else { return }
          DispatchQueue.main.async {
            events(data)
          }
        },
        onError: { error in
          DispatchQueue.main.async {
            events(
              FlutterError(
                code: "Error in searchForDevice", message: error.localizedDescription, details: nil)
            )
          }
        },
        onCompleted: {
          DispatchQueue.main.async {
            events(FlutterEndOfEventStream)
          }
        })
      return nil
    },
    onCancel: { _ in
      self.searchSubscription?.dispose()
      return nil
    })

  var firmwareUpdateSubscription: Disposable?
  var firmwareUpdateEvents: FlutterEventSink?
  
  lazy var firmwareUpdateHandler = StreamHandler(
    onListen: { _, events in
      self.firmwareUpdateEvents = events
      return nil
    },
    onCancel: { _ in
      self.firmwareUpdateSubscription?.dispose()
      self.firmwareUpdateEvents = nil
      return nil
    })

  private func createStreamingChannel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult)
  {
    let arguments = call.arguments as! [Any]
    let name = arguments[0] as! String
    let identifier = arguments[1] as! String
    let feature = PolarDeviceDataType.allCases[arguments[2] as! Int]

    if streamingChannels[name] == nil {
      streamingChannels[name] = StreamingChannel(messenger, name, api, identifier, feature)
    }

    result(nil)
  }

  func getAvailableOnlineStreamDataTypes(
    _ call: FlutterMethodCall, _ result: @escaping FlutterResult
  ) {
    let identifier = call.arguments as! String

    _ = api.getAvailableOnlineStreamDataTypes(identifier).subscribe(
      onSuccess: { data in
        guard let data = jsonEncode(data.map { PolarDeviceDataType.allCases.firstIndex(of: $0)! })
        else {
          result(
            result(
              FlutterError(
                code: "Unable to get available online stream data types", message: nil, details: nil
              )))
          return
        }
        result(data)
      },
      onFailure: {
        result(
          FlutterError(
            code: "Unable to get available online stream data types",
            message: $0.localizedDescription, details: nil))
      })
  }

  func requestStreamSettings(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let feature = PolarDeviceDataType.allCases[arguments[1] as! Int]

    _ = api.requestStreamSettings(identifier, feature: feature).subscribe(
      onSuccess: { data in
        guard let data = jsonEncode(PolarSensorSettingCodable(data))
        else { return }
        result(data)
      },
      onFailure: {
        result(
          FlutterError(
            code: "Unable to request stream settings", message: $0.localizedDescription,
            details: nil))
      })
  }

  func startRecording(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let exerciseId = arguments[1] as! String
    let interval = RecordingInterval(rawValue: arguments[2] as! Int)!
    let sampleType = SampleType(rawValue: arguments[3] as! Int)!

    _ = api.startRecording(
      identifier,
      exerciseId: exerciseId,
      interval: interval,
      sampleType: sampleType
    ).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        result(
          FlutterError(
            code: "Error starting recording", message: error.localizedDescription, details: nil))
      })
  }

  func stopRecording(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String

    _ = api.stopRecording(identifier).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        result(
          FlutterError(
            code: "Error stopping recording", message: error.localizedDescription, details: nil))
      })
  }

  func requestRecordingStatus(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String

    _ = api.requestRecordingStatus(identifier).subscribe(
      onSuccess: { data in
        result([data.ongoing, data.entryId])
      },
      onFailure: { error in
        result(
          FlutterError(
            code: "Error stopping recording", message: error.localizedDescription, details: nil))
      })
  }

  func listExercises(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String

    var exercises = [String]()
    _ = api.fetchStoredExerciseList(identifier).subscribe(
      onNext: { data in
        guard let data = jsonEncode(PolarExerciseEntryCodable(data))
        else {
          return
        }
        exercises.append(data)
      },
      onError: { error in
        result(
          FlutterError(
            code: "Error listing exercises", message: error.localizedDescription, details: nil))
      },
      onCompleted: {
        result(exercises)
      }
    )
  }

  func fetchExercise(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let entry = try! decoder.decode(
      PolarExerciseEntryCodable.self,
      from: (arguments[1] as! String)
        .data(using: .utf8)!
    ).data

    _ = api.fetchExercise(identifier, entry: entry).subscribe(
      onSuccess: { data in
        guard let data = jsonEncode(PolarExerciseDataCodable(data))
        else {
          return
        }
        result(data)
      },
      onFailure: { error in
        result(
          FlutterError(
            code: "Error  fetching exercise", message: error.localizedDescription, details: nil))
      })
  }

  func removeExercise(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [Any],
          let identifier = arguments[0] as? String,
          let entryData = (arguments[1] as? String)?.data(using: .utf8) else {
        result(FlutterError(
            code: PolarErrorCode.invalidArgument,
            message: "Invalid arguments provided",
            details: nil
        ))
        return
    }

    do {
        let entry = try JSONDecoder().decode(PolarExerciseEntryCodable.self, from: entryData).data
        api.removeExercise(identifier, entry: entry)
            .subscribe(
                onCompleted: {
                    result(nil)
                },
                onError: { error in
                    let code: String
                    // Use a more generic approach with thorough error detection
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("disconnect") || errorDescription.contains("device disconnect") {
                        code = PolarErrorCode.deviceDisconnected
                    } else if errorDescription.contains("support") || errorDescription.contains("unsupport") || errorDescription.contains("not supported") {
                        code = PolarErrorCode.notSupported
                    } else {
                        code = PolarErrorCode.bluetoothError
                    }
                    result(FlutterError(
                        code: code,
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            )
    } catch {
        result(FlutterError(
            code: PolarErrorCode.invalidArgument,
            message: "Failed to decode exercise entry",
            details: nil
        ))
    }
  }

  func setLedConfig(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let config = try! decoder.decode(
      LedConfigCodable.self,
      from: (arguments[1] as! String)
        .data(using: .utf8)!
    ).data
    _ = api.setLedConfig(identifier, ledConfig: config).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        result(
          FlutterError(
            code: "Error setting led config", message: error.localizedDescription, details: nil))
      })
  }

  func doFactoryReset(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let preservePairingInformation = arguments[1] as! Bool
    _ = api.doFactoryReset(identifier, preservePairingInformation: preservePairingInformation)
      .subscribe(
        onCompleted: {
          result(nil)
        },
        onError: { error in
          result(
            FlutterError(
              code: "Error doing factory reset", message: error.localizedDescription, details: nil))
        })
  }

  func enableSdkMode(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String
    _ = api.enableSDKMode(identifier).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        result(
          FlutterError(
            code: "Error enabling SDK mode", message: error.localizedDescription, details: nil))
      })
  }

  func disableSdkMode(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String
    _ = api.disableSDKMode(identifier).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        result(
          FlutterError(
            code: "Error disabling SDK mode", message: error.localizedDescription, details: nil))
      })
  }

  func isSdkModeEnabled(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String
    _ = api.isSDKModeEnabled(identifier).subscribe(
      onSuccess: {
        result($0)
      },
      onFailure: { error in
        result(
          FlutterError(
            code: "Error checking SDK mode status", message: error.localizedDescription,
            details: nil))
      })
  }

  private func invokeMethod(_ methodName: String, arguments: Any? = nil) {
    DispatchQueue.main.async {
      self.channel.invokeMethod(methodName, arguments: arguments)
    }
  }

  public func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
    guard let data = jsonEncode(PolarDeviceInfoCodable(polarDeviceInfo))
    else {
      return
    }
    invokeMethod("deviceConnecting", arguments: data)
  }

  public func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
    guard let data = jsonEncode(PolarDeviceInfoCodable(polarDeviceInfo))
    else {
      return
    }
    invokeMethod("deviceConnected", arguments: data)
  }

  public func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
    guard let data = jsonEncode(PolarDeviceInfoCodable(polarDeviceInfo))
    else {
      return
    }
    invokeMethod("deviceDisconnected", arguments: [data, pairingError])
  }

  public func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
    invokeMethod("batteryLevelReceived", arguments: [identifier, batteryLevel])
  }

  public func batteryChargingStatusReceived(_ identifier: String, chargingStatus: BleBasClient.ChargeState) {
    // Convert ChargeState to integer values that Flutter can understand
    let statusValue: Int
    
    switch chargingStatus {
    case .unknown:
      statusValue = -1
    case .charging:
      statusValue = 1
    case .dischargingActive:
      statusValue = 0
    case .dischargingInactive:
      statusValue = 2
    }
    
    invokeMethod("batteryChargingStatusReceived", arguments: [identifier, statusValue])
  }

  public func blePowerOn() {
    invokeMethod("blePowerStateChanged", arguments: true)
  }

  public func blePowerOff() {
    invokeMethod("blePowerStateChanged", arguments: false)
  }

  public func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
    invokeMethod(
      "sdkFeatureReady",
      arguments: [
        identifier,
        PolarBleSdkFeature.allCases.firstIndex(of: feature)!,
      ])
  }

  public func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
    invokeMethod(
      "disInformationReceived", arguments: [identifier, uuid.uuidString, value])
  }

  public func disInformationReceivedWithKeysAsStrings(
    _ identifier: String, key: String, value: String
  ) {
    channel.invokeMethod("disInformationReceived", arguments: [identifier, key, value])
  }

  public func deviceInfoReceived(_ identifier: String, rssi: Int, name: String, connectable: Bool) {
    invokeMethod("deviceInfoReceived", arguments: [identifier, rssi, name, connectable])
  }

  // MARK: - PolarBleApiDeviceFeaturesObserver Implementation
  
  // Added to fully implement the protocol - may need to adjust parameter types
  public func deviceFeaturesReceived(_ identifier: String, features: Set<String>) {
    invokeMethod("deviceFeaturesReceived", arguments: [identifier, Array(features)])
  }

  // MARK: Deprecated functions

  public func streamingFeaturesReady(
    _ identifier: String, streamingFeatures: Set<PolarBleSdk.PolarDeviceDataType>
  ) {
    // Do nothing
  }

  public func hrFeatureReady(_ identifier: String) {
    // Do nothing
  }

  public func ftpFeatureReady(_ identifier: String) {
    // Do nothing
  }

  func getAvailableOfflineRecordingDataTypes(
    _ call: FlutterMethodCall, _ result: @escaping FlutterResult
  ) {
    guard let identifier = call.arguments as? String else {
      result(
        FlutterError(code: "INVALID_ARGUMENT", message: "Identifier is not a string", details: nil))
      return
    }

    // Use the api to get available offline recording data types
    _ = api.getAvailableOfflineRecordingDataTypes(identifier).subscribe(
      onSuccess: { dataTypes in
        // Map data types to their respective indices
        let dataTypesIds = dataTypes.compactMap { PolarDeviceDataType.allCases.firstIndex(of: $0) }
        // Safely convert indices to description strings and return
        let dataTypesDescriptions = dataTypesIds.map { "\($0)" }
        result(dataTypesDescriptions)
      },
      onFailure: { error in
        result(
          FlutterError(
            code: "ERROR_GETTING_DATA_TYPES",
            message: error.localizedDescription,
            details: nil
          ))
      }
    )
  }

  func requestOfflineRecordingSettings(_ call: FlutterMethodCall, _ result: @escaping FlutterResult)
  {
    guard let arguments = call.arguments as? [Any] else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENT", message: "Arguments are not in expected format", details: nil))
      return
    }
    guard let identifier = arguments[0] as? String else {
      result(
        FlutterError(
          code: "INVALID_IDENTIFIER", message: "Identifier is not a string", details: nil))
      return
    }
    guard let index = arguments[1] as? Int, index < PolarDeviceDataType.allCases.count else {
      result(
        FlutterError(
          code: "INVALID_FEATURE", message: "Feature index is out of bounds", details: nil))
      return
    }
    let feature = PolarDeviceDataType.allCases[index]

    _ = api.requestStreamSettings(identifier, feature: feature)
      .subscribe(
        onSuccess: { settings in
          if let encodedData = jsonEncode(PolarSensorSettingCodable(settings)) {
            result(encodedData)
          } else {
            result(
              FlutterError(
                code: "ENCODING_ERROR", message: "Failed to encode stream settings", details: nil))
          }
        },
        onFailure: { error in
          result(
            FlutterError(
              code: "REQUEST_ERROR",
              message: "Error requesting stream settings: \(error.localizedDescription)",
              details: nil))
        })
  }

  func startOfflineRecording(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let feature = PolarDeviceDataType.allCases[arguments[1] as! Int]
    // Attempt to decode the sensor settings
    let settingsData = arguments[2] as? String
    let settings =
      settingsData != nil
      ? try? decoder.decode(
        PolarSensorSettingCodable.self,
        from: settingsData!.data(using: .utf8)!
      ).data : nil

    _ = api.startOfflineRecording(identifier, feature: feature, settings: settings, secret: nil)
      .subscribe(
        onCompleted: {
          result(nil)
        },
        onError: { error in
          result(
            FlutterError(
              code: "Error starting offline recording", message: error.localizedDescription,
              details: nil))
        })
  }

  func stopOfflineRecording(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {

    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let feature = PolarDeviceDataType.allCases[arguments[1] as! Int]

    api.stopOfflineRecording(identifier, feature: feature).subscribe(
      onCompleted: {

        result(nil)

      },
      onError: { error in

        result(
          FlutterError(
            code: "Error stopping offline recording",
            message: error.localizedDescription.description, details: nil))
      })
  }

  func getOfflineRecordingStatus(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String

    _ = api.getOfflineRecordingStatus(identifier)
      .subscribe(
        onSuccess: { statusDict in
          // Filter and map keys where the value is true
          let keysWithTrueValues = statusDict.compactMap { key, value -> Int? in
            value ? PolarDeviceDataType.allCases.firstIndex(of: key) : nil
          }
          result(keysWithTrueValues)  // Return only the filtered list of keys
        },
        onFailure: { error in
          result(
            FlutterError(
              code: "Error getting offline recording status", message: error.localizedDescription,
              details: nil)
          )
        })
  }

  func listOfflineRecordings(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let identifier = call.arguments as? String else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS", message: "Expected a string identifier as argument",
          details: nil))
      return
    }

    api.listOfflineRecordings(identifier).debug("listOfflineRecordings")
      .toArray()
      .subscribe(
        onSuccess: { entries in
          var jsonStringList: [String] = []

          do {
            encoder.dateEncodingStrategy = .millisecondsSince1970
            for entry in entries {
              // Use PolarOfflineRecordingEntryCodable for encoding
              let entryCodable = PolarOfflineRecordingEntryCodable(entry)
              let data = try encoder.encode(entryCodable)
              if let jsonString = String(data: data, encoding: .utf8) {
                jsonStringList.append(jsonString)
              }
            }
            result(jsonStringList)  // Return the array of JSON strings
          } catch {
            result(
              FlutterError(
                code: "ENCODE_ERROR", message: "Failed to encode entries to JSON", details: nil))
          }
        },
        onFailure: { error in
          result(
            FlutterError(
              code: "ERROR",
              message: "Offline recording listing error: \(error.localizedDescription)",
              details: nil))
        }
      )
  }

  func getOfflineRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let entryJsonString = arguments[1] as! String

    guard let entryData = entryJsonString.data(using: .utf8) else {
      result(
        FlutterError(code: "INVALID_ARGUMENT", message: "Invalid entry JSON string", details: nil))
      return
    }

    do {
      let entry = try JSONDecoder().decode(PolarOfflineRecordingEntryCodable.self, from: entryData)
        .data

      _ = api.getOfflineRecord(identifier, entry: entry, secret: nil)
        .subscribe(
          onSuccess: { recordingData in
            do {
              // Use the PolarOfflineRecordingDataCodable to encode the data to JSON
              let dataCodable = PolarOfflineRecordingDataCodable(recordingData)
              encoder.dateEncodingStrategy = .millisecondsSince1970
              let data = try encoder.encode(dataCodable)
              if let jsonString = String(data: data, encoding: .utf8) {
                result(jsonString)
              } else {
                result(
                  FlutterError(
                    code: "ENCODE_ERROR", message: "Failed to encode recording data to JSON string",
                    details: nil))
              }
            } catch {
              result(
                FlutterError(
                  code: "ENCODE_ERROR", message: "Failed to encode recording data to JSON",
                  details: nil))
            }
          },
          onFailure: { error in
            result(
              FlutterError(
                code: "FETCH_ERROR",
                message: "Failed to fetch recording: \(error.localizedDescription)", details: nil))
          }
        )
    } catch {
      result(
        FlutterError(code: "DECODE_ERROR", message: "Failed to decode entry JSON", details: nil))
    }
  }

  func removeOfflineRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let entryJsonString = arguments[1] as! String

    guard let entryData = entryJsonString.data(using: .utf8) else {
      result(
        FlutterError(code: "INVALID_ARGUMENT", message: "Invalid entry JSON string", details: nil))
      return
    }

    do {
      let entry = try! JSONDecoder().decode(PolarOfflineRecordingEntryCodable.self, from: entryData)
        .data

      _ = api.removeOfflineRecord(identifier, entry: entry).subscribe(
        onCompleted: {
          result(nil)
        },
        onError: { error in
          result(
            FlutterError(
              code: "Error removing exercise", message: error.localizedDescription, details: nil))
        })
    }
  }

  func getDiskSpace(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String
    _ = api.getDiskSpace(identifier).subscribe(
      onSuccess: { diskSpaceData in
        let freeSpace = diskSpaceData.freeSpace  // Corrected from 'availableSpace'
        let totalSpace = diskSpaceData.totalSpace
        result([freeSpace, totalSpace])  // Return as a list
      },
      onFailure: { error in
        result(
          FlutterError(
            code: "Error getting disk space", message: error.localizedDescription, details: nil))
      })
  }

  func getLocalTime(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let identifier = call.arguments as? String else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS", message: "Expected a device identifier as a String",
          details: nil))
      return
    }

    _ = api.getLocalTime(identifier).subscribe(
      onSuccess: { time in
        let dateFormatter = ISO8601DateFormatter()
        let timeString = dateFormatter.string(from: time)

        result(timeString)
      },
      onFailure: { error in
        result(
          FlutterError(
            code: "GET_LOCAL_TIME_ERROR",
            message: error.localizedDescription,
            details: nil
          )
        )
      })
  }

  func setLocalTime(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [Any],
      args.count == 2,
      let identifier = args[0] as? String,
      let timestamp = args[1] as? Double
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS", message: "Expected [identifier, timestamp] as arguments",
          details: nil))
      return
    }

    let time = Date(timeIntervalSince1970: timestamp)

    let timeZone = TimeZone.current

    _ = api.setLocalTime(identifier, time: time, zone: timeZone).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        result(
          FlutterError(
            code: "SET_LOCAL_TIME_ERROR",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    )
  }

  func doFirstTimeUse(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let identifier = args["identifier"] as? String,
      let configDict = args["config"] as? [String: Any]
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Expected identifier and config dictionary",
          details: nil))
      return
    }

    // Convert the dictionary to PolarFirstTimeUseConfig
    guard let gender = configDict["gender"] as? String,
      let birthDateString = configDict["birthDate"] as? String,
      let height = configDict["height"] as? Int,
      let weight = configDict["weight"] as? Int,
      let maxHeartRate = configDict["maxHeartRate"] as? Int,
      let vo2Max = configDict["vo2Max"] as? Int,
      let restingHeartRate = configDict["restingHeartRate"] as? Int,
      let trainingBackground = configDict["trainingBackground"] as? Int,
      let deviceTime = configDict["deviceTime"] as? String,
      let typicalDay = configDict["typicalDay"] as? Int,
      let sleepGoalMinutes = configDict["sleepGoalMinutes"] as? Int
    else {
      result(
        FlutterError(
          code: "INVALID_CONFIG",
          message: "Invalid configuration parameters",
          details: nil))
      return
    }

    // Convert string date to Date object
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let birthDate = dateFormatter.date(from: birthDateString) else {
      result(
        FlutterError(
          code: "INVALID_DATE",
          message: "Invalid birth date format",
          details: nil))
      return
    }

    // Convert training background value to appropriate enum case
    let trainingBackgroundLevel: PolarFirstTimeUseConfig.TrainingBackground
    switch trainingBackground {
    case 10: trainingBackgroundLevel = .occasional
    case 20: trainingBackgroundLevel = .regular
    case 30: trainingBackgroundLevel = .frequent
    case 40: trainingBackgroundLevel = .heavy
    case 50: trainingBackgroundLevel = .semiPro
    case 60: trainingBackgroundLevel = .pro
    default: trainingBackgroundLevel = .occasional  // default fallback
    }

    // Convert typical day to enum
    let typicalDayEnum: PolarFirstTimeUseConfig.TypicalDay
    switch typicalDay {
    case 1: typicalDayEnum = .mostlyMoving
    case 2: typicalDayEnum = .mostlySitting
    case 3: typicalDayEnum = .mostlyStanding
    default: typicalDayEnum = .mostlySitting
    }

    // Create config object with validation
    let config = PolarBleSdk.PolarFirstTimeUseConfig(
      gender: gender == "Male" ? .male : .female,
      birthDate: birthDate,
      height: Float(height),
      weight: Float(weight),
      maxHeartRate: maxHeartRate,
      vo2Max: vo2Max,
      restingHeartRate: restingHeartRate,
      trainingBackground: trainingBackgroundLevel,
      deviceTime: deviceTime,
      typicalDay: typicalDayEnum,
      sleepGoalMinutes: sleepGoalMinutes
    )

    _ = api.doFirstTimeUse(identifier, ftuConfig: config).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        result(
          FlutterError(
            code: "FTU_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
      }
    )
  }

  func isFtuDone(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let identifier = call.arguments as? String else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Expected a device identifier as a String",
          details: nil
        ))
      return
    }

    _ = api.isFtuDone(identifier).subscribe(
      onSuccess: { isFtuDone in
        result(isFtuDone)
      },
      onFailure: { error in
        result(
          FlutterError(
            code: "FTU_CHECK_ERROR",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    )
  }

  func getSleep(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let fromDateStr = arguments[1] as! String
    let toDateStr = arguments[2] as! String
    
    // Convert strings to Date objects with proper timezone handling
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current // Use current timezone
    
    guard let fromDate = dateFormatter.date(from: fromDateStr),
          let toDate = dateFormatter.date(from: toDateStr) else {
        result(FlutterError(
          code: PolarErrorCode.invalidArgument,
          message: "Invalid date format. Expected YYYY-MM-DD",
          details: nil))
        return
    }
    
    // For debugging
    print("[PolarPlugin] getSleep called with fromDate=\(fromDateStr), toDate=\(toDateStr)")
    print("[PolarPlugin] Parsed dates - fromDate=\(fromDate), toDate=\(toDate)")
    
    // Use the correct iOS API method getSleepData
    _ = api.getSleepData(identifier: identifier, fromDate: fromDate, toDate: toDate).subscribe(
        onSuccess: { sleepAnalysisResults in
            print("[PolarPlugin] getSleepData received \(sleepAnalysisResults.count) sleep analysis results")
            
            // Enhanced debugging for each sleep result
            for (index, sleepResult) in sleepAnalysisResults.enumerated() {
                print("[PolarPlugin] === Sleep Record \(index + 1) Details ===")
                print("[PolarPlugin] sleepResultDate: \(sleepResult.sleepResultDate ?? "nil")")
                print("[PolarPlugin] sleepStartTime: \(sleepResult.sleepStartTime?.description ?? "nil")")
                print("[PolarPlugin] sleepEndTime: \(sleepResult.sleepEndTime?.description ?? "nil")")
                print("[PolarPlugin] lastModified: \(sleepResult.lastModified?.description ?? "nil")")
                print("[PolarPlugin] sleepGoalMinutes: \(sleepResult.sleepGoalMinutes?.description ?? "nil")")
                print("[PolarPlugin] deviceId: \(sleepResult.deviceId ?? "nil")")
                print("[PolarPlugin] userSleepRating: \(sleepResult.userSleepRating?.rawValue.description ?? "nil")")
                print("[PolarPlugin] batteryRanOut: \(sleepResult.batteryRanOut?.description ?? "nil")")
                print("[PolarPlugin] sleepStartOffsetSeconds: \(sleepResult.sleepStartOffsetSeconds?.description ?? "nil")")
                print("[PolarPlugin] sleepEndOffsetSeconds: \(sleepResult.sleepEndOffsetSeconds?.description ?? "nil")")
                print("[PolarPlugin] sleepWakePhases count: \(sleepResult.sleepWakePhases?.count ?? 0)")
                print("[PolarPlugin] sleepCycles count: \(sleepResult.sleepCycles?.count ?? 0)")
                print("[PolarPlugin] snoozeTime count: \(sleepResult.snoozeTime?.count ?? 0)")
                print("[PolarPlugin] alarmTime: \(sleepResult.alarmTime?.description ?? "nil")")
                print("[PolarPlugin] originalSleepRange: \(sleepResult.originalSleepRange != nil ? "present" : "nil")")
                print("[PolarPlugin] ================================")
            }
            
            // Convert to the structure Flutter expects: PolarSleepData with analysis wrapper
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                
                // Wrap each sleep analysis result in the expected PolarSleepData structure
                let wrappedSleepData = sleepAnalysisResults.map { analysisResult in
                    return PolarSleepDataWrapper(
                        date: analysisResult.sleepResultDate ?? "",
                        result: analysisResult
                    )
                }
                
                let jsonData = try encoder.encode(wrappedSleepData)
                let jsonString = String(data: jsonData, encoding: .utf8)
                
                // Log the actual JSON being sent to Flutter
                print("[PolarPlugin] JSON being sent to Flutter:")
                print("[PolarPlugin] \(jsonString ?? "nil")")
                
                result(jsonString)
            } catch {
                print("[PolarPlugin] Encoding error: \(error)")
                result(FlutterError(
                  code: "ENCODING_ERROR",
                  message: "Failed to encode sleep data to JSON: \(error.localizedDescription)",
                  details: nil))
            }
        },
        onFailure: { error in
            print("[PolarPlugin] getSleepData error: \(error.localizedDescription)")
            let errorCode = self.mapErrorCode(error)
            result(FlutterError(
              code: errorCode,
              message: error.localizedDescription,
              details: nil))
        }
    )
  }

  func stopSleepRecording(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let identifier = call.arguments as? String else {
        result(FlutterError(
          code: PolarErrorCode.invalidArgument,
          message: "Expected a device identifier as a String",
          details: nil))
        return
    }
    
    print("[PolarPlugin] stopSleepRecording called for device \(identifier) at \(Date())")
    
    // Get device time for debugging
    _ = api.getLocalTime(identifier).subscribe(
        onSuccess: { deviceTime in
            print("[PolarPlugin] Device time before stopping sleep recording: \(deviceTime)")
            
            // Now stop the sleep recording
            _ = self.api.stopSleepRecording(identifier: identifier).subscribe(
                onCompleted: {
                    print("[PolarPlugin] Successfully stopped sleep recording")
                    result(nil)
                },
                onError: { error in
                    print("[PolarPlugin] Error stopping sleep recording: \(error.localizedDescription)")
                    print("[PolarPlugin] Error type: \(type(of: error))")
                    
                    let errorCode = self.mapErrorCode(error)
                    result(FlutterError(
                      code: errorCode,
                      message: error.localizedDescription,
                      details: nil))
                }
            )
        },
        onFailure: { error in
            print("[PolarPlugin] Could not get device time: \(error.localizedDescription)")
            
            // Continue with stopping sleep recording even if we can't get the time
            _ = self.api.stopSleepRecording(identifier: identifier).subscribe(
                onCompleted: {
                    result(nil)
                },
                onError: { error in
                    print("[PolarPlugin] Error stopping sleep recording: \(error.localizedDescription)")
                    
                    let errorCode = self.mapErrorCode(error)
                    result(FlutterError(
                      code: errorCode,
                      message: error.localizedDescription,
                      details: nil))
                }
            )
        }
    )
  }
  
  func getSleepRecordingState(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let identifier = call.arguments as? String else {
        result(FlutterError(
          code: PolarErrorCode.invalidArgument,
          message: "Expected a device identifier as a String",
          details: nil))
        return
    }
    
    print("[PolarPlugin] getSleepRecordingState called for device \(identifier)")
    
    _ = api.getSleepRecordingState(identifier: identifier).subscribe(
        onSuccess: { isRecording in
            print("[PolarPlugin] getSleepRecordingState result: \(isRecording)")
            result(isRecording)
        },
        onFailure: { error in
            print("[PolarPlugin] Error getting sleep recording state: \(error.localizedDescription)")
            
            let errorCode = self.mapErrorCode(error)
            result(FlutterError(
              code: errorCode,
              message: error.localizedDescription,
              details: nil))
        }
    )
  }
  
  func setupSleepStateObservation(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as! [String]
    let eventChannelName = arguments[0]
    let identifier = arguments[1]
    
    print("[PolarPlugin] Setting up sleep state observation for \(identifier) on channel \(eventChannelName)")
    
    // Create an event channel for this observation
    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    
    // Set up the handler for the event channel
    var stateSubscription: Disposable?
    let streamHandler = StreamHandler(
        onListen: { _, events in
            print("[PolarPlugin] Starting sleep state observation for \(identifier)")
            
            stateSubscription = self.api.observeSleepRecordingState(identifier: identifier).subscribe(
                onNext: { state in
                    print("[PolarPlugin] Sleep state changed: \(state[0])")
                    DispatchQueue.main.async {
                        events(state[0])  // First element is the sleep state
                    }
                },
                onError: { error in
                    print("[PolarPlugin] Error in sleep state observation: \(error.localizedDescription)")
                    
                    let errorCode = self.mapErrorCode(error)
                    DispatchQueue.main.async {
                        events(FlutterError(
                          code: errorCode,
                          message: error.localizedDescription,
                          details: nil))
                    }
                },
                onCompleted: {
                    print("[PolarPlugin] Sleep state observation completed")
                    DispatchQueue.main.async {
                        events(FlutterEndOfEventStream)
                    }
                }
            )
            
            return nil
        },
        onCancel: { _ in
            print("[PolarPlugin] Cancelling sleep state observation for \(identifier)")
            stateSubscription?.dispose()
            return nil
        }
    )
    
    eventChannel.setStreamHandler(streamHandler)
    
    // Indicate successful setup
    result(nil)
  }
  
  // Helper method to map Polar SDK errors to our error codes
  private func mapErrorCode(_ error: Error) -> String {
    if let polarError = error as? PolarErrors {
        switch polarError {
        case .deviceNotConnected:
            return PolarErrorCode.deviceDisconnected
        case .deviceNotFound:
            return PolarErrorCode.deviceDisconnected
        case .operationNotSupported:
            return PolarErrorCode.notSupported
        case .serviceNotFound:
            return PolarErrorCode.operationNotAllowed
        case .notificationNotEnabled:
            return PolarErrorCode.operationNotAllowed
        case .unableToStartStreaming:
            return PolarErrorCode.operationNotAllowed
        case .invalidArgument:
            return PolarErrorCode.invalidArgument
        case .messageEncodeFailed, .messageDecodeFailed:
            return PolarErrorCode.bluetoothError
        case .dateTimeFormatFailed:
            return PolarErrorCode.invalidArgument
        case .polarBleSdkInternalException, .deviceError, .polarOfflineRecordingError:
            return PolarErrorCode.bluetoothError
        @unknown default:
            // Handle any new error cases added in future SDK versions
            return PolarErrorCode.bluetoothError
        }
    }
    
    // Fallback to string matching for other error types
    let errorDescription = error.localizedDescription.lowercased()
    if errorDescription.contains("timeout") {
        return PolarErrorCode.timeout
    } else if errorDescription.contains("bluetooth") || errorDescription.contains("106") {
        return PolarErrorCode.bluetoothError
    }
    
    return PolarErrorCode.bluetoothError
  }



  func deleteDeviceDateFolders(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let api = api else {
      result(FlutterError(
        code: PolarErrorCode.bluetoothError,
        message: "API not initialized",
        details: nil))
      return
    }
    
    guard let args = call.arguments as? [Any],
          let identifier = args[0] as? String,
          let fromDateStr = args[1] as? String,
          let toDateStr = args[2] as? String else {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Invalid arguments",
        details: nil))
      return
    }
    
    // Parse the date strings (YYYY-MM-DD format)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    
    guard let fromDate = dateFormatter.date(from: fromDateStr),
          let toDate = dateFormatter.date(from: toDateStr) else {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Invalid date format. Expected YYYY-MM-DD",
        details: nil))
      return
    }
    
    print("[PolarPlugin] deleteDeviceDateFolders called with fromDate=\(fromDate), toDate=\(toDate)")
    
    _ = api.deleteDeviceDateFolders(identifier, fromDate: fromDate, toDate: toDate).subscribe(
      onCompleted: {
        print("[PolarPlugin] deleteDeviceDateFolders completed successfully")
        result(nil)
      },
      onError: { error in
        print("[PolarPlugin] deleteDeviceDateFolders error: \(error.localizedDescription)")
        
        let errorCode: String
        if error.localizedDescription.lowercased().contains("timeout") {
          errorCode = PolarErrorCode.timeout
        } else if error.localizedDescription.lowercased().contains("no such file") {
          errorCode = "NO_SUCH_FILE_OR_DIRECTORY"
        } else {
          errorCode = self.mapErrorCode(error)
        }
        
        result(FlutterError(
          code: errorCode,
          message: error.localizedDescription,
          details: nil))
      }
    )
  }

  func deleteStoredDeviceData(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let api = api else {
      result(FlutterError(
        code: PolarErrorCode.bluetoothError,
        message: "API not initialized",
        details: nil))
      return
    }
    
    guard let args = call.arguments as? [Any],
          let identifier = args[0] as? String,
          let dataTypeStr = args[1] as? String,
          let untilDateStr = args[2] as? String else {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Invalid arguments",
        details: nil))
      return
    }
    
    // Parse the date string (YYYY-MM-DD format)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    
    guard let untilDate = dateFormatter.date(from: untilDateStr) else {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Invalid date format. Expected YYYY-MM-DD",
        details: nil))
      return
    }
    
    // Convert string to PolarStoredDataType
    let dataType = mapStringToStoredDataType(dataTypeStr)
    
    print("[PolarPlugin] deleteStoredDeviceData called with identifier=\(identifier), dataType=\(dataTypeStr), until=\(untilDate)")
    
    _ = api.deleteStoredDeviceData(identifier, dataType: dataType, until: untilDate).subscribe(
      onCompleted: {
        print("[PolarPlugin] deleteStoredDeviceData completed successfully for \(dataTypeStr)")
        result(nil)
      },
      onError: { error in
        print("[PolarPlugin] deleteStoredDeviceData error for \(dataTypeStr): \(error.localizedDescription)")
        
        let errorCode: String
        if error.localizedDescription.lowercased().contains("timeout") {
          errorCode = PolarErrorCode.timeout
        } else if error.localizedDescription.lowercased().contains("no such file") {
          errorCode = "NO_SUCH_FILE_OR_DIRECTORY"
        } else {
          errorCode = self.mapErrorCode(error)
        }
        
        result(FlutterError(
          code: errorCode,
          message: error.localizedDescription,
          details: nil))
      }
    )
  }
  
  private func mapStringToStoredDataType(_ dataTypeStr: String) -> PolarStoredDataType.StoredDataType {
    switch dataTypeStr {
    case "ACTIVITY":
      return PolarStoredDataType.StoredDataType.ACTIVITY
    case "AUTO_SAMPLE":
      return PolarStoredDataType.StoredDataType.AUTO_SAMPLE
    case "DAILY_SUMMARY":
      return PolarStoredDataType.StoredDataType.DAILY_SUMMARY
    case "NIGHTLY_RECOVERY":
      return PolarStoredDataType.StoredDataType.NIGHTLY_RECOVERY
    case "SDLOGS":
      return PolarStoredDataType.StoredDataType.SDLOGS
    case "SLEEP":
      return PolarStoredDataType.StoredDataType.SLEEP
    case "SLEEP_SCORE":
      return PolarStoredDataType.StoredDataType.SLEEP_SCORE
    case "SKIN_CONTACT_CHANGES":
      return PolarStoredDataType.StoredDataType.SKIN_CONTACT_CHANGES
    case "SKIN_TEMP":
      return PolarStoredDataType.StoredDataType.SKINTEMP
    default:
      return PolarStoredDataType.StoredDataType.ACTIVITY // Default fallback
    }
  }

  func setOfflineRecordingTrigger(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let api = api else {
      result(FlutterError(
        code: PolarErrorCode.bluetoothError,
        message: "API not initialized",
        details: nil))
      return
    }
    
    guard let args = call.arguments as? [Any],
          let identifier = args[0] as? String,
          let triggerJson = args[1] as? String else {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Invalid arguments",
        details: nil))
      return
    }
    
    do {
      guard let triggerData = triggerJson.data(using: .utf8),
            let triggerDict = try JSONSerialization.jsonObject(with: triggerData) as? [String: Any],
            let triggerFeaturesDict = triggerDict["triggerFeatures"] as? [String: Any?] else {
        result(FlutterError(
          code: PolarErrorCode.invalidArgument,
          message: "Invalid trigger JSON format",
          details: nil))
        return
      }
      
      // Convert trigger mode - now using consistent strings across platforms
      let triggerMode: PolarOfflineRecordingTriggerMode
      if let triggerModeString = triggerDict["triggerMode"] as? String {
        switch triggerModeString {
        case "triggerDisabled":
          triggerMode = .triggerDisabled
        case "triggerSystemStart":
          triggerMode = .triggerSystemStart
        case "triggerExerciseStart":
          triggerMode = .triggerExerciseStart
        default:
          result(FlutterError(
            code: PolarErrorCode.invalidArgument,
            message: "Unknown trigger mode: \(triggerModeString)",
            details: nil))
          return
        }
      } else {
        result(FlutterError(
          code: PolarErrorCode.invalidArgument,
          message: "triggerMode must be a string",
          details: nil))
        return
      }
      
      // Convert trigger features
      var triggerFeatures: [PolarDeviceDataType: PolarSensorSetting?] = [:]
      for (dataTypeString, settingsValue) in triggerFeaturesDict {
        let dataType: PolarDeviceDataType
        switch dataTypeString {
        case "ppi":
          dataType = .ppi
        case "hr":
          dataType = .hr
        case "ecg":
          dataType = .ecg
        case "acc":
          dataType = .acc
        case "ppg":
          dataType = .ppg
        case "gyro":
          dataType = .gyro
        case "magnetometer":
          dataType = .magnetometer
        case "temperature":
          dataType = .temperature
        case "pressure":
          dataType = .pressure
        default:
          result(FlutterError(
            code: PolarErrorCode.invalidArgument,
            message: "Unknown data type: \(dataTypeString)",
            details: nil))
          return
        }
        
        // For PPI and HR, settings should be nil
        let settings: PolarSensorSetting?
        if settingsValue != nil && dataType != .ppi && dataType != .hr {
          // Parse settings if provided and not for PPI/HR
          settings = nil // For now, we'll set this to nil since settings parsing is complex
        } else {
          settings = nil
        }
        
        triggerFeatures[dataType] = settings
      }
      
      let trigger = PolarOfflineRecordingTrigger(triggerMode: triggerMode, triggerFeatures: triggerFeatures)
      
      _ = api.setOfflineRecordingTrigger(identifier, trigger: trigger, secret: nil).subscribe(
        onCompleted: {
          result(nil)
        },
        onError: { error in
          let errorCode = self.mapErrorCode(error)
          result(FlutterError(
            code: errorCode,
            message: error.localizedDescription,
            details: nil))
        }
      )
    } catch {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Failed to parse trigger JSON: \(error.localizedDescription)",
        details: nil))
    }
  }

  func doRestart(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let api = api else {
      result(FlutterError(
        code: PolarErrorCode.bluetoothError,
        message: "API not initialized",
        details: nil))
      return
    }
    
    guard let args = call.arguments as? [Any],
          let identifier = args[0] as? String,
          let preservePairingInformation = args[1] as? Bool else {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Invalid arguments",
        details: nil))
      return
    }
    
    _ = api.doRestart(identifier, preservePairingInformation: preservePairingInformation).subscribe(
      onCompleted: {
        result(nil)
      },
      onError: { error in
        let errorCode = self.mapErrorCode(error)
        result(FlutterError(
          code: errorCode,
          message: error.localizedDescription,
          details: nil))
      }
    )
  }
  
  
  func updateFirmware(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let api = api else {
      result(FlutterError(
        code: PolarErrorCode.bluetoothError,
        message: "API not initialized",
        details: nil))
      return
    }
    
    guard let args = call.arguments as? [Any],
          let identifier = args[0] as? String,
          let firmwareUrl = args[1] as? String else {
      result(FlutterError(
        code: PolarErrorCode.invalidArgument,
        message: "Invalid arguments",
        details: nil))
      return
    }
    
    // Start firmware update and stream events
    let updateObservable: Observable<FirmwareUpdateStatus>
    if firmwareUrl.isEmpty {
      updateObservable = api.updateFirmware(identifier)
    } else if let firmwareURL = URL(string: firmwareUrl) {
      updateObservable = api.updateFirmware(identifier, fromFirmwareURL: firmwareURL)
    } else {
      updateObservable = Observable.error(NSError(domain: "PolarPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid firmware URL"]))
    }
    
    firmwareUpdateSubscription = updateObservable.subscribe(
      onNext: { [weak self] status in
        guard let self = self else { return }
        
        let statusString: String
        let details: String
        
        switch status {
        case .fetchingFwUpdatePackage(let statusDetails):
          statusString = "fetchingFwUpdatePackage"
          details = statusDetails
        case .preparingDeviceForFwUpdate(let statusDetails):
          statusString = "preparingDeviceForFwUpdate"
          details = statusDetails
        case .writingFwUpdatePackage(let statusDetails):
          statusString = "writingFwUpdatePackage"
          details = statusDetails
        case .finalizingFwUpdate(let statusDetails):
          statusString = "finalizingFwUpdate"
          details = statusDetails
        case .fwUpdateCompletedSuccessfully(let statusDetails):
          statusString = "fwUpdateCompletedSuccessfully"
          details = statusDetails
        case .fwUpdateNotAvailable(let statusDetails):
          statusString = "fwUpdateNotAvailable"
          details = statusDetails
        case .fwUpdateFailed(let statusDetails):
          statusString = "fwUpdateFailed"
          details = statusDetails
        }
        
        let statusMap: [String: Any] = [
          "status": statusString,
          "details": details
        ]
        
        DispatchQueue.main.async {
          self.firmwareUpdateEvents?(statusMap)
        }
      },
      onError: { [weak self] error in
        guard let self = self else { return }
        
        let errorCode = self.mapErrorCode(error)
        DispatchQueue.main.async {
          self.firmwareUpdateEvents?(FlutterError(
            code: errorCode,
            message: error.localizedDescription,
            details: nil))
        }
      },
      onCompleted: { [weak self] in
        guard let self = self else { return }
        
        DispatchQueue.main.async {
          self.firmwareUpdateEvents?(FlutterEndOfEventStream)
        }
      }
    )
    
    // Return success immediately to indicate the update process has started
    result(nil)
  }
}

// Add this extension after the main class implementation to provide default implementations
// for any other methods that might be required but we're unaware of
extension SwiftPolarPlugin {
  // Catch-all method for any protocol methods we haven't explicitly implemented
  @objc internal func deviceTimeFeatureReady(_ identifier: String) {
    // Default empty implementation
    invokeMethod("deviceTimeFeatureReady", arguments: [identifier])
  }
  
  @objc internal func deviceSetTimeSuccess(_ identifier: String) {
    // Default empty implementation
    invokeMethod("deviceSetTimeSuccess", arguments: [identifier])
  }
  
  @objc internal func deviceSetTimeFailed(_ identifier: String, error: Error) {
    // Default empty implementation
    invokeMethod("deviceSetTimeFailed", arguments: [identifier, error.localizedDescription])
  }
  
  // For SDK 6.0.0 USB port support
  @objc internal func usbFeatureReady(_ identifier: String) {
    // Default empty implementation
    invokeMethod("usbFeatureReady", arguments: [identifier])
  }
  
  @objc internal func usbStatusReceived(_ identifier: String, status: Bool) {
    // Default empty implementation for USB status
    invokeMethod("usbStatusReceived", arguments: [identifier, status])
  }
}

class StreamHandler: NSObject, FlutterStreamHandler {
  let onListen: (Any?, @escaping FlutterEventSink) -> FlutterError?
  let onCancel: (Any?) -> FlutterError?

  init(
    onListen: @escaping (Any?, @escaping FlutterEventSink) -> FlutterError?,
    onCancel: @escaping (Any?) -> FlutterError?
  ) {
    self.onListen = onListen
    self.onCancel = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    return onListen(arguments, events)
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return onCancel(arguments)
  }
}

protocol AnyObservable {
  func anySubscribe(
    onNext: ((Any) -> Void)?,
    onError: ((Swift.Error) -> Void)?,
    onCompleted: (() -> Void)?
  ) -> Disposable
}

extension Observable: AnyObservable {
  public func anySubscribe(
    onNext: ((Any) -> Void)? = nil,
    onError: ((Swift.Error) -> Void)? = nil,
    onCompleted: (() -> Void)? = nil
  ) -> Disposable {
    subscribe(onNext: onNext, onError: onError, onCompleted: onCompleted)
  }
}

class StreamingChannel: NSObject, FlutterStreamHandler {
  let api: PolarBleApi
  let identifier: String
  let feature: PolarDeviceDataType
  let channel: FlutterEventChannel

  var subscription: Disposable?

  init(
    _ messenger: FlutterBinaryMessenger, _ name: String, _ api: PolarBleApi, _ identifier: String,
    _ feature: PolarDeviceDataType
  ) {
    self.api = api
    self.identifier = identifier
    self.feature = feature
    self.channel = FlutterEventChannel(name: name, binaryMessenger: messenger)

    super.init()

    channel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    // Will be null for some features
    let settings = try? decoder.decode(
      PolarSensorSettingCodable.self,
      from: (arguments as! String)
        .data(using: .utf8)!
    ).data

    let stream: AnyObservable
    switch feature {
    case .ecg:
      stream = api.startEcgStreaming(identifier, settings: settings!)
    case .acc:
      stream = api.startAccStreaming(identifier, settings: settings!)
    case .ppg:
      stream = api.startPpgStreaming(identifier, settings: settings!)
    case .ppi:
      stream = api.startPpiStreaming(identifier)
    case .gyro:
      stream = api.startGyroStreaming(identifier, settings: settings!)
    case .magnetometer:
      stream = api.startMagnetometerStreaming(identifier, settings: settings!)
    case .hr:
      stream = api.startHrStreaming(identifier)
    case .temperature:
      stream = api.startTemperatureStreaming(identifier, settings: settings!)
    case .pressure:
      stream = api.startPressureStreaming(identifier, settings: settings!)
    case .skinTemperature:
        stream = api.startSkinTemperatureStreaming(identifier, settings: settings!)
    }

    subscription = stream.anySubscribe(
      onNext: { data in
        guard let data = jsonEncode(PolarDataCodable(data)) else {
          return
        }
        DispatchQueue.main.async {
          events(data)
        }
      },
      onError: { error in
        DispatchQueue.main.async {
          events(
            FlutterError(
              code: "Error while streaming", message: error.localizedDescription, details: nil))
        }
      },
      onCompleted: {
        DispatchQueue.main.async {
          events(FlutterEndOfEventStream)
        }
      })

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    subscription?.dispose()
    return nil
  }

  func dispose() {
    subscription?.dispose()
    channel.setStreamHandler(nil)
  }
}
