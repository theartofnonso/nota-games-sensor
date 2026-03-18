/// Generates Agora channel name for 1:1 calls between two users.
/// Must be identical for caller and callee so they join the same channel.
String generateVideoCallChannelName(String userId1, String userId2) {
  final ids = [userId1, userId2]..sort();
  final half = (64 - 6) ~/ 2; // 64 max - 'call_' prefix
  final a = ids[0].replaceAll('-', '').substring(0, half.clamp(0, 32));
  final b = ids[1].replaceAll('-', '').substring(0, half.clamp(0, 32));
  return 'call_${a}_$b';
}
