ruleset track_my_trip {
  meta {
    name "Track Trips"
    description <<
A first ruleset for Part 2 of pico lab
>>
    author "Daniel Hair"
    logging on
    shares __testing, long_trip
  }
  
  global {
    __testing = {
        "queries": [ { "name": "__testing" } ],
        "events": [ { "domain": "car", "type": "new_trip", "attrs": [ "mileage" ] } ]
    }

    long_trip = "200".as("Number")
  }
  
  rule process_trip {
    select when car new_trip
    pre{
      mileage = event:attr("mileage").klog("FROM process_trip -- Mileage passed in: ")
      all_attrs = event:attrs()
    }
    send_directive("new_trip") with
      trip_length = mileage
    fired{
        raise explicit event "trip_processed"
            attributes all_attrs
    }
  }

  rule find_long_trips {
    select when explicit trip_processed
    pre {
        mileage = event:attr("mileage").klog("FROM find_long_trips -- Mileage passed in: ")
        all_attrs = event:attrs()
        is_long = mileage > long_trip
    }
    fired{
        raise explicit event "found_long_trip"
            attributes all_attrs
        if (is_long)
    }
  }

  rule trip_tracker_added {
		select when pico ruleset_added
		pre {
			name = event:attr("name")
			vehicle_name = event:attr("vehicle_name")
			peci = wrangler:parent().eci
			ceci = wrangler:myself().eci
		}
		if name == "trip_tracker" then
			event:send({ 
				"eci": peci,
				"eid": "subscription_module_needed",
     			"domain": "child",
				"type": "subscription_module_needed",
     			"attrs": {
					 "child_eci": ceci,
					 "vehicle_name" : vehicle_name
				}
			})
	}
	
	rule after_ruleset_added {
		select when pico ruleset_added
		pre{
			name = event:attr("name")
			vehicle_name = event:attr("vehicle_name")
			peci = wrangler:parent().eci
			ceci = wrangler:myself().eci
		}
		if name != "trip_tracker" || "trip_store" then
			event:send({
				"eci": peci,
				"eid": "send_subscription",
				"domain": "child",
				"type": "send_subscription",
				"attrs": {
					"child_eci": ceci,
					"vehicle_name" : vehicle_name
				}
			})
	}

	rule approve_subscription {
    select when wrangler inbound_pending_subscription_added
    pre {
        attributes = event:attrs().klog("Subcription: ")
    }
    always {
        raise wrangler event "pending_subscription_approval"
          attributes attributes
    }
  }
}