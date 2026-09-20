# **PRODUCT REQUIREMENTS DOCUMENT (PRD)**

## **Product Name**

**9ja Transport**

## **1\. Product Overview**

9ja Transport is a transportation booking app designed for **Danfo drivers, bus operators, bike riders, and passengers in Nigeria**.

The app allows passengers to book a ride before going to the park. After booking, the passenger receives a **digital transport slip with a barcode**. At the park, the passenger presents the slip, the booking is confirmed, and the passenger can enter the vehicle and choose **any available seat**.

The service is designed to combine the traditional Nigerian transport-park system with the convenience of online booking.

The goal is not to completely replace existing parks and transport workers. Instead, it should help parks and drivers **organise passengers, reduce confusion, improve trust, and know how many passengers are coming before departure**.

---

# **2\. Problem Being Solved**

Passengers in Nigeria often experience:

* Long queues at transport parks.  
* Uncertainty about whether a vehicle still has space.  
* Arguments over fares.  
* Difficulty knowing which driver or vehicle they are boarding.  
* Lack of proper booking records.  
* Fake claims of payment or reservation.  
* Delays caused by passengers trying to fill the vehicle.  
* Concerns about entering an unfamiliar vehicle or bike.  
* Poor record keeping at some parks.

Drivers and park operators also face:

* Vehicles leaving without enough passengers.  
* Difficulty keeping track of reserved passengers.  
* Last-minute cancellations.  
* Poor records of daily trips and earnings.  
* Difficulty communicating fare changes.  
* Lost or disputed booking information.

---

# **3\. Product Goal**

The product should make it possible for a passenger to:

**Search → Choose trip → Book → Pay or reserve → Receive slip → Go to park → Verify booking → Board vehicle.**

The experience should be simple enough for someone using a smartphone for the first time.

---

# **4\. Target Users**

### **Passengers**

People travelling within cities or between locations using Danfo, minibuses, buses, and motorcycles.

### **Drivers and Riders**

Approved Danfo drivers, bus drivers, and commercial bike riders.

### **Park Workers**

People responsible for checking passengers, confirming bookings, directing passengers, and managing departures.

### **Transport Business Owners**

Individuals or companies that own vehicles and want to monitor their drivers, trips, passengers, and income.

### **Administrator**

The organisation operating 9ja Transport and responsible for verifying users, handling complaints, monitoring activity, and managing the service.

---

# **5\. Core Passenger Features**

## **5.1 Create Account**

Passengers should be able to register using:

* Phone number  
* Name  
* Optional email address

The phone number should be verified before the account becomes active.

The app should not require unnecessary information during registration.

---

## **5.2 Search for a Journey**

A passenger should enter:

* Where they are going from  
* Destination  
* Date  
* Preferred departure time  
* Number of passengers

The app should then show available journeys.

Example:

**Ikeja → CMS**  
Departure: 8:30 AM  
Fare: ₦1,500  
Vehicle: Danfo  
Available spaces: 7

---

## **5.3 Booking**

The passenger books a **space**, not a specific seat.

After arriving at the park, the passenger can choose **any available seat**.

This keeps the booking process simple and matches normal park operations.

---

# **6\. Payment Options**

The app should support three main options:

### **Pay Now**

The passenger pays before arriving at the park.

### **Reserve and Pay at Park**

The passenger reserves a space and pays when they arrive.

### **Cash Booking**

Passengers who prefer cash can still use the platform by making a reservation and paying physically at the park.

The service should not make online payment compulsory for every passenger.

---

# **7\. Digital Transport Slip**

After booking, the passenger receives a digital slip.

The slip should contain:

* Passenger name  
* Booking number  
* Departure location  
* Destination  
* Date  
* Departure time  
* Fare  
* Driver name  
* Driver phone number  
* Vehicle number  
* Vehicle plate number  
* Park name  
* **Barcode**

The passenger should be able to save the slip on their phone.

The slip should also be available when the passenger has **poor internet access**.

---

# **8\. Barcode Verification**

At the park, the passenger presents the barcode on the phone.

The park worker or driver scans the barcode.

The system should immediately show:

