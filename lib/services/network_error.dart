/// Nhận diện lỗi mạng từ lỗi mà tầng API ném ra.
///
/// `DatabaseService` bọc SocketException / TimeoutException thành
/// `Exception('Khong co ket noi mang...')`, còn trên web có thể là
/// `ClientException` / `Failed host lookup` / `XMLHttpRequest error`.
bool isNetworkError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('khong co ket noi mang') ||
      message.contains('no internet') ||
      message.contains('socketexception') ||
      message.contains('clientexception') ||
      message.contains('failed host lookup') ||
      message.contains('connection refused') ||
      message.contains('connection closed') ||
      message.contains('connection reset') ||
      message.contains('network is unreachable') ||
      message.contains('networkerror') ||
      message.contains('xmlhttprequest error') ||
      message.contains('handshakeexception') ||
      message.contains('timeoutexception') ||
      message.contains('timed out');
}
