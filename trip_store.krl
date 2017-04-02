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
			trips = ent:trips.defaultsTo(empty_trip, "trips are cleared");
			short_trips = trips.difference(ent:long_trips.defaultsTo(empty_long_trip, "long_trips cleared"));
			short_trips
		}
	}
	rule collect_trips{
		select when explicit trip_processed
		pre{
			mileage = event:attr("mileage").klog("mileages passed in: ")
			attributes = event:attrs().klog("our attributes")
			timestamp = event:attr("timestamp").klog("timestamp passed in: ")
		}
		always{
			ent:trips := ent:trips.defaultsTo(empty_trip, "Trips initialized");
			ent:trip_id := ent:trip_id.defaultsTo(empty_id, "trip_ids initialized");
			ent:trips{[ent:trip_id{["_0", "trip_id"]}, "mileage"]} := mileage;
			ent:trips{[ent:trip_id{["_0", "trip_id"]}, "timestamp"]} := timestamp;
			ent:trip_id{["_0", "trip_id"]} := ent:trip_id{["_0", "trip_id"]} + 1
		}
	}

	rule collect_long_trips{
		select when explicit found_long_trip
		pre{
			mileage = event:attr("mileage").klog("long mileage passed in: ")
			timestamp = event:attr("timestamp").klog("timestamp passed in: ")
		}
		always{
			ent:long_trips := ent:long_trips.defaultsTo(empty_long_trip, "initialized long_trips");
			ent:trip_id := ent:trip_id.defaultsTo(empty_id, "initializing trip_ids");
			ent:long_trips{[ent:trip_id{["_0", "long_trip_id"]}, "mileage"]} := mileage;
			ent:long_trips{[ent:trip_id{["_0", "long_trip_id"]}, "timestamp"]} := timestamp;
			ent:trip_id{["_0", "long_trip_id"]} := ent:trip_id{["_0", "long_trip_id"]} + 1
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