import 'dart:convert';
import 'dart:io';

import 'package:cron/cron.dart';
import 'package:dotenv/dotenv.dart';
import 'package:mysql1/mysql1.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf_cors;
import 'package:shelf_router/shelf_router.dart';

import 'services/ical_service.dart';
import 'services/mail_service.dart';

// TODO: move _dbSettings to some extra file (constanst.dart somewhere)
late final ConnectionSettings _dbSettings;
late final MailService _mailService;

// TODO: split this into multiple files

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/locations', _locationsHandler)
  ..get('/streets/<locationCode>', _streetsHandler)
  ..get('/collection-dates/<locationCode>/<streetCode>/<date>',
      _collectionDatesHandler)
  ..post('/subscribe', _subscribeHandler)
  ..get('/unsubscribe/<hashValue>', _unsubscribeHandler)
  ..get('/download/ical/<encodedInfo>', _iCalDownloadHandler);
// ..get('/send-mails', _sendMailsHandler);

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

  // query the database
  Results results =
      await conn.query('SELECT locationName, locationCode FROM locations');

  // close the connection
  await conn.close();

  List<List<String>> locations = [];
  // iterate over the results
  for (var result in results) {
    locations.add([result[0].toString(), result[1].toString()]);
  }

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

  // query the database
  Results results = await conn.query(selectLocationIDQuery, [locationCode]);
  locationID = results.first[0].toString();
  results = await conn.query(selectStreetsListQuery, [locationID]);

  // close the connection
  await conn.close();

  // create a list of street-streetCode pairs
  List<List<String>> streets = [];

  for (var result in results) {
    streets.add([result[0].toString(), result[1].toString()]);
  }

  // return the streets
  return Response.ok(jsonEncode(streets));
}

Future<Response> _collectionDatesHandler(Request request) async {
  final locationCode = request.params['locationCode'];
  final streetCode = request.params['streetCode'];
  final date = request.params['date'];

  String locationName, streetName;
  Map<String, List<String>> collectionDates = {};

  // TODO: use location_service.getLocationNameFromCode
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

  // close the connection
  await conn.close();

  for (var row in results) {
    collectionDates.putIfAbsent(row[0], () => []).add(row[1]);
  }

  return Response.ok(jsonEncode(collectionDates));
}

Future<Response> _subscribeHandler(Request request) async {
  // get the body of the request
  String body = await request.readAsString();

  // initialize the variable to store the parsed request
  late Map<String, dynamic> bodyMap;

  try {
    // parse the body
    bodyMap = jsonDecode(body);
  } catch (e) {
    print("the body is not a valid json");
    return Response.badRequest(body: 'the body is not a valid json');
  }

  // initialize the variables
  late String name,
      email,
      locationCode,
      streetCode,
      daysBefore,
      notificationTime,
      categories;

  // check if all attributes are present
  // and assign them to variables
  try {
    // get the name
    name = bodyMap['name']!;
    // get the email address
    email = bodyMap['email']!;
    // get the location code
    locationCode = bodyMap['locationCode']!;
    // get the street code
    streetCode = bodyMap['streetCode']!;
    // get the daysBefore
    daysBefore = bodyMap['daysBefore']!;
    // get the notificationTime
    notificationTime = bodyMap['notificationTime']!;
    // get the categories
    categories = bodyMap['categories']!;
    // TODO: remove this
    print("new subscription:"
        "name: $name,email: $email, locationcode: $locationCode, streetCode: $streetCode, daysBefore: $daysBefore, notificationTime: $notificationTime, categories: $categories");
  } catch (e) {
    print("a subscription attribute is missing");
    return Response.badRequest(body: 'a subscription attribute is missing');
  }

  // check, if the user already exists
  bool userExists = await _checkIfUserExists(email: email);

  // connect to the database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

  // create the statement to call the stored procedure to insert or update the subscription
  String insertOrUpdateSubscriptionQuery =
      "call insertOrUpdateSubscriber(?, ?, ?, ?, ?, ?, ?);";

  // set the parameters for the statement
  List<String> parameters = [
    name,
    email,
    locationCode,
    streetCode,
    notificationTime,
    daysBefore,
    categories
  ];

  // execute the statement
  await conn.query(insertOrUpdateSubscriptionQuery, parameters);

  // check, if the import was successful
  String selectSubscriberWithSettingsQuery =
      "select count(*), name, locationCode, streetCode, notificationTime, notificationDaysBefore, mail_hash from subscribersView where email=?;";
  String selectSubscribersCategoriesQuery =
      "select category from subscribersCategoriesView where email=?;";

  // initialize variables for the check
  int dbUserCount;
  String dbUserName,
      dbUserLocationCode,
      dbUserStreetCode,
      dbUserNotificationTime,
      dbUserDaysBefore,
      dbUserMailHash;
  List<String> dbUserCategories = [];

  // execute the query to get user information and settings
  Results results =
      await conn.query(selectSubscriberWithSettingsQuery, [email]);
  // set the variables
  dbUserCount = results.first[0];
  if (dbUserCount == 1) {
    dbUserName = results.first[1].toString();
    dbUserLocationCode = results.first[2].toString();
    dbUserStreetCode = results.first[3].toString();
    dbUserNotificationTime = results.first[4].toString();
    dbUserDaysBefore = results.first[5].toString();
    dbUserMailHash = results.first[6].toString();
    if (dbUserName == name &&
        dbUserLocationCode == locationCode &&
        dbUserStreetCode == streetCode &&
        dbUserNotificationTime == notificationTime &&
        dbUserDaysBefore == daysBefore) {
      results = await conn.query(selectSubscribersCategoriesQuery, [email]);
      for (var result in results) {
        dbUserCategories.add(result[0].toString());
      }
    } else {
      return Response.internalServerError(
          body: "the user's settings could not be set");
    }
  } else {
    print("the user could not be imported");
    return Response.internalServerError(body: 'the user could not be imported');
  }

  // close the connection
  await conn.close();

  // TODO: implement the sending of the confirmation email
  _sendSubscriptionConfirmationMail(dbUserName, email, dbUserMailHash,
      userExists: userExists);

  // return the status code
  return Response.ok('');
}

