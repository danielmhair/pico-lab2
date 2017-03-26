ruleset trip_store {
  	meta {
	    name "Trip Store"
	    description <<
	Part 3 of Pico Lab 1
	>>
	    author "Daniel Hair"
	    logging on
	    shares __testing, long_trip, trips, long_trips, short_trips
	    provides trips, short_trips, long_trips
  	}
  	global {
	    __testing = {"queries":[{ "name": "__testing" }],
	    			 "events": [{"domain" : "car", "type" : "trip_reset"}]}

	    empty_trip = { "0": { "mileage": "0".as("Number"), "timestamp" : timestamp } }

	    empty_long_trip = { "0": { "mileage": "0".as("Number"), "timestamp" : timestamp } }

	    empty_id = { "_0": { "trip_id": "0".as("Number"), "long_trip_id" : "0".as("Number") } }

	    long_trip = "200".as("Number")

	    trips = function() {
      		ent:trips
		}

		long_trips = function() {
    		ent:long_trips
		}

		short_trips = function() {
			trips = ent:trips.defaultsTo(empty_trip,"ent:trips was empty");
			short_trips = trips.difference(ent:long_trips.defaultsTo(empty_long_trip, "ent:long_trips was empty"));
			short_trips
		}
	}
	rule collect_trips{
		select when explicit trip_processed
		pre{
			mileage = event:attr("mileage").klog("our passed in mileage to be stored: ")
			attributes = event:attrs().klog("our attributes")
			timestamp = event:attr("timestamp").klog("our passed in timestamp")
		}
		always{
      		ent:trips := ent:trips.defaultsTo(empty_trip,"initialization was needed");
      		ent:trip_id := ent:trip_id.defaultsTo(empty_id,"initializing trip_ids");
      		ent:trips{[ent:trip_id{["_0","trip_id"]},"mileage"]} := mileage;
      		ent:trips{[ent:trip_id{["_0","trip_id"]},"timestamp"]} := timestamp;
      		ent:trip_id{["_0","trip_id"]} := ent:trip_id{["_0","trip_id"]} + 1
		}
	}

	rule collect_long_trips{
		select when explicit found_long_trip
		pre{
			mileage = event:attr("mileage").klog("our passed in long mileage to be stored: ")
			timestamp = event:attr("timestamp").klog("our passed in timestamp")
		}
		always{
			ent:long_trips := ent:long_trips.defaultsTo(empty_long_trip, "initilization was needed");
			ent:trip_id := ent:trip_id.defaultsTo(empty_id, "initializing trip_ids");
			ent:long_trips{[ent:trip_id{["_0","long_trip_id"]},"mileage"]} := mileage;
			ent:long_trips{[ent:trip_id{["_0","long_trip_id"]},"timestamp"]} := timestamp;
			ent:trip_id{["_0","long_trip_id"]} := ent:trip_id{["_0","long_trip_id"]} + 1
		}
	}
	rule clear_trips{
		select when car trip_reset
		always {
			ent:trips := empty_trip;
			ent:long_trips := empty_long_trips;
			ent:trip_id := empty_id
		}
	}
 }