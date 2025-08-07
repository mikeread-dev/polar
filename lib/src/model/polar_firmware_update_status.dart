/// Polar firmware update status
enum PolarFirmwareUpdateStatus {
  /// Fetching firmware update package
  fetchingFwUpdatePackage,
  
  /// Preparing device for firmware update
  preparingDeviceForFwUpdate,
  
  /// Writing firmware update package to device
  writingFwUpdatePackage,
  
  /// Finalizing firmware update
  finalizingFwUpdate,
  
  /// Firmware update completed successfully
  fwUpdateCompletedSuccessfully,
  
  /// Firmware update not available
  fwUpdateNotAvailable,
  
  /// Firmware update failed
  fwUpdateFailed;

  /// Create a [PolarFirmwareUpdateStatus] from json
  static PolarFirmwareUpdateStatus fromJson(dynamic json) {
    final statusString = (json as String).toLowerCase();
    
    switch (statusString) {
      case 'fetchingfwupdatepackage':
        return PolarFirmwareUpdateStatus.fetchingFwUpdatePackage;
      case 'preparingdeviceforfwupdate':
        return PolarFirmwareUpdateStatus.preparingDeviceForFwUpdate;
      case 'writingfwupdatepackage':
        return PolarFirmwareUpdateStatus.writingFwUpdatePackage;
      case 'finalizingfwupdate':
        return PolarFirmwareUpdateStatus.finalizingFwUpdate;
      case 'fwupdatecompletedsuccess':
      case 'fwupdatecompletedsuccessfully':
        return PolarFirmwareUpdateStatus.fwUpdateCompletedSuccessfully;
      case 'fwupdatenotavailable':
        return PolarFirmwareUpdateStatus.fwUpdateNotAvailable;
      case 'fwupdatefailed':
        return PolarFirmwareUpdateStatus.fwUpdateFailed;
      default:
        throw ArgumentError('Unknown firmware update status: $json');
    }
  }
}

/// Polar firmware update event containing status and details
class PolarFirmwareUpdateEvent {
  /// The update status
  final PolarFirmwareUpdateStatus status;
  
  /// Additional details about the status
  final String details;
  
  /// Constructor
  const PolarFirmwareUpdateEvent({
    required this.status,
    required this.details,
  });
  
  /// Create from JSON
  factory PolarFirmwareUpdateEvent.fromJson(Map<String, dynamic> json) {
    final event = PolarFirmwareUpdateEvent(
      status: PolarFirmwareUpdateStatus.fromJson(json['status']),
      details: json['details'] as String,
    );
    return event;
  }
  
  @override
  String toString() {
    return 'PolarFirmwareUpdateEvent(status: $status, details: $details)';
  }
}