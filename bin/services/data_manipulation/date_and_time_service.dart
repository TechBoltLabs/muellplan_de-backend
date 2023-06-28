// bin/services/data_manipulation/date_and_time_service.dart

import '../../constants/constants_barrel.dart';

// this method transforms a provided date from the database to an european date format
// but only the day and month
String getEuropeanDate({required String dateString}) {
  // parse the date string to a DateTime object
  DateTime parsedDate = DateTime.parse(dateString);

  // return the date in the european format
  return "${parsedDate.day}.${parsedDate.month}.";
}

// this method gets a date string and returns the corresponding weekday as a String
String getWeekDay({required String date, bool useShortForm = false}) {
  // variable for storing the weekday
  String weekday;
  // if the user wants to use the short form of the weekday
  if (useShortForm) {
    // get the weekday from the date string
    // by using the DateTime.parse(date).weekday method
    // which returns an int from 1 to 7
    // that int is used as an index for the weekDaysShortForms list
    weekday = weekDaysShortForms[DateTime.parse(date).weekday - 1];
  } else {
    // if the user wants to use the long form of the weekday
    // get the weekday from the date string
    // by using the DateTime.parse(date).weekday method
    // which returns an int from 1 to 7
    // that int is used as an index for the weekDays list
    weekday = weekDays[DateTime.parse(date).weekday - 1];
  }
  // return the weekday
  return weekday;
}