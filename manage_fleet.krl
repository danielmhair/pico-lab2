rule manage_fleet {
  meta {
    name "manage_fleet"
    description <<
      Manage Fleet of Cars 
    >>
    author "Daniel Hair"
    logging on
    shares __testing, showChildren, vehicleByName
		provides __testing, showChildren, vehicleByName
	use module Subscriptions
    use module io.picolabs.pico alias wrangler
  }
  global {
    __testing = {
			"events":  [ 
				{ "domain": "car", "type": "new_vehicle", "attrs": [ "vehicle_name" ] },
				{"domain": "collection", "type" : "empty"},
				{"domain": "car", "type" : "unneeded_vehicle", "attrs":["vehicle_name"]},
				{"domain": "vehicles", "type": "func"},
			]
		}

    showChildren = function() {
			wrangler:children()
		}

		vehicleByName = function(name) {
			ent:vehicles[name]
		}

		vehicles = function(){
			vehicle_subscriptions = Subscriptions:getSubscriptions()
			.filter(function(v){
				v{"attributes"}{"subscriber_role"} == "vehicle"
			})
			vehicle_subscriptions
		}
  }
  
	rule create_vehicle {
		select when car new_vehicle
		pre {
			vehicle_name = event:attr("vehicle_name")
			exists = ent:vehicles >< vehicle_name
			eci = meta:eci
		}
		if exists then
		send_directive("vehicle_ready")
			with vehicle_name = vehicle_name
		fired {
		} else {
			vehicle_name.klog("Cars name is: ")
			raise pico event "new_child_request"
				attributes {
					"dname": vehicle_name,
					"color": "#FF69B4",
					"vehicle_name": vehicle_name
				}
		}
	}

	rule vehicle_initialized {
		select when pico child_initialized
		pre {
			new_vehicle = event:attr("new_child")
			vehicle_name = event:attr("rs_attrs"){"vehicle_name"}
		}
		if vehicle_name then
			event:send({ 
				"eci": new_vehicle.eci,
				"eid": "install-track-my-trips",
				"domain": "pico",
				"type": "new_ruleset",
				"attrs": { 
					"name": "track_my_trips", 
					"url": "https://raw.githubusercontent.com/danielmhair/pico-lab2/master/track_my_trip.krl", 
					"vehicle_name": vehicle_name
				}
			})
		fired {
				ent:vehicles := ent:vehicles.defaultsTo({});
				ent:vehicles{[vehicle_name]} := new_vehicle
		}
	}

	rule create_subscription_module {
		select when subscription_module_needed
		pre {
			child_eci = event:attr("eci_to_use")
			vehicle_name = event:attr("vehicle_name")
		}
		if child_eci then
			event:send({ 
				"eci": child_eci,
				"eid": "install-ruleset",
				"domain": "pico",
				"type": "new_ruleset",
				"attrs": {
					"rid": "Subscriptions",
					"name": "Subscriptions",
					"vehicle_name": vehicle_name 
				}
			})
	}

	rule add_to_subscription {
		select when child send_subscription
		pre {
			child_eci = event:attr("eci_to_use")
			vehicle_name = event:attr("vehicle_name")
		}
		if vehicle_name then
			event:send({ 
				"eci": child_eci,
				"eid": "install-trip-store",
				"domain": "pico",
				"type": "new_ruleset",
				"attrs": {
					"name": "trip_store",
					"url": "https://raw.githubusercontent.com/danielmhair/pico-lab2/master/trip_store.krl", 
					"vehicle_name": vehicle_name
				}
			})
		fired {
			raise wrangler event "subscription"
				with name = vehicle_name
			name_space = "fleet"
			my_role = "fleet"
			subscriber_role = "vehicle"
			channel_type = "subscription"
			subscriber_eci = child_eci
		}
	}

	rule delete_vehicle {
		select when car unneeded_vehicle
		pre {
			vehicle_name = event:attr("vehicle_name")
			exists = ent:vehicles >< vehicle_name
			eci = meta:eci
			child_to_delete = vehicleByName(vehicle_name)
			subscription_name = "fleet:" + vehicle_name
		}
		if exists then
			send_directive("vehicle_deleted")
				with vehicle_name = vehicle_name
			fired {
				raise pico event "delete_child_request"
					attributes child_to_delete;
					raise wrangler event "subscription_cancellation"
						with subscription_name = subscription_name
				ent:vehicles{[vehicle_name]} := null
			}
	}
}