'use strict';

/* socket io definitions */
const express = require('express');
const socketIO = require('socket.io');
const path = require('path');

const PORT = process.env.PORT || 3000;
const INDEX = path.join(__dirname, 'index.html');

const server = express()
  .use((req, res) => res.sendFile(INDEX) )
  .listen(PORT, () => console.log(`Listening on ${ PORT }`));

const io = socketIO(server);


/* application variables */
var members = [];
var members_i = 0;
var min_members = 2; // should be 2

var textfiles = [ {'name':'Vote Leave (Brexit)' , 'author':'Boris Johnson' , 'date':'05.09.2016' , 'filename':'brexit-bj.txt'} , {'name':'Inauguration Speech' , 'author':'Donald Trump' , 'date':'01.20.2017' , 'filename':'trump-inauguration.txt'} ];

var textfile_nil = {'name':'-' , 'author':'-' , 'date':'-' , 'filename':'-'};
var textfiles_i = 0;

var text_body = "";
var text_body_split = [];
var text_body_length = 0;
var text_body_i = 0;
var fs = require('fs');

var running = 0;

var activeTimeout = null;
var timeoutSecs = 30; // should be 30


io.on('connection', (socket) => {
  console.log('Client connected : '+socket.id);
  socket.join('inactive');
  socket.emit('duckduckgoose','inactive'); // states: inactive, standby, duck, goose
  socket.emit('displaymessage','\'join\' to begin');

  /* when client enters the room, take them out of inactive 
   * and add them to active as well as to members list.
   * if running, send them info/tell to wait.
   * otherwise, not enough ppl are active.
   * if they are the new member that tips the balance,
   * run the game
   * NB: name = join-1. Can implement IP stuff here.
  */ 
  socket.on('join', function (name, fn) {
  	console.log('client join request from '+socket.id);

  	socket.leave('inactive');
  	members.push(socket.id);
	console.log(members);
  	socket.join('active');

	if(running) {
		socket.emit('duckduckgoose','standby'); // states: inactive, standby, duck, goose
		socket.emit('displaymessage','please wait for next turn to begin');
		socket.emit('textinfo',JSON.stringify(textfiles[textfiles_i]));
	} else if(!running) {
		socket.emit('duckduckgoose','standby');
		socket.emit('displaymessage','please wait for other participants to join');

		if(members.length >= min_members) {
			running = 1;

			io.to('active').emit('duckduckgoose','standby');
			io.to('active').emit('displaymessage','please wait for next turn to begin');

			load_new_textfile(ddg);
		}
	}

 	fn(1);
  });

  /* when client leaves the room, take them out of active and add them to inactive. 
   * make sure removal from members list will not cause skipping over next member.
   * finally, if running, make sure this is not the member that tips the balance
  */ 
  socket.on('leave', function (name, fn) {
  	console.log('client leave request from '+socket.id);

  	socket.leave('active');

	var socket_members_index = members.indexOf(socket.id);
	if (socket_members_index > -1) {
		if(socket_members_index <= members_i) members_i--;
    	members.splice(socket_members_index, 1);
	}
	  	console.log(members);
	
	socket.emit('duckduckgoose','inactive');
	socket.emit('displaymessage','\'join\' to begin');

  	socket.join('inactive');

	if(running){
		if(members.length < min_members){
			running = 0;
			io.to('active').emit('duckduckgoose','standby');
			io.to('active').emit('displaymessage','please wait for other participants to join');
			io.to('active').emit('textinfo',JSON.stringify(textfile_nil));
		} else {
			ddg();
		}
	}

 	fn(1);
  });

  /* when client advances, move on to next member, next word, and run ddg
  */ 
  socket.on('advance', function (name, fn) {
  	console.log('client advance request from '+socket.id);
  	if(running){
  		console.log('request accepted for '+socket.id);
		if(socket.id == members[members_i]){
			console.log('request successful for '+socket.id);
			clearTimeout(activeTimeout);

			members_i++;
			text_body_i++;
			if(text_body_i >= text_body_length){
				load_new_textfile(ddg);
			} else {
				ddg();
			}

		} else {
			console.log('Not your turn! '+socket.id);
		}
	} else {
		console.log('request denied for '+socket.id);
	}


 	fn(1);
  });

  socket.on('disconnect', () => {
  	console.log('Client disconnected : '+socket.id);
  	socket.leave('active');
  	socket.leave('inactive');

	var socket_members_index = members.indexOf(socket.id);
	if (socket_members_index > -1) {
		if(socket_members_index <= members_i) members_i--;
    	members.splice(socket_members_index, 1);
	} 

	if(running){
		if(members.length < min_members){
			running = 0;
			io.to('active').emit('duckduckgoose','standby');
			io.to('active').emit('displaymessage','please wait for other participants to join');
			io.to('active').emit('textinfo',JSON.stringify(textfile_nil));
		} else {
			ddg();
		}
	}

  });

});

/* run the game
 * basically, take members_i and send 'goose'
 * to all others, send 'duck'
 * get a timeout going so if no response in 30s move on
*/ 
function ddg () {
	if(running){
		if(members_i >= members.length) members_i = 0;
		if(members_i < 0) members_i = 0;

		io.to(members[members_i]).emit('duckduckgoose', 'goose');
		//io.to(members[members_i]).emit('displaymessage', 'You\'re the goose!');

		io.to(members[members_i]).emit('displaymessage', text_body_split[text_body_i]);

		for(let j=0; j<members.length; j++){
			if(j!=members_i) {
				io.to(members[j]).emit('duckduckgoose', 'duck');
				//io.to(members[j]).emit('displaymessage', 'you\'re a duck');
				io.to(members[j]).emit('displaymessage', '...');
			}
		}

		//activeTimeout = setTimeout(timeout, timeoutSecs*1000, members_i);
	}
}

/* timeout
 * note: should not increment word counter, just pass to next person
*/ 
function timeout (xref_members_i) {
	if(running){
		if(xref_members_i == members_i){
			console.log("Timed out");
			members_i++;
			ddg();
		}
	}
}


/* pull a new textfile
 * 
*/ 
function load_new_textfile (bar) {

	// shuffle textfiles array? maybe upon rest of text_i? or use random text_i values?
	textfiles_i = (textfiles_i+1) % textfiles.length;

  	console.log('loading: '+textfiles[textfiles_i].filename);
	fs.readFile('./texts/'+textfiles[textfiles_i].filename, 'utf8', function (err,data) {
		if (err) {
			return console.log(err);
			process.exit(-1);
		}

		text_body = data;
		text_body_split = text_body.split(/[\s*]/g); // along all whitespace
		text_body_length = text_body_split.length;

		text_body_i = 0;

		io.to('active').emit('textinfo',JSON.stringify(textfiles[textfiles_i]));
  		console.log('load successful');

		bar();
	});

}


