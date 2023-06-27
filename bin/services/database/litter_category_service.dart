// bin/services/database/litter_category_service.dart

import 'package:mysql1/mysql1.dart';

Future<String> getCategoryDescriptionFromCategoryIdentifier({required ConnectionSettings dbSettings, required String categoryIdentifier}) async{
  // initialize return variable
  String categoryDescription;

  // prepare statement to be executed
  String selectCategoryDescriptionQuery = "select category from litterCategory where category_identifier = ?";

  // prepare params for the query
  List<String> parameters = [categoryIdentifier];

  // connect to database
  MySqlConnection conn = await MySqlConnection.connect(dbSettings);

  // execute query and save results
  Results results = await conn.query(selectCategoryDescriptionQuery, parameters);

  print("fetched description for category identifier: $categoryIdentifier");
  print("results for category description: ${results.toString()}");

  // close connection
  await conn.close();

  // save the categoryDescription
  categoryDescription = results.first[0].toString();

  // return the description
  return categoryDescription;
}