**VALID BOOKING**

or

**BOOKING ALREADY USED**

or

**BOOKING CANCELLED**

or

**BOOKING EXPIRED**

Each booking barcode should only be usable for the journey it was created for.

---

# **9\. Network Problems**

Nigeria has areas where mobile internet can be unreliable.

The app should therefore allow:

* Bookings to remain visible on the phone after they have been created.  
* The passenger to open their transport slip without internet.  
* Park workers to continue checking passengers when there is temporary network trouble.  
* Booking information to update when the network returns.

A passenger should not lose a valid booking simply because the network becomes poor while they are at the park.

---

# **10\. Cancellation and No-Show Policy**

Passengers should be able to cancel before departure.

The product should use a simple cancellation rule:

**Early cancellation:** passenger receives a refund according to the cancellation period.

**Late cancellation:** passenger may receive a smaller refund.

**No-show:** after a defined grace period, the booking expires and the space can be offered to another passenger.

### **Recommended grace period**

**15 minutes after the scheduled departure time.**

The app should clearly show the cancellation and no-show rules before payment.

---

# **11\. Driver and Rider Profiles**

Every approved driver or bike rider should have a profile.

The profile should show:

* Name  
* Photograph  
* Phone number  
* Vehicle type  
* Vehicle number  
* Plate number  
* Park  
* Approved status  
* Customer ratings  
* Number of completed trips

Passengers should be able to see the driver's information **before boarding**.

---

# **12\. Driver Verification**

Drivers and riders should not be allowed to operate immediately after registration.

They should provide the required identification and transport documents for verification.

The platform should verify:

* Driver identity  
* Phone number  
* Vehicle information  
* Plate number  
* Relevant transport documents  
* Park/operator information

Once approved, the driver's profile receives a visible **Verified Driver** status.

---

# **13\. Vehicle Verification**

Each vehicle should have a record containing:

* Vehicle number  
* Plate number  
* Vehicle type  
* Driver assigned to it  
* Transport park  
* Owner/operator  
* Verification status

The vehicle shown to the passenger should match the vehicle at the park.

---

# **14\. Trip Management**

Drivers or park workers should be able to see:

* Today's trips  
* Departure time  
* Number of booked passengers  
* Passengers who have arrived  
* Passengers who have not arrived  
* Payment status

Before leaving the park, the driver or authorised park worker should be able to mark the trip as:

**Ready to Leave**

and then:

**Departed**

---

# **15\. Passenger Arrival Tracking**

When the passenger reaches the park, their barcode is scanned.

The system marks them as:

**Arrived**

This allows the driver to know how many booked passengers are already present.

Example:

**Trip: Ikeja → CMS**  
Booked: 14  
Arrived: 12  
Not arrived: 2

---

# **16\. Fare Management**

Transport fares can change frequently in Nigeria.

The system should allow authorised transport operators to update fares.

Before a passenger confirms a booking, the app must clearly show the **current fare**.

Once a passenger has successfully paid, that booking should retain its agreed fare.

---

# **17\. Nigerian Economy Features**

The product should recognise that not every passenger has the same financial situation.

### **Fare Alerts**

Passengers should be notified when the price of a regular route changes.

### **Price History**

Passengers can see previous prices for a route so they understand when prices have changed.

### **Multiple Payment Choices**

Online payment should not be the only option.

### **Affordable Booking**

9ja Transport should avoid adding unnecessary charges that make short journeys significantly more expensive.

### **Low-Data Design**

The app should use as little mobile data as possible.

### **Offline Slip**

A passenger should still be able to show a previously issued booking slip without internet.

---

# **18\. Bike Ride Feature**

Bike bookings should work differently from Danfo bookings.

For a bike:

1. Passenger enters pickup point.  
2. Passenger enters destination.  
3. App shows available riders.  
4. Passenger selects a ride.  
5. Passenger receives booking information.  
6. Rider details are displayed.  
7. Passenger confirms the rider before starting the trip.

The bike booking should display:

* Rider name  
* Rider photograph  
* Phone number  
* Bike number  
* Plate number where applicable  
* Fare  
* Pickup location  
* Destination

