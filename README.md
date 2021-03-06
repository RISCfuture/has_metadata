has_metadata
============

**Keep your tables narrow**

|             |                                 |
|:------------|:--------------------------------|
| **Author**  | Tim Morgan                      |
| **Version** | 1.6.1 (Jan 24, 2012)            |
| **License** | Released under the MIT License. |

About
-----

Wide tables are a problem for big databases. If your `ActiveRecord` models have
10, maybe 15 columns, some of which are `VARCHARs` or maybe even `TEXTs`, it's
going to slow your queries down when you start to scale up.

The easy solution to this problem is to limit your projections; in other words,
to only `SELECT` the columns that you actually need. If you've got a `users`
table with a giant `about_me` text column, and you're only trying to look up the
user's login, then just select the `login` column.

In the long run, though, a superior solution is to just move those
`about_me`-type columns to a completely different table. This table has just one
JSON-serialized field, making it schemaless, so it doesn't waste space. Each row
in this table is associated with a record in another table (`Metadata` `has_one`
of your models).

This way, when your website gets huge, all of your giant, freeform data is in
one table that you can shard, or move off to an alternate database, or even a
NoSQL-type document store, or otherwise manage as you please. Your relational
tables remain slim and efficient, containing only columns that a) are indexed,
or b) you need frequent access to.

This gem includes a generator that creates the `Metadata` model, and a module
that you can include in your models to define which fields have been spun off to
the metadata record.

Installation
------------

**Important Note:** This gem is only compatible with Ruby 1.9+ and Rails 3.0+.

Firstly, add the gem to your Rails project's `Gemfile`:

```` ruby
gem 'has_metadata'
````

Next, run the generator, which will add the `Metadata` model and its migration
to your application.

```` sh
rails generate metadata
````

Usage
-----

The first thing to think about is what columns to keep in your model. You will
need to keep any indexed columns, or any columns you perform lookups or other
SQL queries with. You should also keep any frequently accessed columns,
especially if they are small (integers or booleans). Good candidates for the
metadata table are the `TEXT`- and `VARCHAR`-type columns that you only need to
render a page or two in your app.

You'll need to change your model's schema so that it has a `metadata_id` column
that will associate the model with its `Metadata` instance:

```` ruby
t.belongs_to :metadata
````

Next, include the `HasMetadata` module in your model, and call the
`has_metadata` method to define the schema of your metadata. You can get more
information in the {HasMetadata::ClassMethods#has_metadata} documentation, but for starters, here's a
basic example:

```` ruby
class User < ActiveRecord::Base
  include HasMetadata
  has_metadata({
    about_me: { type: String, length: { maximum: 512 } },
    birthdate: { type: Date, presence: true },
    zipcode: { type: Number, numericality: { greater_than: 9999, less_than: 10_000} }
  })
end
````

As you can see, you pass field names mapped to a hash. The hash describes the
validation that will be performed, and is in the same format as a call to
`validates`. In addition to the `EachValidator` keys shown above, you can also
pass a `type` key, to constrain the Ruby type that can be assigned to the field.

Each of these fields (in this case, `about_me`, `birthdate`, and `zipcode`) can
be accessed and set as first_level methods on an instance of your model:

```` ruby
user.about_me #=> "I was born in 1982 in Aberdeen. My father was a carpenter from..."
````

... and thus, used as part of `form_for` fields:

```` ruby
form_for user do |f|
  f.text_area :about_me, rows: 5, cols: 80
end
````

The only thing you _can't_ do is use these fields in a query, obviously. You
can't do something like `User.where(zipcode: 90210)`, because that column
doesn't exist on the `users` table.
