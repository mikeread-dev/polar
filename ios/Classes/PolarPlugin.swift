// Add to handleMethodCall
case "getSleep":
    getSleep(call: call, result: result)

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
            result(nil)
            return
        }
        
        do {
            let jsonData = try JSONEncoder().encode(sleepData)
            let jsonString = String(data: jsonData, encoding: .utf8)
            result(jsonString)
        } catch {
            result(FlutterError(code: "JSON_ENCODING_ERROR",
                              message: error.localizedDescription,
                              details: nil))
        }
    }
}