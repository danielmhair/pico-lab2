ruleset track_trips {
  meta {
    name "Track Trips"
    description <<
A first ruleset for Part 2 of pico lab
>>
    author "Daniel Hair"
    logging on
    shares __testing
  }
  
  global {
    __testing = {
        "queries": [ { "name": "__testing" } ],
        "events": [ { "domain": "echo", "type": "message", "attrs": [ "mileage" ] } ]
    }
  }
  
  rule process_trip {
    select when echo message
    pre{
      mileage = event:attr("mileage").klog("Mileage passed in: ")
    }
    send_directive("trip") with
      trip_length = mileage
  }
}