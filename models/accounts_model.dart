// /models/authModel.dart

import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:mysql1/mysql1.dart';
import 'package:shelf/shelf.dart';
import 'dart:async';
import '../database_connection.dart' as database;
import 'utils.dart';

Future<Response> addAccount(Map<String, dynamic> accountInfo) async {
  if (!isValidCredentials(accountInfo)) {
    // Guard statement, return error/fail
    // TODO Validate with regex
  }

  MySqlConnection dbConnection = await database.createConnection();

  final String salt = generateSalt();
  final String hashedPassword = hashPassword(accountInfo['password'], salt);

  // Add the account, if not unique an error is returned which we can catch
  try {
    Results result = await dbConnection.query(
        'INSERT INTO account (username, first_name, last_name, password, salt) ' +
            'VALUE (?, ?, ?, ?, ?)',
        [
          accountInfo['username'],
          accountInfo['first_name'],
          accountInfo['last_name'],
          hashedPassword,
          salt,
        ]);

    print('User inserted. Affected rows: ${result.affectedRows}');
    return Response(HttpStatus.created, body: 'Account registered.');
  } on MySqlException catch (e) {
    print(e);
    // Duplicate entry error
    if (e.errorNumber == 1062) {
      return Response(HttpStatus.conflict, body: "Username already exists!");
    }
    // Other MySqlException errors
    return Response.internalServerError(body: e.message);
  } catch (e) {
    print(e);
    if (e is TimeoutException || e is SocketException) {
      return Response.internalServerError(
          body: 'Connection failed. Please try again later.');
    }
    // Catch-all other exceptions
    return Response.internalServerError(
        body: 'Something went wrong on our end. Please try again later.');
  } finally {
    dbConnection.close();
  }
}

Future<Response> loginAccount(String username, String password) async {
  //if (!isValidCredentials(accountInfo)) {
  // Guard statement, return error/fail
  // TODO Validate with regex
  //}

  MySqlConnection dbConnection = await database.createConnection();

  // Get the account if it exists
  try {
    Results results = await dbConnection
        .query('SELECT * FROM account WHERE username = ?', [username]);

    Iterator iterator = results.iterator;
    if (!iterator.moveNext()) {
      return Response.notFound('Username does not exist.');
    }
    // Username found. Compare password.
    final account = iterator.current;
    final hashedPassword = hashPassword(password, account['salt']);

    if (hashedPassword != account['password']) {
      return Response.forbidden("Wrong username or password.");
    }

    // Generate JWT to return with response
    final jwt = generateJwt(account['account_id'].toString());

    return Response.ok(json.encode({'jwt': jwt}), headers: {
      HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
    });

    //} on MySqlException catch (e) {
    //print(e);
    //return Response.internalServerError(body: e.message);
  } catch (e) {
    print(e);
    if (e is TimeoutException || e is SocketException) {
      return Response.internalServerError(
          body: 'Connection failed. Please try again later.');
    }
    // Catch-all other exceptions
    return Response.internalServerError(
        body: 'Something went wrong on our end. Please try again later.');
  } finally {
    dbConnection.close();
  }
}

bool isValidCredentials(Map<String, dynamic> userInfo) {
  // TODO
  return true;
}
