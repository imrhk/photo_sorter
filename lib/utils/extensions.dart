import 'package:equatable/equatable.dart';

mixin DefaultOverrides on Equatable {
  @override
  List<Object?> get props => [];

  @override
  bool? get stringify => true;
}

extension StringExtensions on String {
  String capitalize() {
    if (isNotEmpty) {
      StringBuffer stringBuffer = StringBuffer();
      stringBuffer.write(substring(0, 1).toUpperCase());
      if (length > 1) {
        stringBuffer.write(substring(1, length).toLowerCase());
      }
      return stringBuffer.toString();
    }
    return this;
  }
}
