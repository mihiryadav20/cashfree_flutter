// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // GlobalKey to manage the NavigatorState
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? orderId; // To store the order ID returned from Django backend
  String? paymentSessionId; // To store the payment session ID

  @override
  void initState() {
    super.initState();
    CFPaymentGatewayService().setCallback(onVerify, onError);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,  // Attach the GlobalKey to the Navigator
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Cashfree Flutter Integration'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Click below to open the checkout page"),
              TextButton(
                onPressed: createOrderAndCheckout,
                child: const Text("Pay Now"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step 1: Create an order by calling Django backend API
  Future<void> createOrderAndCheckout() async {
    try {
      var response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/create-payment/'), // Update with your Django API endpoint
        body: {
          'amount': '505', // Example amount, change as needed
          'customer_id': 'mihirsyadav', // Replace with real customer ID
          'customer_phone': '9876543210', // Replace with real phone number
          'customer_email': 'test@example.com', // Replace with real email
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          orderId = jsonResponse['order_id'];
          paymentSessionId = jsonResponse['payment_session_id']; // Assuming your Django backend returns this
        });
        // Proceed to Cashfree payment page
        webCheckout();
      } else {
        print('Failed to create order: ${response.body}');
      }
    } catch (e) {
      print('Error creating order: $e');
    }
  }

  // Step 2: Create session and initiate payment
  CFSession? createSession() {
    if (orderId != null && paymentSessionId != null) {
      try {
        var session = CFSessionBuilder()
            .setEnvironment(CFEnvironment.SANDBOX) // Set to PRODUCTION when live
            .setOrderId(orderId!)
            .setPaymentSessionId(paymentSessionId!)
            .build();
        return session;
      } on CFException catch (e) {
        print(e.message);
      }
    }
    return null;
  }

  // Initiating the Web Checkout process
  webCheckout() async {
    try {
      var session = createSession();
      
      // Ensure session is successfully created
      if (session != null) {
        var cfWebCheckout = CFWebCheckoutPaymentBuilder().setSession(session).build(); // Ensure you build the payment object
        
        // Initiating the payment process
        CFPaymentGatewayService().doPayment(cfWebCheckout as CFPayment); // Explicit cast to CFPayment
      } else {
        print('Failed to create session');
      }
    } on CFException catch (e) {
      print(e.message);
    }
  }

  // Handle verification after payment
  void onVerify(String orderId) async {
    var response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/fetch-payment-status/'),
      body: {'order_id': orderId},
    );

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      String paymentStatus = jsonResponse['payment_status'];
      print('Payment status: $paymentStatus');

      if (paymentStatus == 'SUCCESS') {
        print("Navigating to PaymentSuccessPage");
        // Use the GlobalKey to perform the navigation
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => PaymentSuccessPage()),
        );
      } else {
        showFailureMessage();
      }
    } else {
      print('Failed to fetch payment status: ${response.body}');
    }
  }

  // Handle error during payment
  void onError(CFErrorResponse errorResponse, String orderId) {
    // Check the available fields in errorResponse and print the entire response
    print('Payment failed for Order ID: $orderId. Error: ${errorResponse.toString()}');
    showFailureMessage();  // Show a failure message when payment fails
  }

  // Function to show a payment failure message
  void showFailureMessage() {
    showDialog(
      context: navigatorKey.currentContext!,  // Use the GlobalKey's context
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Payment Failed"),
          content: Text("Your payment has failed. Please try again."),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}

// New page for payment success
class PaymentSuccessPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Payment Success"),
      ),
      body: Center(
        child: Text(
          "Your payment was successful!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }
}
