# PassiveRedis - A Node ORM for Redis

PassiveRedis is an easy way to logically access data stored in a Redis
datastore. PassiveRedis is based off of the Ruby ORM ActiveRecord,
though it does not impliment all of its features (yet).

# Making Models With PassiveRedis

Here is a simple example for creating a User model with PassiveRedis.
This code should be placed in a directory containing all of the other
models and the filename should correspond with the class name.

```coffeescript
PassiveRedis = (require 'PassiveRedis').PassiveRedis

class User extends PassiveRedis
  @string_id: 'username'

  schema:
    username: 'String'
    email: 'String'
    password: 'String'

  relationships:
    hasMany: {
      mailboxes: {}
      messages: {}
    }

User.find = PassiveRedis._find
exports.User = User
```

# Relationships (hasMany and hasOne)

PassiveRedis supports hasMany and hasOne relationships that are defined
within the Model class definition. To setup relationships simply create a `relationships`
property on the model and define the hasMany and hasOne keys.

Usage:

```coffeescript

Mailbox.find 2, (err, mailbox) ->
  if !err
    # Assumes a hasOne relationship between Mailbox and User
    # Because it is possible that hasOne's will be async, returned
    # values from hasOne are promises, that impliment a `with` method
    mailbox.user.with (user) ->
      console.log 'Mailbox\'s user', user

    mailbox.messages (messages) ->
      console.log 'found', messages.length, 'messages'
```


# Getters and Setters

When schema properties are accessed on the model, PassiveRedis
impliments getters and setters that check for getProperty style methods
on the model. If "username" was defined in the model schema, and a
getUsername method was defined on the model, an attempt to access the
username property would call the getUsername method.


# License Information

Copyright (c) 2011 Judson Stephenson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
