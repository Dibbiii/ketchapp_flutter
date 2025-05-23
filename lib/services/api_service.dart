import 'dart:convert';
import 'package:http/http.dart' as http;
import './api_exceptions.dart';

class ApiService {
  final String _baseUrl = "http://37.103.87.3:8080/api";

  Future<dynamic> _processResponse(http.Response response) {
    final body = response.body;
    dynamic decodedJson;
    try {
      decodedJson = json.decode(body);
    } catch (e) {
      // TODO: Se il corpo non è JSON valido o è vuoto per alcuni successi (es. 204 No Content)
      // gestisci di conseguenza. Per ora, se non è 2xx, lanciamo un errore.
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        return Future.value(decodedJson ?? body); 
      case 400:
        throw BadRequestException(decodedJson?['message'] ?? 'Richiesta non valida');
      case 401:
        throw UnauthorizedException(decodedJson?['message'] ?? 'Non autorizzato');
      case 403:
        throw ForbiddenException(decodedJson?['message'] ?? 'Accesso negato');
      case 404:
        throw NotFoundException(decodedJson?['message'] ?? 'Risorsa non trovata');
      case 409: // Conflict
        throw UserAlreadyExistsException(decodedJson?['message'] ?? 'L\'utente esiste già.');
      case 500:
        throw InternalServerErrorException(decodedJson?['message'] ?? 'Errore interno del server');
      default:
        throw ApiException(
            'Errore durante la comunicazione con il server: ${response.statusCode}',
            response.statusCode);
    }
  }

  Future<dynamic> fetchData(String endpoint) async {
    final response = await http.get(Uri.parse('$_baseUrl/$endpoint')); 
    return _processResponse(response);
  }

  Future<dynamic> postData(String endpoint, Map<String, dynamic> data) async { 
    final response = await http.post(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 409) { // HTTP 409 Conflict - Gestione personalizzata per postData
      final responseBody = json.decode(response.body);
      // Supponiamo che il backend restituisca un campo 'error_code' o 'message'
      // per distinguere il tipo di conflitto.
      final String? errorCode = responseBody['error_code'] as String?;
      final String message = responseBody['message'] as String? ?? 'Risorsa già esistente.';

      if (errorCode == 'USERNAME_TAKEN' || message.toLowerCase().contains('username')) {
        throw UsernameAlreadyExistsException(message);
      } else if (errorCode == 'EMAIL_TAKEN_BACKEND' || message.toLowerCase().contains('email')) {
        throw EmailAlreadyExistsInBackendException(message);
      }
      // Se è un 409 ma non specificamente username/email duplicato, lancia una ConflictException generica
      throw ConflictException(message);
    } else {
      // Per tutti gli altri stati di errore, usa il metodo generico _processResponse
      return _processResponse(response);
    }
  }

  Future<dynamic> deleteData(String endpoint) async {
    final response = await http.delete(Uri.parse('$_baseUrl/$endpoint'));
    return _processResponse(response);
  }

  Future<dynamic> findEmailByUsername(String username) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/email/$username'));
    return _processResponse(response);
  }
  
  
  // Implementa metodi simili per PUT, DELETE, ecc., usando _processResponse
}