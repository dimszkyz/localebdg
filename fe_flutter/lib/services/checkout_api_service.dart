import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class CheckoutApiService {
  // Mengambil baseUrl dinamis dari ApiService bawaan Anda
  static String get baseUrl => ApiService.baseUrl;

  /// Mengirim data transaksi checkout ke backend Laravel
  static Future<Map<String, dynamic>?> checkout({
    required String address,
    required String phone,
    required String provinceName,
    required String cityName,
    required String courier,
    required double shippingCost,
    required List<Map<String, dynamic>> cartItems,
    required String paymentType,
    String? bankCode,
  }) async {
    // URL default tanpa garis miring di akhir
    final urlNoSlash = Uri.parse('$baseUrl/checkout');
    // URL fallback dengan garis miring di akhir untuk membypass redirect Apache/Nginx
    final urlWithSlash = Uri.parse('$baseUrl/checkout/');
    
    debugPrint("🚨 [LOUD DEBUG] CheckoutApiService.checkout() TELAH DIPANGGIL!");
    debugPrint("📡 [LOUD DEBUG] URL TARGET: $urlNoSlash");

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // SISTEM PENCARIAN TOKEN BERLAPIS
      final token = prefs.getString('token') ?? 
                    prefs.getString('auth_token') ?? 
                    prefs.getString('access_token') ?? 
                    ApiService.token;
      
      debugPrint("🔑 [LOUD DEBUG] Token Terpilih: ${token != null ? 'Ada (Mulai dengan: ${token.substring(0, token.length > 10 ? 10 : token.length)}...)' : 'KOSONG / NULL'}");
      
      if (token == null) {
        debugPrint("❌ [LOUD DEBUG] Gagal mengirim checkout: Token otorisasi NULL.");
        return null;
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final Map<String, dynamic> payload = {
        'address': address,
        'phone': phone,
        'province_name': provinceName,
        'city_name': cityName,
        'courier': courier,
        'shipping_cost': shippingCost.toInt(),
        'items': cartItems,
        'payment_type': paymentType,
        'bank': bankCode,
      };

      debugPrint("📡 [LOUD DEBUG] HTTP Headers: $headers");
      debugPrint("📡 [LOUD DEBUG] HTTP Payload Body: ${json.encode(payload)}");

      // PERCOBAAN PERTAMA: Mengirim ke rute tanpa garis miring
      debugPrint("📡 [LOUD DEBUG] Mencoba mengirim HTTP POST Request (Tanpa garis miring)...");
      var response = await http.post(
        urlNoSlash,
        headers: headers,
        body: json.encode(payload),
      );

      debugPrint("📡 [LOUD DEBUG] HTTP Response Status Code: ${response.statusCode}");

      // LOGIKA PENYELAMATAN JIKA TERJADI REDIRECT / METHOD NOT ALLOWED (HTTP 405)
      if (response.statusCode == 405) {
        debugPrint("⚠️ [LOUD DEBUG] Server merespons 405 (Method Not Allowed).");
        debugPrint("⚠️ [LOUD DEBUG] Mendeteksi adanya trailing slash redirect otomatis oleh server hosting!");
        debugPrint("🔄 [LOUD DEBUG] Melakukan fallback instan dengan menembak POST langsung ke URL: $urlWithSlash");
        
        response = await http.post(
          urlWithSlash,
          headers: headers,
          body: json.encode(payload),
        );
        
        debugPrint("📡 [LOUD DEBUG] Fallback HTTP Response Status Code: ${response.statusCode}");
      }

      debugPrint("📡 [LOUD DEBUG] HTTP Response Body Mentah Akhir: ${response.body}");
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decodedData = json.decode(response.body);
        debugPrint("📥 [LOUD DEBUG] Respons sukses 200/201 diterima dari server.");
        return decodedData;
      } else {
        debugPrint("❌ [LOUD DEBUG] ERROR SERVER TERDETEKSI!");
        debugPrint("❌ [LOUD DEBUG] Detail Status Code: ${response.statusCode}");
        debugPrint("❌ [LOUD DEBUG] Respons Mentah Server: ${response.body}");
        return null;
      }
    } catch (e, stacktrace) {
      debugPrint("❌ [LOUD DEBUG] EXCEPTION TERJADI DI FLUTTER: $e");
      debugPrint("❌ [LOUD DEBUG] Stacktrace: $stacktrace");
      return null;
    }
  }

  /// Mengecek status transaksi terbaru pesanan di backend Laravel
  static Future<Map<String, dynamic>?> checkOrderStatus(String orderId) async {
    final urlNoSlash = Uri.parse('$baseUrl/order/$orderId/status');
    final urlWithSlash = Uri.parse('$baseUrl/order/$orderId/status/');
    
    debugPrint("📡 [LOUD DEBUG] Memulai request GET status ke: $urlNoSlash");

    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('token') ?? 
                    prefs.getString('auth_token') ?? 
                    prefs.getString('access_token') ?? 
                    ApiService.token;

      if (token == null) {
        debugPrint("❌ [LOUD DEBUG] Token otorisasi NULL.");
        return null;
      }

      final Map<String, String> headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var response = await http.get(
        urlNoSlash,
        headers: headers,
      );

      debugPrint("📡 [LOUD DEBUG] Status respons cek status: ${response.statusCode}");
      
      // Fallback trailing slash untuk cek status jika merespons 405 atau 301
      if (response.statusCode == 405) {
        debugPrint("🔄 [LOUD DEBUG] Cek status dialihkan oleh server, mencoba ulang ke: $urlWithSlash");
        response = await http.get(
          urlWithSlash,
          headers: headers,
        );
        debugPrint("📡 [LOUD DEBUG] Fallback Status respons cek status: ${response.statusCode}");
      }
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        return decodedData;
      } else {
        debugPrint("❌ [LOUD DEBUG] Gagal cek status. Status: ${response.statusCode}, Body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ [LOUD DEBUG] Gagal cek status karena Exception: $e");
      return null;
    }
  }
}