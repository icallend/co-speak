# co-speak

Node.js server and partner Swift app, implemented with Socket.io, as documented at http://www.iancallender.net/#projects-isolationism

Currently relevant texts that promote isolationist policies are read aloud collaboratively. Their purpose is thus inverted as they relinquish their status as tools inspiring isolation and instead become tools of community. Texts include speeches by Donald Trump (Inauguration) and Boris Johnson ('Vote Leave'), among others. 

Users connect to a webserver via an app. The server sends a single word to a single client; the word must be read aloud in order to advance the text (if the user fails to read the word properly, the screen flashes red and they are offered an 'advance' button). 