There is no seat selection for bike rides.

---

# **19\. Safety Features**

Passenger safety should be an important part of 9ja Transport.

### **Share Trip**

Passenger can share trip details with a trusted person.

### **Emergency Button**

A visible emergency button should allow the passenger to quickly access emergency assistance options.

### **Driver Information**

Driver identity and vehicle details must be visible before boarding.

### **Trip Status**

The passenger can see whether the trip is:

**Booked → Driver Assigned → Arrived → Boarding → Departed → Completed**

### **Complaint Button**

Passengers should have a simple way to report problems.

---

# **20\. Ratings and Reviews**

After a trip, the passenger can rate:

* Driver/rider  
* Journey experience

The rating process should be simple.

For example:

**How was your trip?**

★★★★★

The passenger can optionally provide a comment.

Drivers should also be able to report problematic passenger behaviour through the platform.

---

# **21\. Park Management**

Each approved transport park should have a digital profile.

The profile can contain:

* Park name  
* Location  
* Available routes  
* Operating hours  
* Transport operators  
* Available vehicles  
* Contact number

Passengers can search for a park and see available trips from that location.

---

# **22\. Booking Queue**

Where a route has many passengers, the park should be able to manage bookings in order.

Example:

**CMS → Ikeja**

1. Booking 001 — Arrived  
2. Booking 002 — Arrived  
3. Booking 003 — Arrived  
4. Booking 004 — Waiting

This can make passenger movement more organised.

---

# **23\. Notifications**

Passengers should receive notifications for important events:

* Booking successful  
* Payment successful  
* Booking reminder  
* Driver assigned  
* Trip time approaching  
* Trip delayed  
* Vehicle changed  
* Fare changed before booking  
* Trip cancelled  
* Refund processed

Important notifications should also be available through **SMS**.

---

# **24\. Driver Notifications**

Drivers should receive:

* New booking  
* Passenger arrival  
* Trip reminder  
* Trip changes  
* Cancellation  
* Vehicle change  
* Park announcements

---

# **25\. Customer Support**

The app should provide simple support options:

**Call Support**  
**Send a Message**  
**Report a Problem**

Common complaints should have quick options such as:

* Driver did not show up  
* Vehicle was different  
* Wrong fare  
* Booking not recognised  
* Payment problem  
* Lost item  
* Safety concern

---

# **26\. Refunds**

The system should clearly record whether a passenger has:

* Paid  
* Not paid  
* Refunded  
* Partially refunded

Refund decisions should follow the published cancellation rules.

The passenger should be notified when a refund has been initiated.

---

# **27\. Lost and Found**

A passenger should be able to report a lost item after a journey.

They should provide:

* Trip information  
* Vehicle number  
* Description of item  
* Approximate location/time

The park or operator can then respond through the platform.

---

# **28\. Driver Earnings**

Drivers should have a simple page showing:

* Today's trips  
* Completed trips  
* Total amount collected  
* Online payments  
* Cash payments  
* Platform charges  
* Amount owed to driver

---

# **29\. Business Owner Dashboard**

Transport owners should be able to see:

* Number of active vehicles  
* Trips completed  
* Passenger bookings  
* Driver activity  
* Daily income  
* Cancelled trips  
* Ratings  
* Vehicle performance

---

# **30\. Administrator Controls**

The 9ja Transport administrator should be able to:

* Approve drivers  
* Suspend drivers  
* Approve vehicles  
* Manage parks  
* Manage routes  
* Set platform charges  
* Handle complaints  
* View bookings  
* Process refunds  
* Monitor suspicious bookings  
* Manage users  
* View overall activity

---

# **31\. Fraud Prevention**

The product should protect passengers, drivers, and the platform.

Important rules include:

* One barcode should not be accepted twice.  
* Cancelled bookings cannot be used.  
* Expired bookings cannot be used.  
* A driver cannot secretly replace the assigned vehicle without updating the booking.  
* Suspicious booking activity should be flagged for review.  
* Payment status must be recorded clearly.

---

# **32\. Special Feature: Park Mode**

One of the most useful features should be a special mode for park workers.

