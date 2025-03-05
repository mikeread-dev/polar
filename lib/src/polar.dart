import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:polar/src/model/polar_sleep.dart';

/// Retrieves sleep data for a given time period
/// 
/// [identifier] The device identifier
/// [fromDate] Start date for sleep data retrieval
/// [toDate] End date for sleep data retrieval
/// 
/// Returns a list of [PolarSleepData] containing sleep analysis results
Future<List<PolarSleepData>> getSleep(
    String identifier,
    DateTime fromDate,
    DateTime toDate,
) async {
    const methodChannel = MethodChannel('polar');
    final response = await methodChannel.invokeMethod<String>(
        'getSleep',
        [
            identifier,
            fromDate.toIso8601String().split('T')[0],
            toDate.toIso8601String().split('T')[0],
        ],
    );

    if (response == null) return [];
    
    try {
        final List<dynamic> jsonList = jsonDecode(response);
        return jsonList
            .map((json) => PolarSleepData.fromJson(json as Map<String, dynamic>))
            .toList();
    } catch (e) {
        // If we can't parse the response as a list, return empty list
        return [];
    }
}
