rule manage_fleet {
  meta {
    name "manage_fleet"
    description <<
      Manage Fleet of Cars 
    >>
    author "Daniel Hair"
    logging on
	shares __testing, showChildren, vehicleByName, fleet_report, vehicles, empty_reports, last_5_reports
	provides __testing, showChildren, vehicleByName, fleet_report, vehicles
	use module Subscriptions
	use module io.picolabs.pico alias wrangler
  }
  	global {
		__testing = {
			"events":  [ 
				{ "domain":  "car", "type" : "new_vehicle", "attrs":["vehicle_name"]},
				{"domain": "collection", "type" : "empty"},
				{"domain": "car", "type" : "unneeded_vehicle", "attrs":["vehicle_name"]},
				{"domain": "report", "type": "func"},
				{"domain": "vehicles", "type": "func"},
				{"domain": "report", "type" : "start"},
				{"domain": "last_5_reports", "type" : "func"}
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

		last_5_reports = function(){
			len = ent:reports.keys().length();
			reports = (len <= 5) => ent:reports | {}.put(ent:reports.keys()[len-5], ent:reports{ent:reports.keys()[len-5]})
													.put(ent:reports.keys()[len-4], ent:reports{ent:reports.keys()[len-4]})
													.put(ent:reports.keys()[len-3], ent:reports{ent:reports.keys()[len-3]})
													.put(ent:reports.keys()[len-2], ent:reports{ent:reports.keys()[len-2]})
													.put(ent:reports.keys()[len-1], ent:reports{ent:reports.keys()[len-1]})
			reports
		}

		highest_report = function(){
			len = ent:reports.keys().length();
			last_report = ent:reports.keys()[len-1].defaultsTo("0_0");
			report_num = last_report.split(re#_#)[1];
			report_num
		}

		fleet_report = function() {
			relevant_subs = vehicles();
			report = relevant_subs
					.map(function(v){
						Subscriptions:skyQuery(v{"attributes"}{"subscriber_eci"}, "trip_store", "trips", {})
					});
			report
		}

		empty_reports = {}
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
				"eid": "install-trip-tracker",
				"domain": "pico",
				"type": "new_ruleset",
				"attrs": { 
					"name": "trip_tracker", 
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
			child_eci = event:attr("child_eci")
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

	rule generate_fleet_report {
		select when report start
		foreach vehicle() setting(vehicle)
		pre {
			child_eci = vehicle{"attributes"}{"subscriber_eci"}
			report_num = highest_report().as("Number") + 1
		}
		if child_eci then
			event.send({
				"eci": child_eci,
				"eid": "fleet request",
				"report": "request",
				"attrs": {
					"name": "report_request",
					"report_num" : report_num
				}
			})
	}

	rule child_reported {
		select when child reporting
		pre {
			id = event:attrs("child_report_id")
			trips = event:attrs("trips")
			report_from_child = {
				"vehicles": vehicles().keys().length(),
				"trips": trips
			}
			report_num = "report_" + id.split("re#_#")[1]
			report = {}
			report.put(id, report_from_child)
		}
		always {
			ent:reports := ent:reports.defaultsTo(empty_reports, "Default to emptyness of reports...")
			ent:reports := ent:reports.put([report_num], report)
			raise increment event "report"
				attributes{ "report_num": report_num }
		}
	}

	rule increment_report {
		select when increment report
		foreach ent:reports{event:attr("report_num")}.keys() setting (key)
			pre{
				report_num = event:attr("report_num")
			}
			always{
				key.klog("foreaching with this key:");
				ent:reports{[report_num, key, "responding"]} := ent:reports{report_num}.keys().length()
			}
	}
	rule empty_collection {
  		select when collection empty
  		always {
    		ent:reports := empty_reports
  		}
	}
}