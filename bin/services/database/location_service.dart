// bin/services/database/location_service.dart

import 'package:mysql1/mysql1.dart';

// TODO: implement handling of falsy or non-existent locationCodes
Future<String> getLocationNameFromCode(
    {required ConnectionSettings dbSettings,
    required String locationCode}) async {

  // initialize return variable
  String locationName;
  // prepare statement to be executed
  String selectLocationNameQuery = "select locationName from locations where locationCode = ?";

  // prepare params for the query
  List<String> parameters = [locationCode];

  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(dbSettings);

  // execute query and save results
  Results results = await conn.query(selectLocationNameQuery, parameters);

  // close connection
  await conn.close();

  // save the locationName
  locationName = results.first[0].toString();

  // return the name
  return locationName;
}
