# PassiveRedis - A Node ORM for Redis

PassiveRedis is an easy way to logically access data stored in a Redis
datastore. PassiveRedis is based off of the Ruby ORM ActiveRecord,
though it does not impliment all of its features (yet).

# Making Models With PassiveRedis

Here is a simple example for creating a User model with PassiveRedis.
This code should be placed in a directory containing all of the other
models and the filename should correspond with the class name.

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


# License Information

Copyright (c) 2011 Judson Stephenson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
