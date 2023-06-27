// bin/services/database/collection_date_service.dart

import 'package:mysql1/mysql1.dart';

Future<Map<String, List<String>>> getFutureCollectionDatesMap(
    {required ConnectionSettings dbSettings,
    required String locationName,
    required String streetName,
    List<String>? categories}) async {
  // initialize return variable
  Map<String, List<String>> collectionDates = {};

  // get the current date
  String currentDate = DateTime.now().toString().split(' ')[0];

  // prepare params for the query
  List<String> parameters = [
    locationName,
    streetName,
    currentDate
  ];

  // prepare placeholders for the categories
  String categoriesPlaceholders = "";

  // if categories is not empty, add a placeholder for each category
  // and add the category to the parameters
  if(categories!.isNotEmpty){
    for(String category in categories){
      // add a placeholder for each category
      categoriesPlaceholders += categoriesPlaceholders.isEmpty ? "?" : ", ?";
      // add category to parameters
      parameters.add(category);
    }
  } else{ // else add placeholders for all categories
    // TODO: fetch all categories from db instead of hardcoding
    categoriesPlaceholders = "'paper', 'residual', 'recycling', 'bio'";
  }

  // prepare statement to be executed
  String selectUpcomingCollectionDatesQuery =
      "select category, date from collectionDatesView "
      "where locationName = ? "
      "and streetName = ? "
      "and date >= ? "
      "and category_identifier in ($categoriesPlaceholders) "
      "order by date;";

  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(dbSettings);

  // execute the query and save results
  Results results =
      await conn.query(selectUpcomingCollectionDatesQuery, parameters);


  // close connection
  await conn.close();

  // parse the results and fill the collection dates map
  for (var row in results) {
    collectionDates.putIfAbsent(row[0], () => []).add(row[1]);
  }

  // return the map
  return collectionDates;
}
