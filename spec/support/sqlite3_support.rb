require 'sqlite3'

# Database
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'spec/db/sqlite3.db')

User.connection.execute 'DROP TABLE IF EXISTS users;'
User.connection.execute 'CREATE TABLE users (id INTEGER PRIMARY KEY, first_name VARCHAR(256), last_name VARCHAR(256), email VARCHAR(256), password_digest VARCHAR(256));'

Post.connection.execute 'DROP TABLE IF EXISTS posts;'
Post.connection.execute 'CREATE TABLE posts (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, subject VARCHAR(256), body VARCHAR(256), is_published BOOLEAN);'

Tag.connection.execute 'DROP TABLE IF EXISTS tags;'
Tag.connection.execute 'CREATE TABLE tags (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(256));'

UsersTag.connection.execute 'DROP TABLE IF EXISTS users_tags;'
UsersTag.connection.execute 'CREATE TABLE users_tags (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, tag_id INTEGER, is_primary BOOLEAN);'
UsersTag.connection.execute 'CREATE UNIQUE INDEX idx_users_tags ON users_tags (user_id, tag_id);'
