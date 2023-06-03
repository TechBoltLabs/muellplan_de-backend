import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:mysql1/mysql1.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf_cors;
import 'package:shelf_router/shelf_router.dart';

late final ConnectionSettings _dbSettingsLocal;
late final ConnectionSettings _dbSettingsProduction;
late final ConnectionSettings _dbSettings;

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/locations', _locationsHandler)
  ..get('/streets/<locationCode>', _streetsHandler)
  ..get('/collection-dates/<locationCode>/<streetCode>/<date>',
      _collectionDatesHandler);

Response _rootHandler(Request req) {
  return Response.ok("possible endpoints are:</br>"
      "'/locations</br>"
      "       --> this gets the locations from the db,</br>"
      "</br>"
      "'/streets/<locationCode>'</br>"
      "       --> this gets the street for the location with the provided locationCode,</br>"
      "</br>"
      "'/collection-dates/<locationCode>/<streetCode>/<date>'</br>"
      "       --> this gets all collection dates for the location and street with the provided Codes from the provided date to the future</br>");
}

Future<Response> _locationsHandler(Request request) async {
  // connect to the database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);
  // print('Connected to database');

  // query the database
  Results results =
      await conn.query('SELECT locationName, locationCode FROM locations');
  // print('Query executed');

  // close the connection
  await conn.close();
  // print('Connection closed');

  List<List<String>> locations = [];
  // iterate over the results
  for (var result in results) {
    locations.add([result[0].toString(), result[1].toString()]);
  }
  //
  // // transform the locations list to a format, where the single values will be enclosed in double-quotes
  // List<String> quotedLocationLists = locations.map((list){
  //   // transform the inner lists to quoted-string-lists
  //   List<String> quotedLocations = list.map((s)=> '"$s"').toList();
  //
  //   // join the inner list into a string with comma separation
  //   return '[${quotedLocations.join(', ')}]';
  // }).toList();
  //
  // // join the outer list with commas
  // String responseBody = quotedLocationLists.join(', ');

  // return the results
  return Response.ok(jsonEncode(locations));
}

Future<Response> _streetsHandler(Request request) async {
  final locationCode = request.params['locationCode'];

  String locationID = '';

  String selectLocationIDQuery =
      "select id from locations where locationCode=?;";
  String selectStreetsListQuery =
      "select streetName, streetCode from streets where location_id=?;";

  // connect to the database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);
  // print("Connected to database");

  // query the database
  Results results = await conn.query(selectLocationIDQuery, [locationCode]);
  locationID = results.first[0].toString();
  results = await conn.query(selectStreetsListQuery, [locationID]);
  // print("Query executed");

  // close the connection
  await conn.close();
  // print("Connection closed");

  // create a list of street-streetCode pairs
  List<List<String>> streets = [];

  for (var result in results) {
    streets.add([result[0].toString(), result[1].toString()]);
  }

  // return the streets
  // return Response.ok(streetsQuoted.toString());
  return Response.ok(jsonEncode(streets));
}

Future<Response> _collectionDatesHandler(Request request) async {
  final locationCode = request.params['locationCode'];
  final streetCode = request.params['streetCode'];
  final date = request.params['date'];

  String locationName, streetName;
  Map<String, List<String>> collectionDates = {};

  String selectLocationNameQuery =
      "select locationName from locations where locationCode=?;";
  String selectStreetNameQuery =
      "select streetName from streets where streetCode=?;";

  String selectCollectionDatesQuery =
      "select category, date from collectionDatesView "
      "where locationName = ? "
      "and streetName = ? "
      "and date >= ? "
      "order by date;";

  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);
  // print("connected to database");

  // query the database
  // get location name
  Results results = await conn.query(selectLocationNameQuery, [locationCode]);
  locationName = results.first[0].toString();

  // get street name
  results = await conn.query(selectStreetNameQuery, [streetCode]);
  streetName = results.first[0].toString();

  // get collection dates
  results = await conn
      .query(selectCollectionDatesQuery, [locationName, streetName, date]);
  // print("query executed");

  for (var row in results) {
    collectionDates.putIfAbsent(row[0], () => []).add(row[1]);
  }

  return Response.ok(jsonEncode(collectionDates));
}

initDBSettings(DotEnv env) {
  ConnectionSettings? _tmpConnectionSettings;

  // this part is for running the app as a docker container
  try {
    String? host = Platform.environment['DB_CON_HOST'];
    String? portStr = Platform.environment['DB_CON_PORT'];
    int? port = portStr != null ? int.tryParse(portStr) : null;
    String? user = Platform.environment['DB_CON_USER'];
    String? password = Platform.environment['DB_CON_PASSWORD'];
    String? db = Platform.environment['DB_CON_DATABASE'];

    // list of variables to be checked, if they are null
    final List variables = [host, port, user, password, db];
    // count the amount of variables that are null
    int nullCount = variables.where((v) => v == null).length;

    // at least one, but not all variables are null
    if (nullCount > 0 && nullCount < variables.length) {
      if (host == null) {
        throw ArgumentError('DB_CON_HOST is not set');
      }
      if (portStr == null || port == null) {
        throw ArgumentError('DB_CON_PORT is not set or not a valid number');
      }
      if (user == null) {
        throw ArgumentError('DB_CON_USER is not set');
      }
      if (password == null) {
        throw ArgumentError('DB_CON_PASSWORD is not set');
      }
      if (db == null) {
        throw ArgumentError('DB_CON_DATABASE is not set');
      }
    }

    _tmpConnectionSettings = ConnectionSettings(
        host: host!, port: port!, user: user!, password: password!, db: db!);
  } on ArgumentError catch (e) {
    print('Error: ${e.message}');
    exit(1);
  } catch (e) {
    print('An unexpected error occurred: $e');
  }

  // this two ConnectionSettings objects are used in application (non-docker) mode
  // .env file is required
  _dbSettingsProduction = ConnectionSettings(
    host: env['DB_PRODUCTION_CON_HOST']!,
    port: int.parse(env['DB_PRODUCTION_CON_PORT']!),
    user: env['DB_PRODUCTION_CON_USER'],
    password: env['DB_PRODUCTION_CON_PASSWORD'],
    db: env['DB_CON_PRODUCTION_DATABASE'],
  );

  _dbSettingsLocal = ConnectionSettings(
    host: env['DB_CON_HOST']!,
    port: int.parse(env['DB_CON_PORT']!),
    user: env['DB_CON_USER'],
    password: env['DB_CON_PASSWORD'],
    db: env['DB_CON_DATABASE'],
  );

  // assign the correct object to the _dbSettings variable (for communication with the db)
  if (_tmpConnectionSettings == null) {
    if (env['USE_PRODUCTION_DB'] == 'true') {
      _dbSettings = _dbSettingsProduction;
    } else {
      _dbSettings = _dbSettingsLocal;
    }
  } else {
    _dbSettings = _tmpConnectionSettings;
  }
}

void main(List<String> args) async {
  var env = DotEnv(includePlatformEnvironment: true)..load();

  // check, if .env does provide the necessary variables
  print('read all vars? ${env.isEveryDefined([
        'DB_CON_HOST',
        'DB_CON_PORT',
        'DB_CON_USER',
        'DB_CON_PASSWORD',
        'DB_CON_DATABASE',
        'SERVER_PORT',
        'USE_PRODUCTION_DB'
      ])}');

  // initialize the database connection settings
  initDBSettings(env);

  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(shelf_cors.corsHeaders())
      .addHandler(_router);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(env['SERVER_PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
