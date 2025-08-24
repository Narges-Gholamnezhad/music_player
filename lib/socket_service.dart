import 'dart:async';
import 'dart:io';
import 'dart:convert'; // برای استفاده از utf8

class SocketService {
  // IP آدرس سرور شما
  // ---------------------------------------------------------------------
  // برای شبیه‌ساز اندروید از '10.0.2.2' استفاده کنید.
  // برای شبیه‌ساز iOS یا دستگاه فیزیکی، IP کامپیوترتان را وارد کنید (مثلاً '192.168.1.5').
  // ---------------------------------------------------------------------
  static const String _serverIp = '10.206.20.213';
  static const int _serverPort = 12345;

  Socket? _socket;
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();

  // یک استریم عمومی که بقیه بخش‌های برنامه می‌توانند به آن گوش دهند
  Stream<String> get responses => _responseController.stream;

  // متد برای اتصال به سرور
  Future<bool> connect() async {
    // اگر از قبل وصل هستیم، دوباره وصل نشو
    if (_socket != null && _socket?.remoteAddress != null) {
      print('SocketService: Already connected.');
      return true;
    }

    try {
      print(
          'SocketService: Attempting to connect to $_serverIp:$_serverPort...');
      _socket = await Socket.connect(_serverIp, _serverPort,
          timeout: const Duration(seconds: 5));
      print('SocketService: Connection successful!');

      // گوش دادن به داده‌های دریافتی از سرور
      _socket!.listen(
        (List<int> data) {
          // استفاده از utf8.decode برای پشتیبانی بهتر از کاراکترها
          final serverResponse = utf8.decode(data).trim();
          if (serverResponse.isNotEmpty) {
            print('SocketService: Received raw data: $serverResponse');
            _responseController.add(serverResponse);
          }
        },
        onError: (error) {
          print('SocketService: Connection Error: $error');
          disconnect();
        },
        onDone: () {
          print('SocketService: Server disconnected.');
          disconnect();
        },
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      print('SocketService: Failed to connect: $e');
      _socket = null;
      return false;
    }
  }

  // متد برای ارسال دستور به سرور
  void sendCommand(String command) {
    if (_socket != null) {
      print('SocketService: Sending command: $command');
      _socket!.writeln(command); // writeln خودش \n را اضافه می‌کند
    } else {
      print('SocketService: Cannot send command. Socket is not connected.');
    }
  }

  // متد برای قطع اتصال
  void disconnect() {
    if (_socket != null) {
      _socket!.destroy();
      _socket = null;
      print('SocketService: Connection destroyed.');
    }
    // بستن کنترلر استریم وقتی دیگر لازم نیست (مثلا در dispose برنامه اصلی)
    // _responseController.close();
  }

  // این بخش برای این است که در کل برنامه فقط یک نمونه از این کلاس داشته باشیم (Singleton)
  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();
}
