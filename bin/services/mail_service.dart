// bin/services/mail_service.dart

// get the necessary information for the email
import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mysql1/mysql1.dart';

class MailService {
  late final ConnectionSettings _dbSettings;
  late final SmtpServer _smtpServer;
  late final MAIL_FROM_NAME;
  late final MAIL_FROM_ADDRESS;
  late final MAIL_HOST;
  late final MAIL_PORT;
  late final MAIL_AUTH_USER;
  late final MAIL_AUTH_PASS;

  MailService(
      {required ConnectionSettings dbSettings,
      String? mailFromName,
      required String mailFromAddress,
      required String mailHost,
      required int mailPort,
      required String mailAuthUser,
      required String mailAuthPass}) {
    _dbSettings = dbSettings;
    // TODO: set mail settings
    MAIL_FROM_ADDRESS = mailFromAddress;
    MAIL_FROM_NAME = mailFromName ?? mailFromAddress;
    MAIL_HOST = mailHost;
    MAIL_PORT = mailPort;
    MAIL_AUTH_USER = mailAuthUser;
    MAIL_AUTH_PASS = mailAuthPass;
    _smtpServer = SmtpServer(MAIL_HOST,
        port: MAIL_PORT,
        username: MAIL_AUTH_USER,
        password: MAIL_AUTH_PASS,
        ssl: true);
  }

// send the email
  Future<bool> sendMail(String email, String subject, String body) async {
    // TODO: implement sendMail

    // create the message object
    Message _message = Message()
      ..from = Address(MAIL_FROM_ADDRESS, MAIL_FROM_NAME)
      ..recipients.add(email)
      ..subject = subject
      ..html = body;

    try {
      final sendReport = await send(_message, _smtpServer);
      // TODO: use Logger
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      // TODO: use Logger
      print('Message not sent. There has been a problem: $e');
    }
    return true;
  }

  void gatherMailInfo() async {}

  Future<bool> sendWelcomeMail(String email) async {
    // initialize the variable for the return value
    bool mailSuccessfullySent = true;

    // connect to the database
    MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

    // initialize variables
    String name = "",
        locationName = "",
        streetName = "",
        mailHash = "",
        notificationTime = "",
        notificationDaysBefore = "";
    List<String> categories = [];

    // create the queries to get the user's name, location, street, categories and mail_hash
    // user info
    String userInformationQuery =
        "SELECT name, locationName, streetName, mail_hash, notificationTime, notificationDaysBefore FROM subscribersView WHERE email = ?";
    // litter categories
    String userCategoriesQuery =
        "SELECT category FROM subscribersCategoriesView WHERE email = ?";

    // set the parameters
    List<String> parameters = [email];

    // execute the queries
    // user info
    Results userInformationResults =
        await conn.query(userInformationQuery, parameters);
    // litter categories
    Results userCategoriesResults =
        await conn.query(userCategoriesQuery, parameters);

    // close the connection
    await conn.close();

    try {
      // assign the results to the variables
      // userinfo
      for (var info in userInformationResults) {
        name = info[0];
        locationName = info[1];
        streetName = info[2];
        mailHash = info[3];
        notificationTime = info[4];
        notificationDaysBefore = info[5];
      }

      // litter categories
      for (var category in userCategoriesResults) {
        categories.add(category[0]);
      }
    } catch (e) {
      print("Error while assigning the results to the variables: $e");
      mailSuccessfullySent = false;
    }

    // create the email body
    String body = await generateWelcomeBody(name, locationName, streetName,
        mailHash, notificationTime, notificationDaysBefore, categories);

    // get the mail subject
    String subject = getSubject("welcome");

    bool mailSent = await sendMail(email, subject, body);

    // send the email
    mailSuccessfullySent = mailSuccessfullySent && mailSent;

    // return the result of the mail sending
    return mailSuccessfullySent;
  }

  Future<String> generateWelcomeBody(
      String name,
      String locationName,
      String streetName,
      String mailHash,
      String notificationTime,
      String notificationDaysBefore,
      List<String> categories) async {
    // get the welcome message template from the file
    String welcomeMessageFilePath = "/app/mail/templates/welcome/welcome.html";
    String welcomeMessage = await File(welcomeMessageFilePath).readAsString();

    // create the address string
    String address = "$locationName, $streetName";

    // initialize tha var for storing the categories' unordered list
    String categoriesStr = "";

    // create the unordered list of categories
    if (categories.isNotEmpty) {
      categoriesStr = "<ul>";
      for (var category in categories) {
        categoriesStr += "<li>$category</li>";
      }
      categoriesStr += "</ul>";
    }

    // get the unsubscribe link
    String unsubscribeLink = getUnsubscribeLink(mailHash);

    // replace the placeholders in the welcome message
    welcomeMessage = welcomeMessage
        .replaceAll('{firstName}', name)
        .replaceAll('{address}', address)
        .replaceAll('{litterCategoriesList}', categoriesStr)
        .replaceAll('{notificationTime}', notificationTime)
        .replaceAll('{notificationDaysBefore}', notificationDaysBefore)
        .replaceAll('{unsubscribeLink}', unsubscribeLink);

    // return the email body
    return welcomeMessage;
  }

