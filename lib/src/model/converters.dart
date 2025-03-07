import 'package:json_annotation/json_annotation.dart';

/// A JSON converter that transforms between [Duration] and integer milliseconds.
///
/// This converter is used with the `@JsonSerializable` annotation to automatically
/// convert Duration objects to/from JSON. It stores durations as milliseconds in JSON.
///
/// Example usage:
/// ```dart
/// @JsonSerializable()
/// class MyClass {
///   @DurationConverter()
///   final Duration duration;
///
///   MyClass(this.duration);
/// }
/// ```
class DurationConverter implements JsonConverter<Duration, int> {
  /// Creates a [DurationConverter] that converts between [Duration] and milliseconds.
  const DurationConverter();

  @override
  Duration fromJson(int json) => Duration(milliseconds: json);

  @override
  int toJson(Duration duration) => duration.inMilliseconds;
}