Future<Response> _unsubscribeHandler(Request request, String hashValue) async {
  bool userExists = await _checkIfUserExistsByHash(hashValue: hashValue);

  List<String> userDetails =
      await _getUserDetailsForConfirmation(hashValue: hashValue);

  String firstName = userDetails[0], email = userDetails[1];

  if (!userExists) {
    return Response.internalServerError(body: "the user does not exist");
  } else {
    bool success = await _unsubscribeUser(hashValue);
    if (!success) {
      return Response.internalServerError(
          body: "the user could not be unsubscribed");
    } else {
      await _mailService.sendUnsubscribeConfirmationMail(firstName, email);

      String body = await _mailService.generateFarewellBody(firstName);
      return Response.ok(body, headers: {'Content-Type': 'text/html'});
    }
  }
}

// this gets a base64 encoded string, which is a json object with the information needed to generate the ical file
// the json object has the following structure:
// {
//   "locationCode" : "locationCode",
//   "streetCode" : "streetCode",
//   "categories" : ["category1", "category2", "category3"]
//   "daysBefore" : "daysBefore",
//   "notificationTime" : "notificationTime"
// }

// TODO: add current timestamp to the hashed information to invalidate the link after a certain time (e.g. 2 minutes)
Future<Response> _iCalDownloadHandler(
    Request request, String encodedInformation) async {
  // decode the information
  String decodedInformation = utf8.decode(base64.decode(encodedInformation));
  // parse the information
  Map<String, dynamic> information = jsonDecode(decodedInformation);

  // get the information
  String locationCode = information["locationCode"],
      streetCode = information["streetCode"],
      notificationTime = information["notificationTime"];
  String daysBefore = information["daysBefore"];
  List<String> categories = information["categories"].cast<String>();

  // TODO: implement the generation of the ical file
  String icalToRespond = await generateICalFile(
      dbSettings: _dbSettings,
      locationCode: locationCode,
      streetCode: streetCode,
      daysBefore: int.parse(daysBefore),
      notificationTime: notificationTime,
      categories: categories);

  return Response.ok(icalToRespond, headers: {
    'Content-Type': 'text/calendar',
    'Content-Disposition': 'attachment; filename="Abfallkalender.ics"'
  });
}

Future<bool> _unsubscribeUser(String mailHash) async {
  // TODO: implement this
  bool success = true;
  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

  // create the statement to call the stored procedure to unsubscribe the user
  String unsubscribeUserQuery = "call unsubscribeUserByHash(?);";

  // set the parameters for the statement
  List<String> parameters = [mailHash];

  // execute the statement
  await conn.query(unsubscribeUserQuery, parameters);

  // check, if the deletion was successful
  String selectSubscriberWithSettingsQuery =
      "select count(*) from subscribersView where mail_hash=?;";

  // initialize the variables
  int dbUserCount;

  // execute the statement
  Results results =
      await conn.query(selectSubscriberWithSettingsQuery, parameters);

  dbUserCount = results.first[0];
  if (dbUserCount != 0) {
    success = false;
  }

  // close the connection
  await conn.close();

  return success;
}