  Future<bool> sendSubscriptionUpdateMail(String email) async {
    // initialize the variable for the return value
    bool mailSuccessfullySent = true;

    // connect to the database
    MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

    // initialize variables
    String name = "",
        locationName = "",
        streetName = "",
        mailHash = "",
        notificationTime = "",
        notificationDaysBefore = "";
    List<String> categories = [];

    // create the queries to get the user's name, location, street, categories and mail_hash
    // user info
    String userInformationQuery =
        "SELECT name, locationName, streetName, mail_hash, notificationTime, notificationDaysBefore FROM subscribersView WHERE email = ?";
    // litter categories
    String userCategoriesQuery =
        "SELECT category FROM subscribersCategoriesView WHERE email = ?";

    // set the parameters
    List<String> parameters = [email];

    // execute the queries
    // user info
    Results userInformationResults =
        await conn.query(userInformationQuery, parameters);
    // litter categories
    Results userCategoriesResults =
        await conn.query(userCategoriesQuery, parameters);

    // close the connection
    await conn.close();

    try {
      // assign the results to the variables
      // userinfo
      name = userInformationResults.first[0];
      locationName = userInformationResults.first[1];
      streetName = userInformationResults.first[2];
      mailHash = userInformationResults.first[3];
      notificationTime = userInformationResults.first[4];
      notificationDaysBefore = userInformationResults.first[5];

      // litter categories
      for (var category in userCategoriesResults) {
        categories.add(category[0]);
      }
    } catch (e) {
      print("Error while assigning the results to the variables: $e");
      mailSuccessfullySent = false;
    }

    // create the email body
    String body = await generateUpdateBody(name, locationName, streetName,
        mailHash, notificationTime, notificationDaysBefore, categories);

    // get the mail subject
    String subject = getSubject("change");

    bool mailSent = await sendMail(email, subject, body);

    // send the email
    mailSuccessfullySent = mailSuccessfullySent && mailSent;

    // return the result of the mail sending
    return mailSuccessfullySent;
  }

  Future<String> generateUpdateBody(
      String name,
      String locationName,
      String streetName,
      String mailHash,
      String notificationTime,
      String notificationDaysBefore,
      List<String> categories) async {
    // get the update message template from the file
    String updateMessageFilePath =
        "/app/mail/templates/update/settingsUpdate.html";
    String updateMessage = await File(updateMessageFilePath).readAsString();

    // create the address string
    String address = "$locationName, $streetName";

    // get the unsubscribe link
    String unsubscribeLink = getUnsubscribeLink(mailHash);

    // initialize tha var for storing the categories' unordered list
    String categoriesStr = "";

    // create the unordered list of categories
    if (categories.isNotEmpty) {
      categoriesStr = "<ul>";
      for (var category in categories) {
        categoriesStr += "<li>$category</li>";
      }
      categoriesStr += "</ul>";
    } else {
      categoriesStr =
          "<p>keine Kategorien ausgewählt</p><br><p class='small'><em>(Dadurch erhalten Sie keine Benachrichtigungen, sind aber noch im System registriert)</em></p><br>"
          "<p>Sie können sich auch vollständig von der Benachrichtigung <a href='{unsubscribeLink}' class='link'>abmelden</a></p>";
    }

    // replace the placeholders in the welcome message
    updateMessage = updateMessage
        .replaceAll('{firstName}', name)
        .replaceAll('{address}', address)
        .replaceAll('{litterCategoriesList}', categoriesStr)
        .replaceAll('{notificationTime}', notificationTime)
        .replaceAll('{notificationDaysBefore}', notificationDaysBefore)
        .replaceAll('{unsubscribeLink}', unsubscribeLink);

    // return the email body
    return updateMessage;
  }

  Future<bool> sendUnsubscribeConfirmationMail(
      String name, String email) async {
    // initialize the variable for the return value
    bool mailSuccessfullySent = true;

    // create the email body
    String body = await generateFarewellBody(name);

    // get the mail subject
    String subject = getSubject("unsubscribe");

    bool mailSent = await sendMail(email, subject, body);

    // send the email
    mailSuccessfullySent = mailSuccessfullySent && mailSent;

    // return the result of the mail sending
    return mailSuccessfullySent;
  }

  Future<String> generateFarewellBody(String name) async {
    // get the farewell message template from the file
    String farewellMessageFilePath =
        "/app/mail/templates/farewell/farewell.html";
    String farewellMessage = await File(farewellMessageFilePath).readAsString();

    // replace the placeholders
    farewellMessage = farewellMessage.replaceAll('{firstName}', name);

    // return the mail body
    return farewellMessage;
  }

