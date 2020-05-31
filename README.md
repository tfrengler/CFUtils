# FrenglerUtils (used to be CFUtils)
Originally this was exclusively a collection of Coldfusion utility stuff gathered in one place, but I have since expanded it to include JS utilities as well

## AjaxProxy.cfc
Originally created at my work as a way for front-end JS to communicate securely with a Coldfusion backend. 
It ended up working so well for me that decided to use it for my home projects and it's been a staple ever since.
Yes, it's meant as a unified front for talking to a backend CFC securely though I am sure it's not fool-proof. 

It works on these principles:
1. There's just 1 method you can call, which is - very creatively - called **call()**
1. An auth-key that needs to be passed to *call()* (this is generated based on your client cookie and a secret key)
1. A whitelist map of components (classes) and methods that are allowed to be called

## Utils.js
Simply just a collection of assorted Javascript utility methods that I frequently end up needing to use in my projects.
Some of them are written by me (getReadableTime, fetchRequest, XOREncode, XORDecode and Log) while the rest are written by other
people and I simply copied them or modified them slightly for my own use.

**NOTE:** fetchRequest() in particular is built to work together with AjaxProxy.

_TO BE UPDATED_