Future<Response> _sendMailsHandler(Request request) async {
  bool success = await _mailService.sendMailToMatchingSubscribers();

  if (success) {
    return Response.ok('mails sent');
  } else {
    return Response.ok('there are no subscribers to be notified now');
  }
}

void _sendSubscriptionConfirmationMail(
    String dbUserName, String email, String dbUserMailHash,
    {required bool userExists}) async {
  if (!userExists) {
    _mailService.sendWelcomeMail(email);
  } else {
    _mailService.sendSubscriptionUpdateMail(email);
  }
}

initDBSettings(DotEnv env) {
  ConnectionSettings? tmpConnectionSettings;

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

    _dbSettings = ConnectionSettings(
        host: host!, port: port!, user: user!, password: password!, db: db!);
  } on ArgumentError catch (e) {
    print('Error: ${e.message}');
    exit(1);
  } catch (e) {
    print('An unexpected error occurred: $e');
  }
}

Future<bool> _checkIfUserExists({required String email}) async {
  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

  // create the statement check the amount of users with the given email (1 or 0)
  String selectSubscriberWithSettingsQuery =
      "select count(*) from subscribersView where email=?;";

  // set the parameters for the statement
  List<String> parameters = [email];

  // execute the statement
  Results results =
      await conn.query(selectSubscriberWithSettingsQuery, parameters);

  // initialize the variables
  int dbUserCount;

  // close the connection
  await conn.close();

  dbUserCount = results.first[0];
  // TODO: remove this
  print("dbUSerCount: $dbUserCount");
  if (dbUserCount == 0) {
    return false;
  } else {
    return true;
  }
}

Future<bool> _checkIfUserExistsByHash({required String hashValue}) async {
  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

  // create the statement check the amount of users with the given email (1 or 0)
  String selectSubscriberWithSettingsQuery =
      "select count(*) from subscribersView where mail_hash=?;";

  // set the parameters for the statement
  List<String> parameters = [hashValue];

  // execute the statement
  Results results =
      await conn.query(selectSubscriberWithSettingsQuery, parameters);

  // initialize the variables
  int dbUserCount;

  // close the connection
  await conn.close();

  dbUserCount = results.first[0];
  // TODO: remove this
  print("dbUSerCount: $dbUserCount");
  if (dbUserCount == 0) {
    return false;
  } else {
    return true;
  }
}

Future<List<String>> _getUserDetailsForConfirmation(
    {required String hashValue}) async {
  // initialize variables
  String name, mailAddress;

  // create the statement for querying the database
  String getUsersMailAddressFromDB =
      "Select name, email from subscribersView where mail_hash = ?";

  // set the parameters for the query
  List<String> parameters = [hashValue];

  //connect to the database
  MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

  // execute the query
  Results results = await conn.query(getUsersMailAddressFromDB, parameters);

  // close connection
  await conn.close();

  // assign the result to the variable
  if (results.isNotEmpty) {
    name = results.first[0];
    mailAddress = results.first[1];
  } else {
    name = '-';
    mailAddress = '-';
  }

  // return the mail address
  return [name, mailAddress];
}

void main(List<String> args) async {
  // load the environment variables from .env file and from the platform
  var env = DotEnv(includePlatformEnvironment: true)..load();
  // initialize the cron class
  Cron cron = Cron();

  // check, if .env does provide the necessary variables
  print('read all vars? ${env.isEveryDefined([
        'SERVER_PORT',
        'MAIL_FROM',
        'MAIL_HOST',
        'MAIL_PORT',
        'MAIL_AUTH_USER',
        'MAIL_AUTH_PASS'
      ])}');

  // initialize the database connection settings
  initDBSettings(env);

  // initialize the mailing class
  _mailService = MailService(
      dbSettings: _dbSettings,
      mailFromName: env['MAIL_FROM_NAME']!,
      mailFromAddress: env['MAIL_FROM']!,
      mailHost: env['MAIL_HOST']!,
      mailPort: int.parse(env['MAIL_PORT']!),
      mailAuthUser: env['MAIL_AUTH_USER']!,
      mailAuthPass: env['MAIL_AUTH_PASS']!);

  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(shelf_cors.corsHeaders())
      .addHandler(_router);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(env['SERVER_PORT'] ?? '3000');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');

  cron.schedule(Schedule.parse('0 * * * *'), () async {
    // TODO: use Logger
    print('Running hourly cron job at ${DateTime.now()}');
    await _mailService.sendMailToMatchingSubscribers();
  });
}
