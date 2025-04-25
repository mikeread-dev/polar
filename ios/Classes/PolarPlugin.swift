// Add to handleMethodCall
case "getSleep":
    getSleep(call: call, result: result)
case "stopSleepRecording":
    stopSleepRecording(call: call, result: result)

// Add new method
private func getSleep(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [Any],
          let identifier = arguments[0] as? String,
          let fromDateString = arguments[1] as? String,
          let toDateString = arguments[2] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", 
                           message: "Invalid arguments for getSleep", 
                           details: nil))
        return
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    guard let fromDate = dateFormatter.date(from: fromDateString),
          let toDate = dateFormatter.date(from: toDateString) else {
        result(FlutterError(code: "INVALID_DATE_FORMAT", 
                           message: "Invalid date format", 
                           details: nil))
        return
    }
    
    api.getSleep(identifier: identifier, 
                 fromDate: fromDate, 
                 toDate: toDate) { sleepData, error in
        if let error = error {
            result(FlutterError(code: "ERROR_GETTING_SLEEP_DATA",
                              message: error.localizedDescription,
                              details: nil))
            return
        }
        
        guard let sleepData = sleepData else {
            result([])  // Return empty array
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let jsonData = try encoder.encode(sleepData)
            let jsonString = String(data: jsonData, encoding: .utf8)
            result(jsonString)
        } catch {
            result(FlutterError(code: "JSON_ENCODING_ERROR",
                              message: error.localizedDescription,
                              details: nil))
        }
    }
}

// Add new function for stopSleepRecording
private func stopSleepRecording(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let identifier = call.arguments as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", 
                           message: "Expected a device identifier string", 
                           details: nil))
        return
    }
    
    api.stopSleepRecording(identifier: identifier)
        .subscribe(
            onCompleted: {
                result(nil)
            },
            onError: { error in
                let errorCode: String
                if let polarError = error as? PolarErrors {
                    switch polarError {
                    case .deviceDisconnected:
                        errorCode = "device_disconnected"
                    case .operationNotSupported:
                        errorCode = "not_supported"
                    case .timeout:
                        errorCode = "timeout"
                    default:
                        errorCode = "bluetooth_error"
                    }
                } else {
                    errorCode = "bluetooth_error"
                }
                
                result(FlutterError(code: errorCode,
                                   message: error.localizedDescription,
                                   details: nil))
            }
        )
        .disposed(by: disposeBag)
}
