DateTime? tryFromSecondsSinceEpoch(int? secondsSinceEpoch, {bool isUtc = false}) {
  if (secondsSinceEpoch == null || secondsSinceEpoch == -1) {
    return null;
  }

  final milliSeconds = secondsSinceEpoch * 1000;
  try {
    return DateTime.fromMillisecondsSinceEpoch(milliSeconds, isUtc: isUtc);
  } catch (e) {
    return null;
  }
}
