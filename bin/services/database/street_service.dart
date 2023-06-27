// bin/services/database/street_service.dart

import 'package:mysql1/mysql1.dart';

// TODO: implement handling of falsy or non-existent streetCodes
Future<String> getStreetNameFromCode(
    {required ConnectionSettings dbSettings,
      required String streetCode}) async {

  // initialize return variable
  String streetName;
  // prepare statement to be executed
  String selectStreetNameQuery = "select streetName from streets where streetCode = ?";

  // prepare params for the query
  List<String> parameters = [streetCode];

  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(dbSettings);

  // execute query and save results
  Results results = await conn.query(selectStreetNameQuery, parameters);

  // close connection
  await conn.close();

  // save the streetName
  streetName = results.first[0].toString();

  // return the name
  return streetName;
}