The worker can:

**Scan booking → Confirm passenger → Mark arrived → Direct passenger to vehicle**

The screen should be extremely simple because park workers may be handling many passengers at once.

---

# **33\. Special Feature: Book for Someone**

A passenger should be able to make a booking for another person.

Example:

Someone in Lagos can book a bus trip for their mother travelling from Ibadan to Lagos.

The booking should show:

**Passenger Name:** Mother's name  
**Booked By:** Account holder

---

# **34\. Special Feature: Trip Reminder**

Passengers should be able to choose:

**Remind me 1 hour before departure**

They can receive the reminder through the app and SMS.

---

# **35\. Special Feature: Trip Code**

For additional confidence, the passenger can receive a short trip code.

The driver confirms the code before the journey starts.

This provides another way to confirm that the right passenger is entering the right vehicle.

---

# **36\. What the Passenger Sees**

The main screen should have simple options:

**Book a Ride**  
**My Bookings**  
**Nearby Parks**  
**Ride History**  
**Profile**

A first-time user should be able to understand the app without needing instructions.

---

# **37\. Main Booking Process**

### **Step 1**

Passenger opens 9ja Transport.

### **Step 2**

Passenger chooses pickup location and destination.

### **Step 3**

Available trips appear.

### **Step 4**

Passenger selects a trip.

### **Step 5**

Passenger chooses:

**Pay Now**  
or  
**Reserve & Pay at Park**

### **Step 6**

Booking is confirmed.

### **Step 7**

Digital transport slip is generated.

### **Step 8**

Passenger goes to the park.

### **Step 9**

Barcode is scanned.

### **Step 10**

Passenger boards the vehicle and chooses any available seat.

### **Step 11**

Vehicle departs.

### **Step 12**

Trip is completed.

---

# **38\. Business Model**

9ja Transport can earn money through:

### **Small Booking Charge**

A reasonable fee can be added to selected bookings.

### **Driver/Operator Service Charge**

Transport operators can pay a small amount for using the service.

### **Business Packages**

Large transport companies can subscribe to additional management features.

The charges should remain reasonable so they do not discourage passengers from using 9ja Transport.

---

# **39\. Launch Strategy**

The first version should **not launch everywhere in Nigeria at once**.

The recommended approach is:

**Start with a small number of parks and routes in one city.**

Learn how passengers, drivers, and park workers use it.

Then expand to more parks and cities.

---

# **40\. Minimum First Version**

The first version should focus on the features essential to making a booking work:

1. Passenger registration  
2. Route search  
3. Trip booking  
4. Online payment  
5. Reserve-and-pay-at-park  
6. Digital transport slip  
7. Barcode  
8. Barcode checking  
9. Driver profiles  
10. Vehicle details  
11. Park management  
12. Booking cancellation  
13. Driver trip management  
14. SMS/app notifications  
15. Customer complaints  
16. Basic ratings

More advanced features can be introduced later.

---

# **41\. Success Measures**

9ja Transport should measure:

* Number of registered passengers  
* Number of active drivers  
* Number of registered parks  
* Number of bookings  
* Number of completed trips  
* Percentage of booked passengers who arrive  
* Number of cancelled bookings  
* Number of repeat passengers  
* Average passenger rating  
* Average driver rating  
* Number of complaints  
* Average time spent checking passengers at the park

---

# **42\. Product Principles**

The product should always follow five principles:

**Simple** — anyone should understand it.

**Affordable** — it should fit Nigerian transport realities.

**Trustworthy** — passengers should know exactly what they booked.

**Flexible** — it should work with cash, online payments, and poor internet.

**Park-Friendly** — it should improve existing transport operations rather than fight against them.

---

# **43\. Final Product Vision**

9ja Transport should become a trusted digital transport service where a Nigerian passenger can open the app, find a route, reserve a space, pay or choose to pay at the park, receive a verified transport slip, arrive at the park, scan the barcode, identify the correct driver and vehicle, choose any available seat, and travel with greater confidence.

The long-term vision is to connect **passengers, Danfo drivers, bike riders, transport parks, and transport companies** across Nigerian cities through one simple service.