  Future<bool> sendMailToMatchingSubscribers() async {
    // initialize the variable for the return value
    bool mailsSuccessfullySent = true;
    // connect to database
    MySqlConnection conn = await MySqlConnection.connect(_dbSettings);

    // create query to get the subscribers to notify with additional Information
    String subscribersToNotifyQuery =
        "select collectionDate, categories, locationName, streetName, email, firstName, mail_hash from subscribersToNotifyWithInformationView";

    // execute the query
    Results subscribersToNotifyResults =
        await conn.query(subscribersToNotifyQuery);

    // close the connection
    await conn.close();

    // initialize variables
    String collectionDate,
        categories,
        locationName,
        streetName,
        email,
        name,
        mailHash;

    // assign the results to the variables
    if (subscribersToNotifyResults.isNotEmpty) {
      // loop through the results
      for (var result in subscribersToNotifyResults) {
        bool mailSuccessfullySent;
        collectionDate = result[0];
        categories =
            result[1].toString(); // is Blob datatype (binary large object)
        locationName = result[2];
        streetName = result[3];
        email = result[4];
        name = result[5];
        mailHash = result[6];
        // TODO: remove this
        print(
            "collectionDate: $collectionDate, categories: $categories, locationName: $locationName, streetName: $streetName, email: $email, name: $name, mailHash: $mailHash");

        // send the mail
        mailSuccessfullySent = await sendNotificationMail(
            email: email,
            firstName: name,
            locationName: locationName,
            streetName: streetName,
            categories: categories,
            date: collectionDate,
            mailHash: mailHash);

        // TODO: user Logger or remove this
        print("mail to $email successfully sent: $mailSuccessfullySent");
      }
    } else {
      mailsSuccessfullySent = false;
    }

    return mailsSuccessfullySent;
  }

  Future<bool> sendNotificationMail(
      {required String email,
      required String firstName,
      required String locationName,
      required String streetName,
      required String categories,
      required String date,
      required String mailHash}) async {
    // initialize the variable for the return value
    bool mailSuccessfullySent = true;

    // needed variables for the mail body:
    // - firstName
    // - address (locationName, streetName)
    // - collections:
    //   - category (not the identifier)
    //   - date
    // - unsubscribeLink (mailHash)

    // initialize variables
    String subject = getSubject("notification");
    String address = "$locationName, $streetName";
    String collectionDatesList = await getCollectionDatesList(categories, date);
    String unsubscribeLink = getUnsubscribeLink(mailHash);

    String body = await generateNotificationBody(
        address: address,
        collectionDatesList: collectionDatesList,
        firstName: firstName,
        unsubscribeLink: unsubscribeLink);

    // send the email
    bool mailSent = await sendMail(email, subject, body);
    mailSuccessfullySent = mailSuccessfullySent && mailSent;

    return mailSuccessfullySent;
  }

  Future<String> getCollectionDatesList(String categories, String date) async {
    List<String> categoriesList = categories.split(",");
    print("categoriesList: $categoriesList");

    // get the notification collection date message template from the file
    String notificationMessageCollectionDateFilePath =
        "/app/mail/templates/notification/mail_collection_date.html";
    String notificationMessageCollectionDateSingle =
        await File(notificationMessageCollectionDateFilePath).readAsString();

    // initialize the variable for the list of collection dates
    String notificationMessageCollectionDates = "";

    // loop through the categories
    for (var category in categoriesList) {
      // replace the placeholders
      String notificationMessageCollectionDateSingleReplaced =
          notificationMessageCollectionDateSingle
              .replaceAll('{category}', category)
              .replaceAll('{date}', date);
      notificationMessageCollectionDates +=
          notificationMessageCollectionDateSingleReplaced;
      print(category);
    }

    // TODO: check, if it could happen this to be empty
    // return the
    return notificationMessageCollectionDates;
  }

  Future<String> generateNotificationBody(
      {required String firstName,
      required String address,
      required String collectionDatesList,
      required String unsubscribeLink}) async {
    // get the notification message template from the file
    String notificationMessageFilePath =
        "/app/mail/templates/notification/mail_body.html";
    String notificationMessage =
        await File(notificationMessageFilePath).readAsString();

    // replace the placeholders
    notificationMessage = notificationMessage
        .replaceAll('{firstName}', firstName)
        .replaceAll('{address}', address)
        .replaceAll('{collectionDatesList}', collectionDatesList)
        .replaceAll('{unsubscribeLink}', unsubscribeLink);

    // return the mail body
    return notificationMessage;
  }

  String getSubject(String type) {
    switch (type) {
      case "welcome":
        return "Willkommen bei muellplan.de";
      case "unsubscribe":
        return "Abmeldung von muellplan.de";
      case "change":
        return "Änderung der Benachrichtigungseinstellungen für muellplan.de";
      case "notification":
        return "muellplan.de Benachrichtigung";
      default:
        return "muellplan.de";
    }
  }

  String getUnsubscribeLink(String mailHash) {
    return "https://api.muellplan.de/unsubscribe/$mailHash";
  }
}
