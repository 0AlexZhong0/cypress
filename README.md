# Cypress Core Socket

This is a shared lib for holding both the `socket.io` server and client.

## Install

```bash
npm install --save @cypress/core-socket
```

## Usage

```javascript
var socket = require("@cypress/core-socket")

// returns
{
  server: require("socket.io"),
  client: require("socket.io-client"),
  getPathToClientSource: function(){
    // returns path to the client 'socket.io.js' file
    // for use in the browser
  }
}
```

```javascript
var socket = require("@cypress/core-socket")

// server usage
var srv = require("http").createServer()
var io = socket.server(srv)
io.on("connection", function(){});

// client usage
var client = socket.client("http://localhost:2020")
client.on("connect", function(){})
client.on("event", function(){})
client.on("disconnect", function(){})

// path usage
socket.getPathToClientSource()
// returns your/path/to/node_modules/socket.io-client/socket.io.js0
```


## Changelog

#### 0.2.1 - *(04/20/17)*
- bump cypress releaser dep

#### 0.2.0 - *(06/17/16)*
- added socket.getClientVersion and socket.getClientSource methods

#### 0.1.0 - *(04/29/16)*
- initial release
