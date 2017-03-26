ruleset echos {
  meta {
    name "Echoing"
    description <<
A first ruleset for Part 1 of Pico Lab
>>
    author "Daniel Hair"
    logging on
    shares __testing
  }
  
  global {
    __testing = {
        "queries":[{ "name": "__testing" }],
        "events": [ { "domain": "echo", "type": "hello" },
                    { "domain": "echo", "type": "message", "attrs": [ "input" ] } ]
    }
  }
  
  rule hello {
    select when echo hello
    send_directive("say") with
      something = "Hello World"
  }
  
  rule message {
    select when echo message
    pre{
      my_input = event:attr("input").klog("The input given is: ")
    }
    send_directive("say") with
      something = my_input
  }
}