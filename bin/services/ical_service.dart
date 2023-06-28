// /bin/services/ical_service.dart

import 'package:ical/serializer.dart';
import 'package:mysql1/mysql1.dart';

import 'data_manipulation/date_and_time_service.dart';
import 'database/database_service_barrel.dart';

// this method gets locationCode, streetCode, daysBefore, notificationTime and categories
// fetches the collection dates for the provided location, street and categories
// and returns the serialized iCal file
Future<String> generateICalFile(
    {required ConnectionSettings dbSettings,
    required String locationCode,
    required String streetCode,
    required int daysBefore,
    required String notificationTime,
    required List<String> categories}) async {
  // TODO: move duplicate code to a separate function
  // get the location and street names
  String locationName = await getLocationNameFromCode(
      dbSettings: dbSettings, locationCode: locationCode);
  String streetName = await getStreetNameFromCode(
      dbSettings: dbSettings, streetCode: streetCode);
  // get the collection dates for the provided location, street and categories
  Map<String, List<String>> collectionDates = await getFutureCollectionDatesMap(
      dbSettings: dbSettings,
      locationName: locationName,
      streetName: streetName,
      categories: categories);

  // initialize the calendar
  ICalendar calendar = ICalendar();

  // create the calendar content and assign it to the calendar
  calendar = await generateIcalContent(
      calendar: ICalendar(),
      locationName: locationName,
      streetName: streetName,
      collectionDates: collectionDates,
      daysBefore: daysBefore,
      notificationTime: notificationTime,
      dbSettings: dbSettings);

  // return the serialized calendar
  return calendar.serialize();
}

// this method gets the locationName, streetName, collectionDates, daysBefore, notificationTime
// creates the calendar content and returns the calendar
Future<ICalendar> generateIcalContent(
    {required ConnectionSettings dbSettings,
    required ICalendar calendar,
    required String locationName,
    required String streetName,
    required Map<String, List<String>> collectionDates,
    required int daysBefore,
    required String notificationTime}) async {
  // iterate over the collectionDates map
  for (var category in collectionDates.keys) {
    // set the category description
    String categoryDescription = category;

    // iterate over the collection dates for the current category
    for (var date in collectionDates[category]!) {
      // calculate the dates
      // parse the date
      DateTime collectionDate = DateTime.parse(date);

      // split the date into year, month and day
      int dateYear = int.parse(date.split('-')[0]);
      int dateMonth = int.parse(date.split('-')[1]);
      int dateDay = int.parse(date.split('-')[2]);

      // split the notificationTime into hour and minute
      int notificationTimeHour = int.parse(notificationTime.split(':')[0]);
      int notificationTimeMinute = int.parse(notificationTime.split(':')[1]);

      // create the notification date DateTime object
      DateTime notificationDateTime = DateTime.utc(dateYear, dateMonth, dateDay,
              notificationTimeHour, notificationTimeMinute)
          .subtract(Duration(days: 2));

      // format the date to be displayed in the description
      // get the weekday
      String weekday = getWeekDay(date: collectionDate.toString());
      // get the european date
      String europeanDate =
          getEuropeanDate(dateString: collectionDate.toString());
      // create the formatted date
      String collectionDateFormatted = "$weekday - $europeanDate";

      // create the event to be added to the calendar
      IEvent event = IEvent(
        // the notification
        alarm: IAlarm.display(
          description: "Entsorger für $categoryDescription kommt",
          duration: Duration(days: daysBefore),
          trigger: notificationDateTime,
        ),
        // the date of the collection
        start: DateTime(collectionDate.year, collectionDate.month,
            collectionDate.day, 0, 0, 0),
        // the title of the event
        summary: "Entsorger für $categoryDescription kommt",
        // the description of the event
        description: "Entsorger für $categoryDescription kommt\n"
            "Ort: $locationName\n"
            "Straße: $streetName\n"
            "Datum: $collectionDateFormatted",
        // the location of the collection
        location: "$locationName, $streetName",
      );

      // add the event to the calendar
      calendar.addElement(event);
    }
  }

  // return the calendar
  return calendar;
}
